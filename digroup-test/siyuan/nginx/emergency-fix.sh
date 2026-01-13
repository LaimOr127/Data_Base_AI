#!/bin/bash
# Экстренное исправление проблем с Nginx и DIGroup
# Использование: sudo ./emergency-fix.sh

set -e

echo "🚨 Экстренное исправление проблем"
echo "==================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "❌ Запустите с sudo"
    exit 1
fi

# Шаг 1: Проверка kernel
echo "1️⃣  Проверка kernel..."
if ! curl -s -m 3 http://127.0.0.1:6806/api/system/version > /dev/null; then
    echo "⚠️  Kernel не отвечает!"
    echo ""
    echo "Запустите kernel вручную:"
    echo "cd /path/to/digroup/app/kernel"
    echo "./SiYuan-Kernel --workspace=/path/to/workspace --accessAuthCode=КОД --port=6806 &"
    echo ""
    read -p "Продолжить настройку Nginx? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ Kernel отвечает"
fi

# Шаг 2: Установка минимальной конфигурации
echo ""
echo "2️⃣  Установка минимальной конфигурации..."

CONFIG_FILE="/etc/nginx/sites-available/digroup"

# Создаем минимальную конфигурацию
cat > "$CONFIG_FILE" <<'EOF'
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80 default_server;
    
    access_log /var/log/nginx/digroup-access.log;
    error_log /var/log/nginx/digroup-error.log;
    
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://127.0.0.1:6806;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_read_timeout 300;
        proxy_send_timeout 300;
        proxy_buffering off;
    }
}
EOF

echo "✅ Конфигурация создана"

# Шаг 3: Активация
echo ""
echo "3️⃣  Активация конфигурации..."

# Удаляем старые ссылки
rm -f /etc/nginx/sites-enabled/digroup
rm -f /etc/nginx/sites-enabled/default

# Создаем новую ссылку
ln -s "$CONFIG_FILE" /etc/nginx/sites-enabled/digroup

echo "✅ Конфигурация активирована"

# Шаг 4: Проверка и перезагрузка
echo ""
echo "4️⃣  Проверка конфигурации..."
if nginx -t; then
    echo "✅ Конфигурация корректна"
    systemctl reload nginx
    echo "✅ Nginx перезагружен"
else
    echo "❌ Ошибка в конфигурации:"
    nginx -t
    exit 1
fi

# Шаг 5: Firewall
echo ""
echo "5️⃣  Настройка firewall..."
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp 2>/dev/null || true
    echo "✅ Порт 80 открыт в UFW"
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-service=http 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    echo "✅ HTTP разрешен в firewalld"
fi

# Шаг 6: Получение IP
echo ""
echo "6️⃣  IP адрес сервера:"
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
echo "   $SERVER_IP"

echo ""
echo "✅ Настройка завершена!"
echo ""
echo "📋 Проверка:"
echo "   1. Kernel запущен: curl http://127.0.0.1:6806/api/system/version"
echo "   2. Nginx работает: curl http://localhost/api/system/version"
echo "   3. Доступ по IP: curl http://$SERVER_IP/api/system/version"
echo ""
echo "🌐 Откройте в браузере:"
echo "   http://$SERVER_IP"
echo ""

