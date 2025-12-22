#!/bin/bash
# Скрипт диагностики проблем с Nginx и DIGroup
# Использование: sudo ./diagnose.sh

echo "🔍 Диагностика DIGroup + Nginx"
echo "================================"
echo ""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Проверка 1: Kernel запущен?
echo "1️⃣  Проверка kernel..."
if pgrep -f "SiYuan-Kernel" > /dev/null; then
    echo -e "${GREEN}✅ Kernel запущен${NC}"
    KERNEL_PID=$(pgrep -f "SiYuan-Kernel" | head -1)
    echo "   PID: $KERNEL_PID"
else
    echo -e "${RED}❌ Kernel НЕ запущен${NC}"
    echo "   Запустите: ./SiYuan-Kernel --workspace=/path --accessAuthCode=КОД --port=6806"
fi
echo ""

# Проверка 2: Порт 6806 доступен?
echo "2️⃣  Проверка порта 6806..."
if lsof -i :6806 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Порт 6806 используется${NC}"
    lsof -i :6806
else
    echo -e "${RED}❌ Порт 6806 не используется${NC}"
fi
echo ""

# Проверка 3: Kernel отвечает?
echo "3️⃣  Проверка доступности kernel..."
if curl -s -m 5 http://127.0.0.1:6806/api/system/version > /dev/null; then
    VERSION=$(curl -s -m 5 http://127.0.0.1:6806/api/system/version)
    echo -e "${GREEN}✅ Kernel отвечает${NC}"
    echo "   Версия: $VERSION"
else
    echo -e "${RED}❌ Kernel не отвечает${NC}"
    echo "   Проверьте, что kernel запущен и слушает порт 6806"
fi
echo ""

# Проверка 4: Nginx запущен?
echo "4️⃣  Проверка Nginx..."
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ Nginx запущен${NC}"
else
    echo -e "${RED}❌ Nginx не запущен${NC}"
    echo "   Запустите: sudo systemctl start nginx"
fi
echo ""

# Проверка 5: Конфигурация Nginx
echo "5️⃣  Проверка конфигурации Nginx..."
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo -e "${GREEN}✅ Конфигурация корректна${NC}"
else
    echo -e "${RED}❌ Ошибки в конфигурации:${NC}"
    sudo nginx -t
fi
echo ""

# Проверка 6: Конфигурация digroup существует?
echo "6️⃣  Проверка конфигурации digroup..."
if [ -f /etc/nginx/sites-available/digroup ]; then
    echo -e "${GREEN}✅ Файл конфигурации существует${NC}"
    if [ -L /etc/nginx/sites-enabled/digroup ]; then
        echo -e "${GREEN}✅ Конфигурация активирована${NC}"
    else
        echo -e "${YELLOW}⚠️  Конфигурация не активирована${NC}"
        echo "   Активируйте: sudo ln -s /etc/nginx/sites-available/digroup /etc/nginx/sites-enabled/"
    fi
else
    echo -e "${RED}❌ Файл конфигурации не найден${NC}"
    echo "   Создайте: /etc/nginx/sites-available/digroup"
fi
echo ""

# Проверка 7: WebSocket в конфигурации
echo "7️⃣  Проверка WebSocket настроек..."
if [ -f /etc/nginx/sites-available/digroup ]; then
    if grep -q "location /ws" /etc/nginx/sites-available/digroup && \
       grep -q "Upgrade" /etc/nginx/sites-available/digroup && \
       grep -q "Connection" /etc/nginx/sites-available/digroup; then
        echo -e "${GREEN}✅ WebSocket настройки найдены${NC}"
    else
        echo -e "${YELLOW}⚠️  WebSocket настройки могут быть неполными${NC}"
    fi
    
    if grep -q "map.*connection_upgrade" /etc/nginx/sites-available/digroup; then
        echo -e "${GREEN}✅ Map для Connection найден${NC}"
    else
        echo -e "${YELLOW}⚠️  Map для Connection не найден (может быть в nginx.conf)${NC}"
    fi
fi
echo ""

# Проверка 8: Последние ошибки в логах
echo "8️⃣  Последние ошибки Nginx (последние 10 строк)..."
if [ -f /var/log/nginx/digroup-error.log ]; then
    echo -e "${YELLOW}Последние ошибки:${NC}"
    sudo tail -10 /var/log/nginx/digroup-error.log
else
    echo -e "${YELLOW}Файл логов не найден${NC}"
fi
echo ""

# Проверка 9: Firewall
echo "9️⃣  Проверка firewall..."
if command -v ufw &> /dev/null; then
    if ufw status | grep -q "80/tcp.*ALLOW" && ufw status | grep -q "443/tcp.*ALLOW"; then
        echo -e "${GREEN}✅ Порты 80 и 443 открыты в UFW${NC}"
    else
        echo -e "${YELLOW}⚠️  Порты могут быть закрыты${NC}"
        echo "   Проверьте: sudo ufw status"
    fi
elif command -v firewall-cmd &> /dev/null; then
    if firewall-cmd --list-services | grep -q "http" && firewall-cmd --list-services | grep -q "https"; then
        echo -e "${GREEN}✅ HTTP и HTTPS разрешены в firewalld${NC}"
    else
        echo -e "${YELLOW}⚠️  HTTP/HTTPS могут быть заблокированы${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Firewall не найден или не настроен${NC}"
fi
echo ""

# Проверка 10: SSL сертификат
echo "🔟 Проверка SSL сертификата..."
if command -v certbot &> /dev/null; then
    if [ -f /etc/letsencrypt/live/*/fullchain.pem ]; then
        echo -e "${GREEN}✅ SSL сертификат найден${NC}"
        sudo certbot certificates 2>/dev/null | grep -A 5 "Certificate Name"
    else
        echo -e "${YELLOW}⚠️  SSL сертификат не найден${NC}"
        echo "   Получите: sudo certbot --nginx -d digroup.yourdomain.com"
    fi
else
    echo -e "${YELLOW}⚠️  Certbot не установлен${NC}"
fi
echo ""

# Итоговые рекомендации
echo "📋 Рекомендации:"
echo "================"

if ! pgrep -f "SiYuan-Kernel" > /dev/null; then
    echo -e "${RED}1. Запустите kernel!${NC}"
fi

if ! curl -s -m 5 http://127.0.0.1:6806/api/system/version > /dev/null; then
    echo -e "${RED}2. Kernel не отвечает - проверьте запуск${NC}"
fi

if ! systemctl is-active --quiet nginx; then
    echo -e "${RED}3. Запустите Nginx: sudo systemctl start nginx${NC}"
fi

if [ -f /etc/nginx/sites-available/digroup ] && ! sudo nginx -t 2>&1 | grep -q "successful"; then
    echo -e "${RED}4. Исправьте ошибки в конфигурации Nginx${NC}"
fi

echo ""
echo "📝 Полезные команды:"
echo "   sudo systemctl status nginx"
echo "   sudo tail -f /var/log/nginx/digroup-error.log"
echo "   curl http://127.0.0.1:6806/api/system/version"
echo "   sudo nginx -t"

