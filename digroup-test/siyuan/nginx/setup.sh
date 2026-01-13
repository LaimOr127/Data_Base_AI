#!/bin/bash
# Скрипт автоматической настройки Nginx + SSL для DIGroup
# Использование: sudo ./setup.sh digroup.yourdomain.com

set -e

# Проверка аргументов
if [ -z "$1" ]; then
    echo "Использование: sudo ./setup.sh digroup.yourdomain.com"
    exit 1
fi

DOMAIN=$1
CONFIG_FILE="/etc/nginx/sites-available/digroup"
CONFIG_LINK="/etc/nginx/sites-enabled/digroup"

echo "🚀 Настройка Nginx + SSL для DIGroup"
echo "Домен: $DOMAIN"
echo ""

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Ошибка: Запустите скрипт с sudo"
    exit 1
fi

# Шаг 1: Установка Nginx
echo "📦 Проверка установки Nginx..."
if ! command -v nginx &> /dev/null; then
    echo "Установка Nginx..."
    apt update
    apt install -y nginx
else
    echo "✅ Nginx уже установлен"
fi

# Шаг 2: Установка Certbot
echo "📦 Проверка установки Certbot..."
if ! command -v certbot &> /dev/null; then
    echo "Установка Certbot..."
    apt install -y certbot python3-certbot-nginx
else
    echo "✅ Certbot уже установлен"
fi

# Шаг 3: Создание конфигурации Nginx
echo "📝 Создание конфигурации Nginx..."

# Создаем временную конфигурацию без SSL (для получения сертификата)
cat > /tmp/digroup-nginx.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    access_log /var/log/nginx/digroup-access.log;
    error_log /var/log/nginx/digroup-error.log;
    
    location / {
        proxy_pass http://127.0.0.1:6806;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 60;
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
EOF

# Копируем конфигурацию
cp /tmp/digroup-nginx.conf "$CONFIG_FILE"

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

# Шаг 4: Проверка DNS
echo "🔍 Проверка DNS записи для $DOMAIN..."
DNS_IP=$(dig +short $DOMAIN | tail -n1)
SERVER_IP=$(curl -s ifconfig.me)

if [ -z "$DNS_IP" ]; then
    echo "⚠️  Внимание: DNS запись для $DOMAIN не найдена"
    echo "   Убедитесь, что A-запись настроена и указывает на IP: $SERVER_IP"
    read -p "Продолжить? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ DNS запись найдена: $DNS_IP"
    if [ "$DNS_IP" != "$SERVER_IP" ]; then
        echo "⚠️  Внимание: DNS IP ($DNS_IP) не совпадает с IP сервера ($SERVER_IP)"
        read -p "Продолжить? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

# Шаг 5: Получение SSL сертификата
echo "🔐 Получение SSL сертификата от Let's Encrypt..."
echo "   Вам будет предложено ввести email для уведомлений"
echo ""

certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --redirect

# Шаг 6: Проверка финальной конфигурации
echo "🔍 Проверка финальной конфигурации..."
if nginx -t; then
    echo "✅ Конфигурация корректна"
    systemctl reload nginx
else
    echo "❌ Ошибка в конфигурации Nginx"
    exit 1
fi

# Шаг 7: Настройка firewall
echo "🔥 Настройка firewall..."
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    echo "✅ Порты 80 и 443 открыты в UFW"
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
    echo "✅ Порты 80 и 443 открыты в firewalld"
else
    echo "⚠️  Firewall не найден, настройте вручную"
fi

# Шаг 8: Проверка автоматического обновления SSL
echo "🔄 Проверка автоматического обновления SSL..."
systemctl enable certbot.timer
systemctl start certbot.timer

echo ""
echo "✅ Настройка завершена!"
echo ""
echo "📋 Следующие шаги:"
echo "1. Убедитесь, что DIGroup kernel запущен на порту 6806"
echo "2. Откройте в браузере: https://$DOMAIN"
echo "3. Введите AccessAuthCode для входа"
echo ""
echo "📊 Проверка статуса:"
echo "   sudo systemctl status nginx"
echo "   sudo systemctl status certbot.timer"
echo ""
echo "📝 Логи:"
echo "   sudo tail -f /var/log/nginx/digroup-access.log"
echo "   sudo tail -f /var/log/nginx/digroup-error.log"

