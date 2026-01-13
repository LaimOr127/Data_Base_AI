#!/bin/bash
# Установка SSL сертификата через Let's Encrypt
# Использование: sudo ./install-ssl.sh your-domain.com your-email@example.com

set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Проверка аргументов
if [ $# -lt 2 ]; then
    echo -e "${RED}❌ Использование: sudo ./install-ssl.sh DOMAIN EMAIL${NC}"
    echo "Пример: sudo ./install-ssl.sh digroup.example.com admin@example.com"
    exit 1
fi

DOMAIN=$1
EMAIL=$2

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Пожалуйста, запустите скрипт с правами root: sudo ./install-ssl.sh${NC}"
    exit 1
fi

echo -e "${BLUE}🔐 Установка SSL сертификата для $DOMAIN${NC}"
echo ""

# Установка Certbot
if ! command -v certbot &> /dev/null; then
    echo -e "${BLUE}Установка Certbot...${NC}"
    apt update
    apt install -y certbot python3-certbot-nginx
    echo -e "${GREEN}✅ Certbot установлен${NC}"
else
    echo -e "${GREEN}✅ Certbot уже установлен${NC}"
fi

# Обновление конфигурации Nginx с доменом
if [ -f /etc/nginx/sites-available/digroup ]; then
    sed -i "s/server_name _;/server_name $DOMAIN;/" /etc/nginx/sites-available/digroup
    systemctl reload nginx
    echo -e "${GREEN}✅ Конфигурация Nginx обновлена${NC}"
fi

# Получение сертификата
echo ""
echo -e "${BLUE}Получение SSL сертификата...${NC}"
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ SSL сертификат установлен${NC}"
    echo ""
    echo -e "${BLUE}📋 Настройка автообновления сертификата...${NC}"
    
    # Проверка наличия cron задачи для обновления
    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
        echo -e "${GREEN}✅ Автообновление сертификата настроено${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✅ SSL настроен!${NC}"
    echo ""
    echo -e "${BLUE}🌐 Доступ:${NC}"
    echo "   HTTPS: https://$DOMAIN"
    echo ""
else
    echo -e "${RED}❌ Ошибка при получении сертификата${NC}"
    exit 1
fi

