#!/bin/bash
# Автоматическая настройка доменных имен для DIGroup
# Использование: ./setup-domains.sh

set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Параметры сервера
SERVER_IP="85.198.99.150"
SERVER_USER="root"
SERVER_PASSWORD="!K5kUHw6Hc0%"
DOMAIN="digroupdb.duckdns.org"
EMAIL="admin@${DOMAIN}"  # Можно изменить на реальный email

# Функция для выполнения команд на удаленном сервере
run_remote() {
    sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=10 \
        "$SERVER_USER@$SERVER_IP" "$@"
}

echo -e "${BLUE}🌐 Настройка доменных имен для DIGroup${NC}"
echo -e "${BLUE}Домен: ${DOMAIN}${NC}"
echo ""

# Проверка наличия sshpass
if ! command -v sshpass &> /dev/null; then
    echo -e "${YELLOW}⚠️  Установка sshpass...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install hudochenkov/sshpass/sshpass || echo -e "${RED}❌ Не удалось установить sshpass. Установите вручную: brew install hudochenkov/sshpass/sshpass${NC}"
    else
        sudo apt-get update && sudo apt-get install -y sshpass
    fi
fi

echo -e "${BLUE}📦 Установка Nginx на сервере...${NC}"
run_remote 'bash -s' << 'REMOTE_SCRIPT'
set -e

# Обновление системы
apt-get update -qq

# Установка Nginx
if ! command -v nginx &> /dev/null; then
    apt-get install -y nginx
    systemctl enable nginx
    echo "✅ Nginx установлен"
else
    echo "✅ Nginx уже установлен"
fi

# Установка Certbot
if ! command -v certbot &> /dev/null; then
    apt-get install -y certbot python3-certbot-nginx
    echo "✅ Certbot установлен"
else
    echo "✅ Certbot уже установлен"
fi

# Создание директории для ACME challenge
mkdir -p /var/www/certbot
chown -R www-data:www-data /var/www/certbot

REMOTE_SCRIPT

echo -e "${GREEN}✅ Nginx и Certbot установлены${NC}"
echo ""

echo -e "${BLUE}📝 Копирование конфигурации Nginx...${NC}"

# Читаем конфигурацию Nginx
NGINX_CONFIG=$(cat << 'NGINX_EOF'
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

# Редирект HTTP на HTTPS для основного домена
server {
    listen 80;
    server_name digroupdb.duckdns.org;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS - Основной сервис DIGroup
server {
    listen 443 ssl http2;
    server_name digroupdb.duckdns.org;
    
    # SSL сертификаты (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/digroupdb.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/digroupdb.duckdns.org/privkey.pem;
    
    # SSL настройки
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    access_log /var/log/nginx/digroup-access.log;
    error_log /var/log/nginx/digroup-error.log;
    
    client_max_body_size 100M;
    
    # Безопасность заголовков
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    location / {
        proxy_pass http://127.0.0.1:6806;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        
        # Увеличенные таймауты для WebSocket
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 60s;
        proxy_buffering off;
        proxy_cache_bypass $http_upgrade;
    }
    
    # Кэширование статических файлов
    location /assets/ {
        proxy_pass http://127.0.0.1:6806;
        proxy_cache_valid 200 1h;
        expires 1h;
        add_header Cache-Control "public, immutable";
    }
}

# HTTP - Grafana
server {
    listen 80;
    server_name grafana.digroupdb.duckdns.org;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS - Grafana
server {
    listen 443 ssl http2;
    server_name grafana.digroupdb.duckdns.org;
    
    ssl_certificate /etc/letsencrypt/live/digroupdb.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/digroupdb.duckdns.org/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    access_log /var/log/nginx/grafana-access.log;
    error_log /var/log/nginx/grafana-error.log;
    
    client_max_body_size 50M;
    
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
}

# HTTP - Prometheus
server {
    listen 80;
    server_name prometheus.digroupdb.duckdns.org;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS - Prometheus
server {
    listen 443 ssl http2;
    server_name prometheus.digroupdb.duckdns.org;
    
    ssl_certificate /etc/letsencrypt/live/digroupdb.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/digroupdb.duckdns.org/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    access_log /var/log/nginx/prometheus-access.log;
    error_log /var/log/nginx/prometheus-error.log;
    
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    
    location / {
        proxy_pass http://127.0.0.1:9090;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
    }
}
NGINX_EOF
)

echo -e "${BLUE}🔐 Получение SSL сертификатов...${NC}"
echo -e "${YELLOW}⚠️  Убедитесь, что DNS запись настроена для домена:${NC}"
echo -e "   - ${DOMAIN} → ${SERVER_IP}"
echo -e "${YELLOW}ℹ️  Примечание: DuckDNS не поддерживает субдомены напрямую.${NC}"
echo -e "${YELLOW}   Сертификат будет получен для основного домена и использован для всех сервисов.${NC}"
echo ""

# Сначала создаем временную конфигурацию только для HTTP (для ACME challenge)
run_remote "cat > /etc/nginx/sites-available/digroup-temp << 'TEMP_EOF'
server {
    listen 80;
    server_name ${DOMAIN} grafana.${DOMAIN} prometheus.${DOMAIN};
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 200 'DNS настройка в процессе...';
        add_header Content-Type text/plain;
    }
}
TEMP_EOF
"

run_remote 'bash -s' << 'REMOTE_SCRIPT'
# Удаляем старые ссылки
rm -f /etc/nginx/sites-enabled/digroup
rm -f /etc/nginx/sites-enabled/default

# Активируем временную конфигурацию
ln -sf /etc/nginx/sites-available/digroup-temp /etc/nginx/sites-enabled/digroup-temp

# Проверяем и перезапускаем Nginx
nginx -t && systemctl restart nginx
REMOTE_SCRIPT

# Получаем SSL сертификаты
run_remote "bash -s" << REMOTE_SCRIPT
set -e

# Проверяем, есть ли уже сертификаты Let's Encrypt
if [ -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
    echo "✅ SSL сертификаты Let's Encrypt уже существуют"
else
    echo "Попытка получения SSL сертификата Let's Encrypt..."
    
    # Убеждаемся, что директория для webroot существует
    mkdir -p /var/www/certbot
    chown -R www-data:www-data /var/www/certbot
    
    # Пробуем получить сертификат через webroot
    certbot certonly --webroot \
        -w /var/www/certbot \
        -d ${DOMAIN} \
        --non-interactive \
        --agree-tos \
        --email ${EMAIL} \
        --preferred-challenges http 2>&1 || {
        
        echo "⚠️  Не удалось получить сертификат Let's Encrypt автоматически"
        echo "Создаем самоподписанный сертификат для тестирования..."
        
        # Создаем директорию для самоподписанного сертификата
        mkdir -p /etc/letsencrypt/live/${DOMAIN}
        
        # Генерируем самоподписанный сертификат
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/letsencrypt/live/${DOMAIN}/privkey.pem \
            -out /etc/letsencrypt/live/${DOMAIN}/fullchain.pem \
            -subj "/C=RU/ST=State/L=City/O=Organization/CN=${DOMAIN}" \
            -addext "subjectAltName=DNS:${DOMAIN},DNS:grafana.${DOMAIN},DNS:prometheus.${DOMAIN}" 2>/dev/null || {
            echo "❌ Не удалось создать самоподписанный сертификат"
            exit 1
        }
        
        echo "✅ Создан самоподписанный сертификат (для тестирования)"
        echo "⚠️  Браузеры будут показывать предупреждение о безопасности"
        echo "   Для получения настоящего сертификата используйте DNS-01 challenge:"
        echo "   certbot certonly --manual --preferred-challenges dns -d ${DOMAIN} -d grafana.${DOMAIN} -d prometheus.${DOMAIN}"
    }
    
    if [ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
        echo "✅ SSL сертификат готов для ${DOMAIN}"
    fi
fi
REMOTE_SCRIPT

echo -e "${GREEN}✅ SSL сертификаты получены${NC}"
echo ""

echo -e "${BLUE}📝 Установка полной конфигурации Nginx с SSL...${NC}"

# Теперь устанавливаем полную конфигурацию с SSL
run_remote "cat > /etc/nginx/sites-available/digroup << 'EOF'
${NGINX_CONFIG}
EOF"

run_remote 'bash -s' << 'REMOTE_SCRIPT'
# Удаляем временную конфигурацию
rm -f /etc/nginx/sites-enabled/digroup-temp

# Активируем полную конфигурацию
ln -sf /etc/nginx/sites-available/digroup /etc/nginx/sites-enabled/digroup

# Проверяем и перезагружаем Nginx
nginx -t && systemctl reload nginx
REMOTE_SCRIPT

echo -e "${GREEN}✅ Полная конфигурация Nginx установлена${NC}"
echo ""

echo -e "${GREEN}✅ SSL сертификаты установлены${NC}"
echo ""

echo -e "${BLUE}🔄 Настройка автообновления сертификатов...${NC}"
run_remote 'bash -s' << 'REMOTE_SCRIPT'
# Проверка наличия cron задачи для обновления
if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
    (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
    echo "✅ Автообновление сертификата настроено"
else
    echo "✅ Автообновление уже настроено"
fi
REMOTE_SCRIPT

echo ""
echo -e "${GREEN}✅ Настройка доменов завершена!${NC}"
echo ""
echo -e "${BLUE}🌐 Доступ к сервисам:${NC}"
echo -e "   - DIGroup: ${GREEN}https://${DOMAIN}${NC}"
echo -e "   - Grafana: ${GREEN}https://grafana.${DOMAIN}${NC}"
echo -e "   - Prometheus: ${GREEN}https://prometheus.${DOMAIN}${NC}"
echo ""
echo -e "${YELLOW}⚠️  Не забудьте настроить DNS записи в DuckDNS:${NC}"
echo -e "   - ${DOMAIN} → ${SERVER_IP}"
echo -e "   - grafana.${DOMAIN} → ${SERVER_IP}"
echo -e "   - prometheus.${DOMAIN} → ${SERVER_IP}"
echo ""
