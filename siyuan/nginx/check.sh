#!/bin/bash
# Простая проверка без sudo (для диагностики)
# Использование: ./check.sh

echo "🔍 Проверка DIGroup (без sudo)"
echo "=============================="
echo ""

# Проверка 1: Kernel
echo "1️⃣  Kernel..."
if pgrep -f "SiYuan-Kernel" > /dev/null; then
    echo "✅ Kernel запущен (PID: $(pgrep -f 'SiYuan-Kernel' | head -1))"
else
    echo "❌ Kernel НЕ запущен"
    echo ""
    echo "Запустите:"
    echo "cd /path/to/digroup/app/kernel"
    echo "./SiYuan-Kernel --workspace=/path/to/workspace --accessAuthCode=КОД --port=6806 &"
fi

# Проверка 2: Kernel отвечает
echo ""
echo "2️⃣  Kernel отвечает?"
RESPONSE=$(curl -s -m 3 http://127.0.0.1:6806/api/system/version 2>&1)
if echo "$RESPONSE" | grep -q "code"; then
    echo "✅ Да, отвечает"
    echo "   Версия: $RESPONSE"
else
    echo "❌ Нет, не отвечает"
    echo "   Ошибка: $RESPONSE"
fi

# Проверка 3: Nginx
echo ""
echo "3️⃣  Nginx..."
if pgrep nginx > /dev/null; then
    echo "✅ Nginx запущен"
else
    echo "❌ Nginx не запущен"
    echo "   Запустите: sudo systemctl start nginx"
fi

# Проверка 4: Доступ через Nginx
echo ""
echo "4️⃣  Доступ через Nginx?"
NGINX_RESPONSE=$(curl -s -m 3 http://localhost/api/system/version 2>&1)
if echo "$NGINX_RESPONSE" | grep -q "code"; then
    echo "✅ Да, работает"
    echo "   Ответ: $NGINX_RESPONSE"
else
    echo "❌ Нет, не работает"
    echo "   Ошибка: $NGINX_RESPONSE"
fi

# Проверка 5: Порт 80
echo ""
echo "5️⃣  Порт 80..."
if netstat -tln 2>/dev/null | grep -q ":80 " || ss -tln 2>/dev/null | grep -q ":80 "; then
    echo "✅ Порт 80 используется"
else
    echo "❌ Порт 80 не используется"
fi

# Получение IP
echo ""
echo "6️⃣  IP адрес сервера:"
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null || echo "не определен")
echo "   $SERVER_IP"

echo ""
echo "📋 Что проверить дальше:"
echo "   1. Если kernel не запущен - запустите его"
echo "   2. Если kernel не отвечает - проверьте логи"
echo "   3. Если Nginx не работает - нужен sudo для настройки"
echo ""
echo "🌐 Для доступа используйте:"
echo "   http://$SERVER_IP"

