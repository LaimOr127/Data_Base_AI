#!/bin/bash
# Скрипт настройки Nginx для DIGroup по IP адресу (без домена, без SSL)
# Использование: sudo ./setup-ip.sh

set -e

echo "🚀 Настройка Nginx для DIGroup по IP адресу"
echo "=============================================="
echo ""

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Ошибка: Запустите скрипт с sudo"
    exit 1
fi

# Получение IP адреса сервера
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
echo "📡 IP адрес сервера: $SERVER_IP"
echo ""

# Шаг 1: Установка Nginx
echo "📦 Проверка установки Nginx..."
if ! command -v nginx &> /dev/null; then
    echo "Установка Nginx..."
    apt update
    apt install -y nginx
else
    echo "✅ Nginx уже установлен"
fi

# Шаг 2: Создание конфигурации
echo "📝 Создание конфигурации Nginx..."

CONFIG_FILE="/etc/nginx/sites-available/digroup"
CONFIG_LINK="/etc/nginx/sites-enabled/digroup"

# Копируем конфигурацию
if [ -f "digroup-ip.conf" ]; then
    cp digroup-ip.conf "$CONFIG_FILE"
    echo "✅ Конфигурация скопирована из digroup-ip.conf"
else
    # Создаем конфигурацию напрямую
    cat > "$CONFIG_FILE" <<'EOF'
# Конфигурация Nginx для DIGroup по IP адресу
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
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 60;
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    location /ws {
        proxy_pass http://127.0.0.1:6806;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 60;
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
EOF
    echo "✅ Конфигурация создана"
fi

# Активируем конфигурацию
if [ -L "$CONFIG_LINK" ]; then
    rm "$CONFIG_LINK"
fi
ln -s "$CONFIG_FILE" "$CONFIG_LINK"

# Удаляем дефолтную конфигурацию (опционально)
if [ -L /etc/nginx/sites-enabled/default ]; then
    echo "⚠️  Удаление дефолтной конфигурации Nginx..."
    rm /etc/nginx/sites-enabled/default
fi

# Проверка конфигурации
echo "🔍 Проверка конфигурации Nginx..."
if nginx -t; then
    echo "✅ Конфигурация корректна"
    systemctl reload nginx
else
    echo "❌ Ошибка в конфигурации Nginx"
    exit 1
fi

# Шаг 3: Настройка firewall
echo "🔥 Настройка firewall..."
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp
    echo "✅ Порт 80 открыт в UFW"
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --reload
    echo "✅ HTTP разрешен в firewalld"
else
    echo "⚠️  Firewall не найден, настройте вручную"
fi

echo ""
echo "✅ Настройка завершена!"
echo ""
echo "📋 Следующие шаги:"
echo "1. Убедитесь, что DIGroup kernel запущен на порту 6806"
echo "2. Откройте в браузере: http://$SERVER_IP"
echo "3. Введите AccessAuthCode для входа"
echo ""
echo "⚠️  ВАЖНО: Это HTTP (не HTTPS) - данные передаются незашифрованными!"
echo "   Используйте только для тестирования в безопасной сети."
echo ""
echo "📊 Проверка:"
echo "   sudo systemctl status nginx"
echo "   curl http://127.0.0.1:6806/api/system/version"
echo "   curl http://$SERVER_IP/api/system/version"

