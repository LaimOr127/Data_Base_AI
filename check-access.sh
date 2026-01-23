#!/bin/bash
# Скрипт для проверки доступа к сервисам DIGroup

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN="digroupdb.duckdns.org"
SERVER_IP="85.198.99.150"

echo -e "${BLUE}🔍 Проверка доступа к сервисам DIGroup${NC}"
echo ""

# Проверка DNS
echo -e "${BLUE}1. Проверка DNS...${NC}"
DNS_IP=$(dig +short $DOMAIN 2>/dev/null | head -1)
if [ "$DNS_IP" == "$SERVER_IP" ]; then
    echo -e "${GREEN}✅ DNS настроен правильно: $DOMAIN → $DNS_IP${NC}"
else
    echo -e "${RED}❌ DNS не настроен или указывает на другой IP${NC}"
    echo "   Ожидается: $SERVER_IP"
    echo "   Получено: $DNS_IP"
fi
echo ""

# Проверка HTTP редиректа
echo -e "${BLUE}2. Проверка HTTP редиректа...${NC}"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -L http://$DOMAIN 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" == "200" ] || [ "$HTTP_STATUS" == "301" ] || [ "$HTTP_STATUS" == "302" ]; then
    echo -e "${GREEN}✅ HTTP доступен (код: $HTTP_STATUS)${NC}"
else
    echo -e "${RED}❌ HTTP недоступен (код: $HTTP_STATUS)${NC}"
fi
echo ""

# Проверка HTTPS
echo -e "${BLUE}3. Проверка HTTPS...${NC}"
HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -k https://$DOMAIN 2>/dev/null || echo "000")
if [ "$HTTPS_STATUS" == "200" ] || [ "$HTTPS_STATUS" == "403" ] || [ "$HTTPS_STATUS" == "404" ]; then
    echo -e "${GREEN}✅ HTTPS доступен (код: $HTTPS_STATUS)${NC}"
else
    echo -e "${RED}❌ HTTPS недоступен (код: $HTTPS_STATUS)${NC}"
fi
echo ""

# Проверка API
echo -e "${BLUE}4. Проверка API...${NC}"
API_RESPONSE=$(curl -s -k https://$DOMAIN/api/system/version 2>/dev/null || echo "")
if echo "$API_RESPONSE" | grep -q "3.4.2"; then
    echo -e "${GREEN}✅ API работает: $API_RESPONSE${NC}"
else
    echo -e "${YELLOW}⚠️  API не отвечает или ответ неожиданный: $API_RESPONSE${NC}"
fi
echo ""

# Проверка прямого доступа по IP
echo -e "${BLUE}5. Проверка прямого доступа по IP...${NC}"
IP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$SERVER_IP:6806/api/system/version 2>/dev/null || echo "000")
if [ "$IP_STATUS" == "200" ]; then
    echo -e "${GREEN}✅ Прямой доступ по IP работает${NC}"
else
    echo -e "${YELLOW}⚠️  Прямой доступ по IP недоступен (код: $IP_STATUS)${NC}"
fi
echo ""

# Итоговая информация
echo -e "${BLUE}📋 Итоговая информация:${NC}"
echo ""
echo "Доступ к сервисам:"
echo -e "  - ${GREEN}DIGroup:${NC} https://$DOMAIN"
echo -e "  - ${GREEN}Grafana:${NC} https://grafana.$DOMAIN"
echo -e "  - ${GREEN}Prometheus:${NC} https://prometheus.$DOMAIN"
echo ""
echo "Прямой доступ по IP (если домен не работает):"
echo -e "  - ${GREEN}DIGroup:${NC} http://$SERVER_IP:6806"
echo -e "  - ${GREEN}Grafana:${NC} http://$SERVER_IP:3000"
echo -e "  - ${GREEN}Prometheus:${NC} http://$SERVER_IP:9090"
echo ""
echo -e "${YELLOW}⚠️  Примечание:${NC} Если используется самоподписанный SSL сертификат,"
echo "   браузер покажет предупреждение о безопасности. Это нормально."
echo "   Нажмите 'Дополнительно' → 'Перейти на сайт'"
echo ""
