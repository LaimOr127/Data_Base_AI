#!/bin/bash
# Автоматическая установка DIGroup на удаленный сервер
# Использование: ./deploy-server.sh

set -e

# Параметры сервера
SERVER_IP="85.198.99.150"
SERVER_USER="root"
SERVER_PASSWORD="!K5kUHw6Hc0%"
GIT_REPO="git@github.com:LaimOr127/Data_Base_AI.git"
INSTALL_DIR="/opt/digroup"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 АВТОМАТИЧЕСКАЯ УСТАНОВКА DIGROUP НА СЕРВЕР"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Сервер: $SERVER_USER@$SERVER_IP"
echo "Директория установки: $INSTALL_DIR"
echo ""

# Проверка SSH ключа или установка sshpass
if ! command -v sshpass &> /dev/null; then
    echo "⚠️  sshpass не установлен. Устанавливаю..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install hudochenkov/sshpass/sshpass
        else
            echo "❌ Установите sshpass: brew install hudochenkov/sshpass/sshpass"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update && sudo apt-get install -y sshpass
    fi
fi

# Функция для выполнения команд на сервере
run_remote() {
    sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$SERVER_USER@$SERVER_IP" "$@"
}

# Функция для копирования файлов на сервер
copy_to_server() {
    sshpass -p "$SERVER_PASSWORD" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -r "$1" "$SERVER_USER@$SERVER_IP:$2"
}

echo "📡 Подключение к серверу..."
if ! run_remote "echo 'Connection test'" &>/dev/null; then
    echo "❌ Не удалось подключиться к серверу"
    exit 1
fi
echo "✅ Подключение установлено"
echo ""

# Шаг 1: Очистка сервера
echo "🧹 ШАГ 1: Очистка сервера..."
run_remote << 'CLEANUP'
    echo "Остановка контейнеров..."
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    echo "Удаление старых образов..."
    docker rmi $(docker images -q) 2>/dev/null || true
    
    echo "Очистка Docker системы..."
    docker system prune -af --volumes 2>/dev/null || true
    
    echo "Удаление старой директории проекта..."
    rm -rf /opt/digroup 2>/dev/null || true
    
    echo "Очистка временных файлов..."
    rm -rf /tmp/digroup* 2>/dev/null || true
    
    echo "✅ Очистка завершена"
CLEANUP
echo ""

# Шаг 2: Установка Docker и зависимостей
echo "📦 ШАГ 2: Установка Docker и зависимостей..."
run_remote << 'INSTALL_DOCKER'
    set -e
    
    echo "Обновление системы..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get upgrade -y -qq
    
    echo "Установка необходимых пакетов..."
    apt-get install -y -qq \
        curl \
        wget \
        git \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        apt-transport-https
    
    echo "Проверка Docker..."
    if ! command -v docker &> /dev/null; then
        echo "Установка Docker..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sh /tmp/get-docker.sh
        rm /tmp/get-docker.sh
    else
        echo "Docker уже установлен"
    fi
    
    echo "Проверка Docker Compose..."
    if ! docker compose version &> /dev/null; then
        echo "Docker Compose уже доступен через 'docker compose'"
    else
        echo "Docker Compose доступен"
    fi
    
    echo "Запуск Docker..."
    systemctl start docker 2>/dev/null || true
    systemctl enable docker 2>/dev/null || true
    
    echo "Настройка прав..."
    usermod -aG docker root 2>/dev/null || true
    
    echo "✅ Docker установлен и запущен"
INSTALL_DOCKER
echo ""

# Шаг 3: Клонирование проекта
echo "📥 ШАГ 3: Клонирование проекта с GitHub..."
run_remote << CLONE_REPO
    set -e
    
    echo "Создание директории..."
    mkdir -p $INSTALL_DIR
    cd $INSTALL_DIR
    
    echo "Клонирование репозитория..."
    # Если есть SSH ключ на сервере, используем его, иначе HTTPS
    if ssh -o StrictHostKeyChecking=no -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        git clone $GIT_REPO . || git clone https://github.com/LaimOr127/Data_Base_AI.git .
    else
        echo "Используем HTTPS для клонирования..."
        git clone https://github.com/LaimOr127/Data_Base_AI.git .
    fi
    
    echo "✅ Проект склонирован"
CLONE_REPO
echo ""

# Шаг 4: Настройка проекта
echo "⚙️  ШАГ 4: Настройка проекта..."
run_remote << 'SETUP_PROJECT'
    set -e
    cd $INSTALL_DIR
    
    echo "Создание необходимых директорий..."
    mkdir -p workspace/conf workspace/data workspace/history workspace/temp
    mkdir -p data backups logs users_db
    
    echo "Установка прав на скрипты..."
    chmod +x *.sh 2>/dev/null || true
    chmod +x deploy/scripts/*.sh 2>/dev/null || true
    find . -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true
    
    echo "Создание .env файла..."
    if [ ! -f ".env" ]; then
        ACCESS_CODE=\$(openssl rand -hex 16 2>/dev/null || echo "b226ba0f30a134fe9245792118bca202")
        cat > .env << EOF
ACCESS_AUTH_CODE=\$ACCESS_CODE
TZ=Europe/Moscow
HOST_IP=0.0.0.0
PORT=6806
PUID=1000
PGID=1000
EOF
        echo "✅ .env файл создан"
        echo "Код доступа: \$ACCESS_CODE"
    else
        echo "✅ .env файл уже существует"
    fi
    
    echo "Настройка пользователей из CSV..."
    if [ -f "users_db/users.csv" ] && [ -f "setup-users-from-csv.py" ]; then
        python3 setup-users-from-csv.py || echo "⚠️  Не удалось настроить пользователей"
    fi
    
    echo "✅ Проект настроен"
SETUP_PROJECT
echo ""

# Шаг 5: Сборка и запуск
echo "🐳 ШАГ 5: Сборка и запуск Docker контейнеров..."
run_remote << 'BUILD_AND_START'
    set -e
    cd $INSTALL_DIR
    
    echo "Загрузка переменных окружения..."
    set -a
    source .env 2>/dev/null || true
    set +a
    
    echo "Сборка образов..."
    docker compose build --no-cache digroup
    
    echo "Запуск контейнеров..."
    docker compose up -d
    
    echo "Ожидание запуска сервисов..."
    sleep 10
    
    echo "Проверка статуса контейнеров..."
    docker compose ps
    
    echo "✅ Сервисы запущены"
BUILD_AND_START
echo ""

# Шаг 6: Настройка файрволла
echo "🔥 ШАГ 6: Настройка файрволла..."
run_remote << 'SETUP_FIREWALL'
    set -e
    
    echo "Проверка UFW..."
    if command -v ufw &> /dev/null; then
        ufw allow 6806/tcp 2>/dev/null || true
        ufw allow 6808/tcp 2>/dev/null || true
        echo "✅ UFW настроен"
    fi
    
    echo "Проверка firewalld..."
    if command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --permanent --add-port=6806/tcp 2>/dev/null || true
        firewall-cmd --permanent --add-port=6808/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        echo "✅ Firewalld настроен"
    fi
SETUP_FIREWALL
echo ""

# Шаг 7: Проверка работоспособности
echo "✅ ШАГ 7: Проверка работоспособности..."
run_remote << 'CHECK_STATUS'
    set -e
    cd $INSTALL_DIR
    
    echo "Проверка контейнеров..."
    docker compose ps
    
    echo ""
    echo "Проверка доступности сервиса..."
    sleep 5
    if curl -f http://localhost:6806/api/system/version &>/dev/null; then
        echo "✅ Сервис доступен на порту 6806"
    else
        echo "⚠️  Сервис еще не отвечает, подождите немного..."
    fi
    
    echo ""
    echo "Логи последних 20 строк:"
    docker compose logs --tail=20 digroup
CHECK_STATUS
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ УСТАНОВКА ЗАВЕРШЕНА"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Доступ к сервису:"
echo "   http://$SERVER_IP:6806"
echo ""
echo "📋 Полезные команды:"
echo "   Просмотр логов: ssh $SERVER_USER@$SERVER_IP 'cd $INSTALL_DIR && docker compose logs -f'"
echo "   Перезапуск: ssh $SERVER_USER@$SERVER_IP 'cd $INSTALL_DIR && docker compose restart'"
echo "   Остановка: ssh $SERVER_USER@$SERVER_IP 'cd $INSTALL_DIR && docker compose down'"
echo ""
