#!/bin/bash
# Скрипт установки DIGroup
# Поддерживает: Linux, macOS
# Использование: ./install.sh

set -e

echo "=========================================="
echo " Установка DIGroup"
echo "=========================================="
echo ""

# Определение ОС
OS_TYPE="unknown"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
fi

echo "Обнаружена ОС: $OS_TYPE"
echo ""

# Проверка Docker
echo "Проверка Docker..."
if command -v docker &> /dev/null; then
    echo "[OK] Docker уже установлен"
else
    echo "Docker не найден. Устанавливаю..."
    
    if [ "$OS_TYPE" == "linux" ]; then
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh
        sudo usermod -aG docker $USER
        echo "[OK] Docker установлен"
        echo "Примечание: Перезайдите в систему или выполните: newgrp docker"
    elif [ "$OS_TYPE" == "macos" ]; then
        echo "Установите Docker Desktop с https://www.docker.com/products/docker-desktop"
        exit 1
    fi
fi

# Запуск Docker (только для Linux)
if [ "$OS_TYPE" == "linux" ]; then
    if ! sudo systemctl is-active --quiet docker 2>/dev/null; then
        echo "Запуск Docker..."
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
fi

echo ""

# Проверка Docker Compose
echo "Проверка Docker Compose..."
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null 2>&1; then
    echo "[OK] Docker Compose доступен"
else
    if [ "$OS_TYPE" == "linux" ]; then
        echo "Установка Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        echo "[OK] Docker Compose установлен"
    fi
fi

echo ""

# Подготовка директорий
echo "Подготовка директорий..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p workspace data backups logs
echo "[OK] Директории созданы"

echo ""

# Создание .env
if [ ! -f ".env" ]; then
    echo "Создание .env файла..."
    ACCESS_CODE=$(openssl rand -hex 16 2>/dev/null || echo "b226ba0f30a134fe9245792118bca202")
    
    cat > .env << EOF
ACCESS_AUTH_CODE=$ACCESS_CODE
TZ=Europe/Moscow
HOST_IP=0.0.0.0
PORT=6806
PUID=1000
PGID=1000
EOF
    echo "[OK] .env файл создан"
    echo ""
    echo "Код доступа: $ACCESS_CODE"
    echo "Сохраните его!"
    echo ""
else
    echo "[OK] .env файл существует"
fi

echo ""

# Настройка файрволла (Linux)
if [ "$OS_TYPE" == "linux" ]; then
    echo "Проверка файрволла..."
    if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
        sudo ufw allow 6806/tcp 2>/dev/null || true
        echo "[OK] Порт 6806 открыт (UFW)"
    elif command -v firewall-cmd &> /dev/null && sudo firewall-cmd --state 2>/dev/null | grep -q "running"; then
        sudo firewall-cmd --permanent --add-port=6806/tcp 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
        echo "[OK] Порт 6806 открыт (firewalld)"
    fi
fi

echo ""
echo "=========================================="
echo " Установка завершена"
echo "=========================================="
echo ""
echo "Следующие шаги:"
echo "  1. Запустите: ./start.sh"
echo "  2. Откройте: http://localhost:6806"
echo ""
if [ "$OS_TYPE" == "linux" ]; then
    echo "Для автозапуска: sudo ./setup-systemd.sh"
    echo ""
fi
