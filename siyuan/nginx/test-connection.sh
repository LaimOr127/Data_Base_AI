#!/bin/bash
# Скрипт для тестирования подключения к DIGroup
# Использование: ./test-connection.sh

echo "🔍 Тестирование подключения к DIGroup"
echo "======================================="
echo ""

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Проверка 1: Kernel запущен?
echo "1️⃣  Проверка kernel..."
if pgrep -f "SiYuan-Kernel" > /dev/null; then
    echo -e "${GREEN}✅ Kernel запущен${NC}"
    KERNEL_PID=$(pgrep -f "SiYuan-Kernel" | head -1)
    echo "   PID: $KERNEL_PID"
else
    echo -e "${RED}❌ Kernel НЕ запущен${NC}"
    echo ""
    echo "   Запустите kernel:"
    echo "   cd /path/to/digroup/app/kernel"
    echo "   ./SiYuan-Kernel --workspace=/path/to/workspace --accessAuthCode=КОД --port=6806 &"
    echo ""
fi

# Проверка 2: Порт 6806
echo ""
echo "2️⃣  Проверка порта 6806..."
if lsof -i :6806 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Порт 6806 используется${NC}"
    lsof -i :6806
else
    echo -e "${RED}❌ Порт 6806 не используется${NC}"
fi

# Проверка 3: Kernel отвечает?
echo ""
echo "3️⃣  Проверка доступности kernel..."
RESPONSE=$(curl -s -m 5 http://127.0.0.1:6806/api/system/version 2>&1)
if echo "$RESPONSE" | grep -q "code"; then
    echo -e "${GREEN}✅ Kernel отвечает${NC}"
    echo "   Ответ: $RESPONSE"
else
    echo -e "${RED}❌ Kernel не отвечает${NC}"
    echo "   Ошибка: $RESPONSE"
    echo ""
    echo "   Проверьте:"
    echo "   1. Kernel запущен?"
    echo "   2. Порт 6806 свободен?"
    echo "   3. Нет ошибок при запуске kernel?"
fi

# Проверка 4: Nginx запущен?
echo ""
echo "4️⃣  Проверка Nginx..."
if systemctl is-active --quiet nginx 2>/dev/null || pgrep nginx > /dev/null; then
    echo -e "${GREEN}✅ Nginx запущен${NC}"
else
    echo -e "${RED}❌ Nginx не запущен${NC}"
    echo "   Запустите: sudo systemctl start nginx"
fi

# Проверка 5: Nginx слушает порт 80?
echo ""
echo "5️⃣  Проверка порта 80..."
if lsof -i :80 > /dev/null 2>&1 || netstat -tlnp 2>/dev/null | grep -q ":80 "; then
    echo -e "${GREEN}✅ Порт 80 используется${NC}"
    if command -v lsof > /dev/null; then
        lsof -i :80 | head -3
    else
        netstat -tlnp 2>/dev/null | grep ":80 "
    fi
else
    echo -e "${RED}❌ Порт 80 не используется${NC}"
    echo "   Nginx не слушает порт 80"
fi

# Проверка 6: Доступ через Nginx
echo ""
echo "6️⃣  Проверка доступа через Nginx..."
NGINX_RESPONSE=$(curl -s -m 5 http://localhost/api/system/version 2>&1)
if echo "$NGINX_RESPONSE" | grep -q "code"; then
    echo -e "${GREEN}✅ Nginx проксирует запросы${NC}"
    echo "   Ответ: $NGINX_RESPONSE"
else
    echo -e "${RED}❌ Nginx не проксирует запросы${NC}"
    echo "   Ошибка: $NGINX_RESPONSE"
    echo ""
    echo "   Проверьте:"
    echo "   1. Конфигурация Nginx правильная?"
    echo "   2. Конфигурация активирована?"
    echo "   3. Nginx перезагружен после изменений?"
fi

# Проверка 7: Конфигурация Nginx
echo ""
echo "7️⃣  Проверка конфигурации Nginx..."
if [ -f /etc/nginx/sites-available/digroup ]; then
    echo -e "${GREEN}✅ Файл конфигурации существует${NC}"
    
    # Проверка map
    if grep -q "map.*connection_upgrade" /etc/nginx/sites-available/digroup; then
        echo -e "${GREEN}✅ Map для WebSocket найден${NC}"
    else
        echo -e "${YELLOW}⚠️  Map для WebSocket не найден${NC}"
    fi
    
    # Проверка location /ws
    if grep -q "location /ws" /etc/nginx/sites-available/digroup; then
        echo -e "${GREEN}✅ Location /ws найден${NC}"
    else
        echo -e "${YELLOW}⚠️  Location /ws не найден${NC}"
    fi
    
    # Проверка синтаксиса
    if sudo nginx -t 2>&1 | grep -q "successful"; then
        echo -e "${GREEN}✅ Синтаксис конфигурации корректен${NC}"
    else
        echo -e "${RED}❌ Ошибки в конфигурации:${NC}"
        sudo nginx -t 2>&1 | tail -5
    fi
else
    echo -e "${RED}❌ Файл конфигурации не найден${NC}"
    echo "   Создайте: /etc/nginx/sites-available/digroup"
fi

# Проверка 8: Логи ошибок
echo ""
echo "8️⃣  Последние ошибки Nginx..."
if [ -f /var/log/nginx/digroup-error.log ]; then
    ERROR_COUNT=$(sudo tail -20 /var/log/nginx/digroup-error.log | wc -l)
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}Последние ошибки (последние 5 строк):${NC}"
        sudo tail -5 /var/log/nginx/digroup-error.log
    else
        echo -e "${GREEN}✅ Нет ошибок в логах${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Файл логов не найден${NC}"
fi

# Итоговые рекомендации
echo ""
echo "📋 Рекомендации:"
echo "================"

if ! pgrep -f "SiYuan-Kernel" > /dev/null; then
    echo -e "${RED}1. ЗАПУСТИТЕ KERNEL!${NC}"
    echo "   Это самая частая причина проблем"
fi

if ! curl -s -m 5 http://127.0.0.1:6806/api/system/version > /dev/null; then
    echo -e "${RED}2. Kernel не отвечает на порту 6806${NC}"
    echo "   Проверьте запуск kernel и логи"
fi

if ! systemctl is-active --quiet nginx 2>/dev/null && ! pgrep nginx > /dev/null; then
    echo -e "${RED}3. Запустите Nginx${NC}"
fi

if [ -f /etc/nginx/sites-available/digroup ] && ! sudo nginx -t 2>&1 | grep -q "successful"; then
    echo -e "${RED}4. Исправьте ошибки в конфигурации Nginx${NC}"
fi

echo ""
echo "📝 Полезные команды:"
echo "   # Проверка kernel"
echo "   curl http://127.0.0.1:6806/api/system/version"
echo ""
echo "   # Проверка через Nginx"
echo "   curl http://localhost/api/system/version"
echo ""
echo "   # Логи Nginx"
echo "   sudo tail -f /var/log/nginx/digroup-error.log"
echo ""
echo "   # Перезагрузка Nginx"
echo "   sudo nginx -t && sudo systemctl reload nginx"

