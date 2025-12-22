#!/bin/bash
# Настройка DIGroup на macOS
# Использование: ./setup-macos.sh

set -e

echo "🍎 Настройка DIGroup на macOS"
echo "=============================="
echo ""

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Пути
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="$SCRIPT_DIR/../app/kernel"
KERNEL_PATH="$KERNEL_DIR/SiYuan-Kernel"

# Определение пути к Nginx (Homebrew)
if [ -d "/opt/homebrew/etc/nginx" ]; then
    NGINX_CONF_DIR="/opt/homebrew/etc/nginx"  # Apple Silicon
    NGINX_LOG_DIR="/opt/homebrew/var/log/nginx"
elif [ -d "/usr/local/etc/nginx" ]; then
    NGINX_CONF_DIR="/usr/local/etc/nginx"  # Intel
    NGINX_LOG_DIR="/usr/local/var/log/nginx"
else
    # Пытаемся найти через brew
    NGINX_CONF_DIR="$(brew --prefix)/etc/nginx"
    NGINX_LOG_DIR="$(brew --prefix)/var/log/nginx"
fi

# Шаг 1: Проверка Homebrew
echo "1️⃣  Проверка Homebrew..."
if ! command -v brew &> /dev/null; then
    echo -e "${RED}❌ Homebrew не установлен${NC}"
    echo ""
    echo "Установите Homebrew:"
    echo "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
else
    echo -e "${GREEN}✅ Homebrew установлен${NC}"
fi

# Шаг 2: Установка Nginx
echo ""
echo "2️⃣  Установка Nginx..."
if ! command -v nginx &> /dev/null; then
    echo "Устанавливаю Nginx..."
    brew install nginx
    echo -e "${GREEN}✅ Nginx установлен${NC}"
else
    echo -e "${GREEN}✅ Nginx уже установлен${NC}"
fi

# Шаг 3: Создание workspace (если нужно)
echo ""
echo "3️⃣  Настройка workspace..."
WORKSPACE_DIR="$HOME/DIGroup-workspace"
if [ ! -d "$WORKSPACE_DIR" ]; then
    mkdir -p "$WORKSPACE_DIR"
    echo -e "${GREEN}✅ Workspace создан: $WORKSPACE_DIR${NC}"
else
    echo -e "${GREEN}✅ Workspace существует: $WORKSPACE_DIR${NC}"
fi

# Шаг 4: Генерация accessAuthCode
echo ""
echo "4️⃣  Генерация accessAuthCode..."
ACCESS_CODE=$(openssl rand -hex 16)
echo -e "${GREEN}✅ AccessAuthCode: $ACCESS_CODE${NC}"
echo "   Сохраните этот код! Он нужен для доступа к DIGroup"

# Шаг 5: Создание конфигурации Nginx
echo ""
echo "5️⃣  Создание конфигурации Nginx..."

# Создаем директорию для конфигураций (если не существует)
if [ ! -d "$NGINX_CONF_DIR/servers" ]; then
    mkdir -p "$NGINX_CONF_DIR/servers"
fi

# Создаем конфигурацию
cat > "$NGINX_CONF_DIR/servers/digroup.conf" <<EOF
# Конфигурация Nginx для DIGroup на macOS

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 8081;
    server_name localhost;
    
    access_log $NGINX_LOG_DIR/digroup-access.log;
    error_log $NGINX_LOG_DIR/digroup-error.log;
    
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://127.0.0.1:6806;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 300;
        proxy_send_timeout 300;
        proxy_buffering off;
    }
}
EOF

echo -e "${GREEN}✅ Конфигурация создана${NC}"

# Шаг 6: Проверка конфигурации
echo ""
echo "6️⃣  Проверка конфигурации Nginx..."
if nginx -t 2>&1 | grep -q "successful"; then
    echo -e "${GREEN}✅ Конфигурация корректна${NC}"
else
    echo -e "${RED}❌ Ошибки в конфигурации:${NC}"
    nginx -t
    exit 1
fi

# Шаг 7: Запуск Nginx
echo ""
echo "7️⃣  Запуск Nginx..."
if brew services list | grep -q "nginx.*started"; then
    echo "Перезагружаю Nginx..."
    brew services restart nginx
else
    echo "Запускаю Nginx..."
    brew services start nginx
fi
echo -e "${GREEN}✅ Nginx запущен${NC}"

# Шаг 8: Запуск kernel
echo ""
echo "8️⃣  Запуск kernel..."
if pgrep -f "SiYuan-Kernel" > /dev/null; then
    echo -e "${YELLOW}⚠️  Kernel уже запущен${NC}"
    read -p "Остановить и перезапустить? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pkill -f "SiYuan-Kernel" || true
        sleep 2
    else
        echo "Пропускаю запуск kernel"
        KERNEL_RUNNING=true
    fi
fi

if [ -z "$KERNEL_RUNNING" ]; then
    echo "Запускаю kernel в фоне..."
    cd "$KERNEL_DIR"
    nohup ./SiYuan-Kernel \
        --wd="$SCRIPT_DIR/../app" \
        --workspace="$WORKSPACE_DIR" \
        --accessAuthCode="$ACCESS_CODE" \
        --port=6806 \
        --mode=dev \
        > /tmp/digroup-kernel.log 2>&1 &
    
    sleep 3
    
    # Проверка запуска
    if pgrep -f "SiYuan-Kernel" > /dev/null; then
        echo -e "${GREEN}✅ Kernel запущен${NC}"
    else
        echo -e "${RED}❌ Ошибка запуска kernel${NC}"
        echo "Проверьте логи: cat /tmp/digroup-kernel.log"
        exit 1
    fi
fi

# Шаг 9: Проверка работы
echo ""
echo "9️⃣  Проверка работы..."
sleep 2

# Проверка kernel
if curl -s -m 3 http://127.0.0.1:6806/api/system/version > /dev/null; then
    echo -e "${GREEN}✅ Kernel отвечает${NC}"
else
    echo -e "${RED}❌ Kernel не отвечает${NC}"
    echo "Проверьте логи: cat /tmp/digroup-kernel.log"
fi

# Проверка Nginx
if curl -s -m 3 http://localhost:8080/api/system/version > /dev/null; then
    echo -e "${GREEN}✅ Nginx проксирует запросы${NC}"
else
    echo -e "${YELLOW}⚠️  Nginx не отвечает (возможно, нужно подождать)${NC}"
fi

# Получение IP
echo ""
echo "🔟 IP адрес:"
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "не определен")
echo "   Локальный IP: $LOCAL_IP"

echo ""
echo "✅ Настройка завершена!"
echo ""
echo "📋 Информация для доступа:"
echo "   AccessAuthCode: $ACCESS_CODE"
echo "   Локальный доступ: http://localhost:8080"
if [ "$LOCAL_IP" != "не определен" ]; then
    echo "   Доступ по сети: http://$LOCAL_IP:8080"
fi
echo ""
echo "📝 Полезные команды:"
echo "   # Остановить kernel"
echo "   pkill -f SiYuan-Kernel"
echo ""
echo "   # Запустить kernel вручную"
echo "   cd $KERNEL_DIR"
echo "   ./SiYuan-Kernel --wd=$SCRIPT_DIR/../app --workspace=$WORKSPACE_DIR --accessAuthCode=$ACCESS_CODE --port=6806 --mode=dev &"
echo ""
echo "   # Логи kernel"
echo "   tail -f /tmp/digroup-kernel.log"
echo ""
echo "   # Логи Nginx"
echo "   tail -f $NGINX_LOG_DIR/digroup-error.log"
echo ""
echo "   # Перезапустить Nginx"
echo "   brew services restart nginx"
echo ""

