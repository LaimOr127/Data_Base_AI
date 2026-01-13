#!/bin/bash
# Автоматическое обновление DIGroup

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/opt/digroup"
BACKUP_BEFORE_UPDATE=true

echo -e "${BLUE}🔄 Автоматическое обновление DIGroup${NC}"
echo "=================================="
echo ""

# Проверка наличия git
if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ Git не установлен${NC}"
    exit 1
fi

cd "$PROJECT_DIR"

# Проверка изменений
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}⚠️  Обнаружены локальные изменения${NC}"
    read -p "Продолжить обновление? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Обновление отменено"
        exit 0
    fi
fi

# Бэкап перед обновлением
if [ "$BACKUP_BEFORE_UPDATE" = true ]; then
    echo -e "${BLUE}Создание бэкапа перед обновлением...${NC}"
    /opt/digroup/deploy/scripts/backup.sh
fi

# Сохранение текущей версии
CURRENT_VERSION=$(git rev-parse HEAD)
echo -e "${BLUE}Текущая версия: $CURRENT_VERSION${NC}"

# Получение обновлений
echo -e "${BLUE}Получение обновлений из репозитория...${NC}"
git fetch origin

# Проверка наличия обновлений
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u})

if [ "$LOCAL" = "$REMOTE" ]; then
    echo -e "${GREEN}✅ Уже установлена последняя версия${NC}"
    exit 0
fi

echo -e "${YELLOW}Обнаружены обновления${NC}"
echo "Изменения:"
git log --oneline "$LOCAL..$REMOTE" | head -10

read -p "Применить обновления? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Обновление отменено"
    exit 0
fi

# Остановка сервисов
echo -e "${BLUE}Остановка сервисов...${NC}"
cd "$PROJECT_DIR"
docker-compose down

# Применение обновлений
echo -e "${BLUE}Применение обновлений...${NC}"
git pull origin main

# Пересборка образов (если нужно)
if [ -f "docker-compose.yml" ]; then
    echo -e "${BLUE}Пересборка Docker образов...${NC}"
    docker-compose build --no-cache
fi

# Запуск сервисов
echo -e "${BLUE}Запуск сервисов...${NC}"
docker-compose up -d

# Ожидание запуска
echo -e "${BLUE}Ожидание запуска...${NC}"
sleep 10

# Проверка работоспособности
if curl -s http://127.0.0.1:6806/api/system/version > /dev/null; then
    echo -e "${GREEN}✅ Обновление завершено успешно!${NC}"
    echo ""
    echo "Новая версия: $(git rev-parse HEAD)"
else
    echo -e "${RED}❌ Ошибка после обновления${NC}"
    echo "Откат к предыдущей версии..."
    git reset --hard "$CURRENT_VERSION"
    docker-compose up -d
    exit 1
fi

