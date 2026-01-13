#!/bin/bash
# Автоматический скрипт запуска DIGroup с полной проверкой
# Использование: ./start_digroup_auto.sh

set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Пути
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
KERNEL_DIR="$PROJECT_DIR/siyuan/kernel"
APP_DIR="$PROJECT_DIR/siyuan/app"
WORKSPACE_DIR="$HOME/DIGroup-workspace"
ACCESS_CODE="b226ba0f30a134fe9245792118bca202"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   DIGroup Автоматический Запуск      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Функция проверки
check_status() {
    local status=$?
    local message=$1
    if [ $status -eq 0 ]; then
        echo -e "${GREEN}✅ $message${NC}"
        return 0
    else
        echo -e "${RED}❌ $message${NC}"
        return 1
    fi
}

# Функция ожидания
wait_for_service() {
    local url=$1
    local name=$2
    local max_attempts=30
    local attempt=0
    
    echo -n "   Ожидание $name"
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            echo ""
            return 0
        fi
        echo -n "."
        sleep 1
        attempt=$((attempt + 1))
    done
    echo ""
    return 1
}

# ============================================
# ШАГ 1: Проверка зависимостей
# ============================================
echo -e "${YELLOW}📋 ШАГ 1: Проверка зависимостей${NC}"
echo ""

# Проверка kernel
if [ ! -f "$KERNEL_DIR/SiYuan-Kernel" ]; then
    echo -e "${YELLOW}⚠️  Kernel не найден: $KERNEL_DIR/SiYuan-Kernel${NC}"
    echo "   Собираю kernel..."
    cd "$KERNEL_DIR"
    if go build -o SiYuan-Kernel 2>&1 | tail -5; then
        echo -e "${GREEN}✅ Kernel собран${NC}"
    else
        echo -e "${RED}❌ Ошибка сборки kernel${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Kernel найден${NC}"
fi

# Проверка Ollama
echo -n "   Проверка Ollama... "
if command -v ollama > /dev/null 2>&1; then
    OLLAMA_VERSION=$(ollama --version 2>/dev/null | head -1 || echo "unknown")
    echo -e "${GREEN}✅ Установлен ($OLLAMA_VERSION)${NC}"
    
    # Проверка запущен ли Ollama сервер
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo -e "   ${GREEN}✅ Ollama сервер запущен${NC}"
    else
        echo -e "   ${YELLOW}⚠️  Ollama сервер не запущен, запускаю...${NC}"
        ollama serve > /tmp/ollama.log 2>&1 &
        OLLAMA_PID=$!
        echo "   Ollama запущен (PID: $OLLAMA_PID)"
        sleep 3
        if wait_for_service "http://localhost:11434/api/tags" "Ollama сервер"; then
            echo -e "   ${GREEN}✅ Ollama сервер запущен${NC}"
        else
            echo -e "   ${YELLOW}⚠️  Ollama сервер запускается...${NC}"
        fi
    fi
    
    # Проверка модели
    echo -n "   Проверка модели nemotron-3-nano:30b-cloud... "
    if curl -s http://localhost:11434/api/show -d '{"name":"nemotron-3-nano:30b-cloud"}' 2>&1 | grep -q "error"; then
        echo -e "${YELLOW}⚠️  Модель не найдена, загружаю...${NC}"
        ollama pull nemotron-3-nano:30b-cloud > /tmp/ollama-pull.log 2>&1 &
        echo "   Модель загружается в фоне..."
    else
        echo -e "${GREEN}✅ Модель доступна${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Ollama не установлен${NC}"
    echo "   Установите Ollama: https://ollama.ai"
fi

# Проверка frontend
echo -n "   Проверка frontend... "
if [ ! -d "$APP_DIR/stage/build/app" ] || [ -z "$(ls -A $APP_DIR/stage/build/app 2>/dev/null)" ]; then
    echo -e "${YELLOW}⚠️  Frontend не собран, собираю...${NC}"
    cd "$APP_DIR"
    pnpm run build:app > /tmp/digroup-build.log 2>&1
    check_status "Frontend собран"
else
    echo -e "${GREEN}✅ Frontend собран${NC}"
fi

echo ""

# ============================================
# ШАГ 2: Остановка старых процессов
# ============================================
echo -e "${YELLOW}🛑 ШАГ 2: Остановка старых процессов${NC}"
pkill -f "SiYuan-Kernel" 2>/dev/null && sleep 2 && echo -e "${GREEN}✅ Старые процессы kernel остановлены${NC}" || echo -e "${GREEN}✅ Нет запущенных процессов kernel${NC}"
pkill -f "electron.*main.js" 2>/dev/null && sleep 1 && echo -e "${GREEN}✅ Старые процессы Electron остановлены${NC}" || echo -e "${GREEN}✅ Нет запущенных процессов Electron${NC}"
echo ""

# ============================================
# ШАГ 3: Запуск kernel
# ============================================
echo -e "${YELLOW}🚀 ШАГ 3: Запуск kernel${NC}"
cd "$KERNEL_DIR"
nohup ./SiYuan-Kernel \
    --wd=../app \
    --workspace="$WORKSPACE_DIR" \
    --accessAuthCode="$ACCESS_CODE" \
    --port=6806 \
    --mode=dev \
    > /tmp/digroup-kernel.log 2>&1 &

KERNEL_PID=$!
echo "   Kernel PID: $KERNEL_PID"

# Ожидание запуска kernel
if wait_for_service "http://127.0.0.1:6806/api/system/version" "Kernel"; then
    KERNEL_VERSION=$(curl -s http://127.0.0.1:6806/api/system/version | python3 -c "import sys, json; print(json.load(sys.stdin)['data'])" 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✅ Kernel запущен и отвечает (версия: $KERNEL_VERSION)${NC}"
else
    echo -e "${RED}❌ Kernel не запустился за 30 секунд${NC}"
    echo "   Проверьте логи: tail -f /tmp/digroup-kernel.log"
    exit 1
fi
echo ""

# ============================================
# ШАГ 4: Проверка работоспособности
# ============================================
echo -e "${YELLOW}🔍 ШАГ 4: Проверка работоспособности${NC}"

# Проверка API
echo -n "   Проверка API... "
if curl -s http://127.0.0.1:6806/api/system/version > /dev/null 2>&1; then
    echo -e "${GREEN}✅ API работает${NC}"
else
    echo -e "${RED}❌ API не отвечает${NC}"
fi

# Проверка Ollama
echo -n "   Проверка Ollama... "
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Ollama доступен${NC}"
else
    echo -e "${YELLOW}⚠️  Ollama недоступен${NC}"
fi

# Проверка логов на ошибки
echo -n "   Проверка логов на критические ошибки... "
if tail -50 /tmp/digroup-kernel.log 2>/dev/null | grep -qiE "fatal|panic|F.*database"; then
    echo -e "${YELLOW}⚠️  Обнаружены ошибки в логах${NC}"
    echo "   Проверьте: tail -f /tmp/digroup-kernel.log"
else
    echo -e "${GREEN}✅ Критических ошибок не обнаружено${NC}"
fi

# Проверка авторизации
echo -n "   Проверка обязательной авторизации... "
if curl -s http://127.0.0.1:6806/ 2>&1 | grep -qiE "check-auth|auth"; then
    echo -e "${GREEN}✅ Авторизация обязательна${NC}"
else
    # Проверяем редирект
    REDIRECT=$(curl -s -I http://127.0.0.1:6806/ 2>&1 | grep -i "location" | head -1)
    if echo "$REDIRECT" | grep -q "check-auth"; then
        echo -e "${GREEN}✅ Авторизация обязательна (редирект работает)${NC}"
    else
        echo -e "${YELLOW}⚠️  Проверьте настройки авторизации${NC}"
    fi
fi

echo ""

# ============================================
# ШАГ 5: Запуск Electron (опционально)
# ============================================
echo -e "${YELLOW}🖥️  ШАГ 5: Запуск Electron приложения${NC}"
read -p "   Запустить Electron приложение? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$APP_DIR"
    NODE_ENV=development pnpm exec electron ./electron/main.js > /tmp/digroup-electron.log 2>&1 &
    ELECTRON_PID=$!
    echo "   Electron запущен (PID: $ELECTRON_PID)"
    echo -e "${GREEN}✅ Electron приложение запущено${NC}"
else
    echo -e "${BLUE}ℹ️  Electron не запущен (можно запустить вручную)${NC}"
fi

echo ""

# ============================================
# ИТОГОВАЯ ИНФОРМАЦИЯ
# ============================================
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ DIGroup успешно запущен!          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

# Получение IP адреса
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="ВАШ_IP_АДРЕС"
fi

echo -e "${BLUE}📊 Информация о сервисах:${NC}"
echo "   • Kernel:  PID $KERNEL_PID (порт 6806)"
if [ ! -z "$ELECTRON_PID" ]; then
    echo "   • Electron: PID $ELECTRON_PID"
fi
if [ ! -z "$OLLAMA_PID" ]; then
    echo "   • Ollama:  PID $OLLAMA_PID (порт 11434)"
fi
echo ""

echo -e "${BLUE}🌐 Доступ к приложению:${NC}"
echo "   • Локально: http://localhost:6806"
echo "   • В сети:   http://$LOCAL_IP:6806"
echo ""

echo -e "${BLUE}🔐 Авторизация:${NC}"
echo "   • AccessAuthCode: $ACCESS_CODE"
echo "   • Или логин/пароль пользователя"
echo ""

echo -e "${BLUE}📝 Логи:${NC}"
echo "   • Kernel:  tail -f /tmp/digroup-kernel.log"
if [ ! -z "$ELECTRON_PID" ]; then
    echo "   • Electron: tail -f /tmp/digroup-electron.log"
fi
if [ ! -z "$OLLAMA_PID" ]; then
    echo "   • Ollama:  tail -f /tmp/ollama.log"
fi
echo ""

echo -e "${BLUE}🛑 Остановка:${NC}"
echo "   • ./stop_digroup.sh"
echo "   • или: pkill -f SiYuan-Kernel && pkill -f electron"
echo ""

echo -e "${GREEN}✅ Все готово к работе!${NC}"

