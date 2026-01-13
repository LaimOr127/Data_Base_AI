#!/bin/bash
# Скрипт проверки здоровья системы DIGroup

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ISSUES=0

check_service() {
    local service=$1
    local port=$2
    
    if curl -s "http://127.0.0.1:${port}/api/system/version" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $service работает${NC}"
        return 0
    else
        echo -e "${RED}❌ $service не отвечает${NC}"
        ISSUES=$((ISSUES + 1))
        return 1
    fi
}

check_disk() {
    local usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$usage" -lt 85 ]; then
        echo -e "${GREEN}✅ Диск: ${usage}% использовано${NC}"
    else
        echo -e "${YELLOW}⚠️  Диск: ${usage}% использовано (рекомендуется <85%)${NC}"
        ISSUES=$((ISSUES + 1))
    fi
}

check_memory() {
    local usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
    if [ "$usage" -lt 85 ]; then
        echo -e "${GREEN}✅ Память: ${usage}% использовано${NC}"
    else
        echo -e "${YELLOW}⚠️  Память: ${usage}% использовано (рекомендуется <85%)${NC}"
        ISSUES=$((ISSUES + 1))
    fi
}

check_docker() {
    if docker ps | grep -q digroup; then
        echo -e "${GREEN}✅ Docker контейнер DIGroup запущен${NC}"
    else
        echo -e "${RED}❌ Docker контейнер DIGroup не запущен${NC}"
        ISSUES=$((ISSUES + 1))
    fi
}

check_nginx() {
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✅ Nginx работает${NC}"
    else
        echo -e "${RED}❌ Nginx не работает${NC}"
        ISSUES=$((ISSUES + 1))
    fi
}

echo "🔍 Проверка здоровья системы DIGroup"
echo "===================================="
echo ""

check_service "DIGroup Kernel" "6806"
check_docker
check_nginx
check_disk
check_memory

# Проверка последнего бэкапа
if [ -d "/opt/digroup/backups" ]; then
    LAST_BACKUP=$(find /opt/digroup/backups -name "*.tar.gz" -type f -mtime -1 | head -1)
    if [ -n "$LAST_BACKUP" ]; then
        echo -e "${GREEN}✅ Последний бэкап: $(basename $LAST_BACKUP)${NC}"
    else
        echo -e "${YELLOW}⚠️  Бэкап не создавался более 24 часов${NC}"
        ISSUES=$((ISSUES + 1))
    fi
fi

echo ""
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✅ Все проверки пройдены успешно!${NC}"
    exit 0
else
    echo -e "${RED}❌ Обнаружено проблем: $ISSUES${NC}"
    exit 1
fi

