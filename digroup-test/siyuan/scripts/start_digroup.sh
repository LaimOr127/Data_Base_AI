#!/bin/bash
# Скрипт для запуска DIGroup одной командой
# Использование: ./start_digroup.sh

set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Пути
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
KERNEL_DIR="$PROJECT_DIR/siyuan/kernel"
APP_DIR="$PROJECT_DIR/siyuan/app"
WORKSPACE_DIR="$HOME/DIGroup-workspace"
ACCESS_CODE="b226ba0f30a134fe9245792118bca202"

echo "🚀 Запуск DIGroup"
echo "=================="
echo ""

# Проверка kernel
if [ ! -f "$KERNEL_DIR/SiYuan-Kernel" ]; then
    echo -e "${RED}❌ Kernel не найден: $KERNEL_DIR/SiYuan-Kernel${NC}"
    exit 1
fi

# Остановка старых процессов
echo "1️⃣  Остановка старых процессов..."
pkill -f "SiYuan-Kernel" 2>/dev/null || true
pkill -f "electron.*main.js" 2>/dev/null || true
sleep 2

# Запуск kernel
echo ""
echo "2️⃣  Запуск kernel..."
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
echo ""
echo "3️⃣  Ожидание запуска kernel..."
for i in {1..30}; do
    if curl -s http://127.0.0.1:6806/api/system/version > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Kernel запущен и отвечает${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ Kernel не запустился за 30 секунд${NC}"
        echo "Проверьте логи: tail -f /tmp/digroup-kernel.log"
        exit 1
    fi
    sleep 1
    echo -n "."
done
echo ""

# Сборка frontend (если нужно)
echo ""
echo "4️⃣  Проверка frontend..."
if [ ! -d "$APP_DIR/stage/build/app" ] || [ -z "$(ls -A $APP_DIR/stage/build/app 2>/dev/null)" ]; then
    echo "   Frontend не собран, собираю..."
    cd "$APP_DIR"
    pnpm run build:app > /tmp/digroup-build.log 2>&1 &
    BUILD_PID=$!
    echo "   Сборка запущена (PID: $BUILD_PID), жду завершения..."
    wait $BUILD_PID
    echo -e "${GREEN}✅ Frontend собран${NC}"
else
    echo -e "${GREEN}✅ Frontend уже собран${NC}"
fi

# Запуск Electron
echo ""
echo "5️⃣  Запуск Electron приложения..."
cd "$APP_DIR"
NODE_ENV=development electron ./electron/main.js > /tmp/digroup-electron.log 2>&1 &
ELECTRON_PID=$!
echo "   Electron PID: $ELECTRON_PID"

# Получение IP адреса для доступа с других устройств
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="ВАШ_IP_АДРЕС"
fi

# Итоговая информация
echo ""
echo -e "${GREEN}✅ DIGroup запущен!${NC}"
echo ""
echo "📊 Процессы:"
echo "   Kernel:  PID $KERNEL_PID (порт 6806)"
echo "   Electron: PID $ELECTRON_PID"
echo ""
echo -e "${YELLOW}🌐 Ссылки для тестирования:${NC}"
echo ""
echo "📱 Локальный доступ (на этом компьютере):"
echo "   • Electron приложение: откроется автоматически"
echo "   • Веб-интерфейс: http://localhost:6806"
echo "   • API проверка: curl http://localhost:6806/api/system/version"
echo ""
echo "🌍 Доступ с других устройств (в той же сети):"
echo "   • Веб-интерфейс: http://$LOCAL_IP:6806"
echo "   • API проверка: curl http://$LOCAL_IP:6806/api/system/version"
echo ""
echo "🔐 Доступ:"
echo "   • AccessAuthCode: $ACCESS_CODE"
echo "   • Или используйте логин/пароль пользователя (Basic Auth)"
echo ""
echo "👥 Тестирование пользователей:"
echo "   • Редактор: curl -u sha:sha123 http://$LOCAL_IP:6806/api/system/version"
echo "   • Гость: curl -u guest:guest123 http://$LOCAL_IP:6806/api/system/version"
echo ""
echo "📝 Логи:"
echo "   Kernel:  tail -f /tmp/digroup-kernel.log"
echo "   Electron: tail -f /tmp/digroup-electron.log"
echo ""
echo "🛑 Остановка:"
echo "   ./stop_digroup.sh"
echo "   или: pkill -f SiYuan-Kernel && pkill -f electron"
echo ""

