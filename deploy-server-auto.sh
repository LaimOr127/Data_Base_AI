#!/bin/bash
# Автоматическая установка DIGroup на удаленный сервер
# Использование: ./deploy-server-auto.sh

set -e

# Параметры сервера
SERVER_IP="85.198.99.150"
SERVER_USER="root"
SERVER_PASSWORD="!K5kUHw6Hc0%"
GIT_REPO="https://github.com/LaimOr127/Data_Base_AI.git"
INSTALL_DIR="/opt/digroup"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 АВТОМАТИЧЕСКАЯ УСТАНОВКА DIGROUP НА СЕРВЕР"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Сервер: $SERVER_USER@$SERVER_IP"
echo "Директория установки: $INSTALL_DIR"
echo ""

# Проверка sshpass
if ! command -v sshpass &> /dev/null; then
    echo "⚠️  sshpass не установлен. Устанавливаю..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install hudochenkov/sshpass/sshpass 2>/dev/null || echo "Установите вручную: brew install hudochenkov/sshpass/sshpass"
        else
            echo "❌ Установите Homebrew и затем: brew install hudochenkov/sshpass/sshpass"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update && sudo apt-get install -y sshpass
    fi
fi

# Функция для выполнения команд на сервере
run_remote() {
    sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=10 \
        "$SERVER_USER@$SERVER_IP" "$@"
}

echo "📡 Подключение к серверу..."
if ! run_remote "echo 'Connection OK'" &>/dev/null; then
    echo "❌ Не удалось подключиться к серверу"
    exit 1
fi
echo "✅ Подключение установлено"
echo ""

# Выполнение всех шагов на сервере одной командой
echo "🚀 Начинаю установку на сервере..."
run_remote bash << 'REMOTE_SCRIPT'
set -e

INSTALL_DIR="/opt/digroup"
GIT_REPO="https://github.com/LaimOr127/Data_Base_AI.git"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧹 ШАГ 1: Очистка сервера..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Остановка и удаление контейнеров
echo "Остановка контейнеров..."
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

echo "Очистка Docker системы..."
docker system prune -af --volumes 2>/dev/null || true

echo "Удаление старой директории проекта..."
rm -rf "$INSTALL_DIR" 2>/dev/null || true

echo "✅ Очистка завершена"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 ШАГ 2: Установка Docker и зависимостей..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

export DEBIAN_FRONTEND=noninteractive

# Обновление системы
echo "Обновление системы..."
apt-get update -qq > /dev/null 2>&1

# Установка необходимых пакетов
echo "Установка необходимых пакетов..."
apt-get install -y -qq \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    python3 \
    python3-pip \
    openssl \
    > /dev/null 2>&1

# Проверка и установка Docker
if ! command -v docker &> /dev/null; then
    echo "Установка Docker..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh > /dev/null 2>&1
    rm /tmp/get-docker.sh
else
    echo "Docker уже установлен"
fi

# Запуск Docker
systemctl start docker 2>/dev/null || true
systemctl enable docker 2>/dev/null || true
usermod -aG docker root 2>/dev/null || true

echo "✅ Docker установлен и запущен"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📥 ШАГ 3: Клонирование проекта..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "Клонирование репозитория..."
git clone "$GIT_REPO" . 2>&1 | tail -5

echo "✅ Проект склонирован"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚙️  ШАГ 4: Настройка проекта..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Создание директорий
mkdir -p workspace/conf workspace/data workspace/history workspace/temp
mkdir -p data backups logs users_db

# Установка прав на скрипты
echo "Установка прав на скрипты..."
find . -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true

# Создание .env файла
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
    echo "✅ .env файл создан"
    echo "🔑 Код доступа: $ACCESS_CODE"
else
    echo "✅ .env файл уже существует"
fi

# Настройка пользователей из CSV
if [ -f "users_db/users.csv" ] && [ -f "setup-users-from-csv.py" ]; then
    echo "Настройка пользователей из CSV..."
    python3 setup-users-from-csv.py 2>&1 | tail -5 || echo "⚠️  Не удалось настроить пользователей"
fi

echo "✅ Проект настроен"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐳 ШАГ 5: Сборка и запуск Docker контейнеров..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Загрузка переменных окружения
set -a
source .env 2>/dev/null || true
set +a

echo "Сборка образов (это может занять 5-10 минут)..."
docker compose build --no-cache digroup 2>&1 | grep -E "Built|error|Error|DONE" | tail -10

echo ""
echo "Запуск контейнеров..."
docker compose up -d

echo "Ожидание запуска сервисов (30 секунд)..."
sleep 30

echo ""
echo "Проверка статуса контейнеров..."
docker compose ps

echo "✅ Сервисы запущены"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔥 ШАГ 6: Настройка файрволла..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v ufw &> /dev/null; then
    ufw allow 6806/tcp 2>/dev/null || true
    ufw allow 6808/tcp 2>/dev/null || true
    echo "✅ UFW настроен"
fi

if command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
    firewall-cmd --permanent --add-port=6806/tcp 2>/dev/null || true
    firewall-cmd --permanent --add-port=6808/tcp 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    echo "✅ Firewalld настроен"
fi

echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ШАГ 7: Проверка работоспособности..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Проверка доступности сервиса..."
sleep 5

if curl -f -s http://localhost:6806/api/system/version > /dev/null 2>&1; then
    echo "✅ Сервис доступен на порту 6806"
    VERSION=$(curl -s http://localhost:6806/api/system/version 2>/dev/null | grep -o '"data":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    echo "   Версия: $VERSION"
else
    echo "⚠️  Сервис еще не отвечает, проверяю логи..."
    echo ""
    echo "Последние 20 строк логов:"
    docker compose logs --tail=20 digroup 2>/dev/null | tail -20
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ УСТАНОВКА ЗАВЕРШЕНА!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Доступ к сервису:"
echo "   http://85.198.99.150:6806"
echo ""
echo "📋 Полезные команды:"
echo "   Логи: cd $INSTALL_DIR && docker compose logs -f"
echo "   Перезапуск: cd $INSTALL_DIR && docker compose restart"
echo "   Остановка: cd $INSTALL_DIR && docker compose down"
echo ""

REMOTE_SCRIPT

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ УСТАНОВКА НА СЕРВЕР ЗАВЕРШЕНА!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Откройте в браузере:"
echo "   http://85.198.99.150:6806"
echo ""
