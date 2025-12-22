#!/bin/bash
# Скрипт проверки и автоматического запуска DIGroup
# Использование: ./check_and_start.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Убираем set -e чтобы скрипт продолжал работу при ошибках проверки
set +e

echo -e "${BLUE}🔍 Проверка системы перед запуском...${NC}"
echo ""

# Проверка 1: Kernel скомпилирован
echo -n "1. Проверка kernel... "
KERNEL_DIR="$SCRIPT_DIR/../kernel"
if [ -f "$KERNEL_DIR/SiYuan-Kernel" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${YELLOW}⚠️  Не найден, будет собран автоматически${NC}"
fi

# Проверка 2: Ollama установлен
echo -n "2. Проверка Ollama... "
if command -v ollama > /dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌ Не установлен${NC}"
    echo "   Установите: https://ollama.ai"
    exit 1
fi

# Проверка 3: Ollama сервер доступен
echo -n "3. Проверка Ollama сервера... "
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${YELLOW}⚠️  Не запущен, будет запущен автоматически${NC}"
fi

# Проверка 4: Модель доступна
echo -n "4. Проверка модели ИИ... "
if curl -s http://localhost:11434/api/show -d '{"name":"nemotron-3-nano:30b-cloud"}' 2>&1 | grep -q "error"; then
    echo -e "${YELLOW}⚠️  Не найдена, будет загружена автоматически${NC}"
else
    echo -e "${GREEN}✅${NC}"
fi

# Проверка 5: Frontend собран
echo -n "5. Проверка frontend... "
APP_DIR="$SCRIPT_DIR/../app"
if [ -d "$APP_DIR/stage/build/app" ] && [ -n "$(ls -A $APP_DIR/stage/build/app 2>/dev/null)" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${YELLOW}⚠️  Не собран, будет собран автоматически${NC}"
fi

# Проверка 6: Порт 6806 свободен
echo -n "6. Проверка порта 6806... "
if lsof -Pi :6806 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Занят${NC}"
    echo "   Останавливаю старые процессы..."
    pkill -f "SiYuan-Kernel" 2>/dev/null || true
    sleep 2
else
    echo -e "${GREEN}✅${NC}"
fi

echo ""
echo -e "${GREEN}✅ Все проверки завершены!${NC}"
echo ""
echo -e "${BLUE}🚀 Запускаю DIGroup...${NC}"
echo ""

# Запуск автоматического скрипта
exec "$SCRIPT_DIR/start_digroup_auto.sh"

