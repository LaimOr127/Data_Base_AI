#!/bin/bash
# Восстановление DIGroup из бэкапа
# Использование: sudo ./restore.sh workspace_20240101_120000.tar.gz

set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Проверка аргументов
if [ $# -lt 1 ]; then
    echo -e "${RED}❌ Использование: sudo ./restore.sh BACKUP_FILE${NC}"
    echo "Пример: sudo ./restore.sh workspace_20240101_120000.tar.gz"
    exit 1
fi

BACKUP_FILE=$1
BACKUP_DIR="/opt/digroup/backups"
WORKSPACE_DIR="/opt/digroup/workspace"

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Пожалуйста, запустите скрипт с правами root: sudo ./restore.sh${NC}"
    exit 1
fi

# Проверка существования файла
if [ ! -f "$BACKUP_FILE" ]; then
    # Попробуем найти в директории бэкапов
    if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
        BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE"
    else
        echo -e "${RED}❌ Файл бэкапа не найден: $BACKUP_FILE${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}⚠️  ВНИМАНИЕ: Это перезапишет текущий workspace!${NC}"
read -p "Продолжить? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Восстановление отменено"
    exit 0
fi

# Остановка Docker контейнера
echo -e "${BLUE}Остановка DIGroup...${NC}"
cd /opt/digroup
docker-compose down 2>/dev/null || true

# Создание резервной копии текущего workspace
if [ -d "$WORKSPACE_DIR" ]; then
    echo -e "${BLUE}Создание резервной копии текущего workspace...${NC}"
    BACKUP_CURRENT="/tmp/workspace_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$BACKUP_CURRENT" -C "$(dirname $WORKSPACE_DIR)" "$(basename $WORKSPACE_DIR)"
    echo -e "${GREEN}✅ Резервная копия создана: $BACKUP_CURRENT${NC}"
fi

# Восстановление из бэкапа
echo -e "${BLUE}Восстановление из бэкапа...${NC}"
mkdir -p "$(dirname $WORKSPACE_DIR)"
tar -xzf "$BACKUP_FILE" -C "$(dirname $WORKSPACE_DIR)"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Восстановление завершено${NC}"
    
    # Установка прав
    chown -R $SUDO_USER:$SUDO_USER "$WORKSPACE_DIR"
    
    # Запуск Docker контейнера
    echo -e "${BLUE}Запуск DIGroup...${NC}"
    docker-compose up -d
    
    echo ""
    echo -e "${GREEN}✅ Восстановление завершено успешно!${NC}"
    echo ""
    echo -e "${BLUE}📋 Проверьте работу:${NC}"
    echo "   docker-compose logs -f"
    echo "   curl http://127.0.0.1:6806/api/system/version"
else
    echo -e "${RED}❌ Ошибка при восстановлении${NC}"
    exit 1
fi

