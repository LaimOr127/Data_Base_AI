#!/bin/bash
# Автоматическая установка DIGroup на удаленный сервер
# Использование: ./deploy-to-server.sh

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Параметры сервера
SERVER_IP="85.198.99.150"
SERVER_USER="root"
SERVER_PASS="!K5kUHw6Hc0%"
SERVER_PATH="/opt/digroup"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🚀 АВТОМАТИЧЕСКАЯ УСТАНОВКА DIGROUP НА СЕРВЕР${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Сервер: ${SERVER_USER}@${SERVER_IP}"
echo "Путь установки: ${SERVER_PATH}"
echo ""

# Проверка наличия sshpass для автоматической авторизации
if ! command -v sshpass &> /dev/null; then
    echo -e "${YELLOW}Установка sshpass для автоматической авторизации...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install hudochenkov/sshpass/sshpass
        else
            echo -e "${RED}Ошибка: Установите sshpass вручную: brew install hudochenkov/sshpass/sshpass${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update && sudo apt-get install -y sshpass || sudo yum install -y sshpass
    fi
fi

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "${SERVER_PASS}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${SERVER_USER}@${SERVER_IP}" "$@"
}

# Функция для копирования файлов на сервер
scp_copy() {
    sshpass -p "${SERVER_PASS}" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r "$@"
}

echo -e "${YELLOW}📡 ШАГ 1: Подключение к серверу...${NC}"
if ! ssh_exec "echo 'Connection test'" &>/dev/null; then
    echo -e "${RED}Ошибка: Не удалось подключиться к серверу${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Подключение установлено${NC}"
echo ""

echo -e "${YELLOW}🧹 ШАГ 2: Очистка сервера...${NC}"
ssh_exec << 'ENDSSH'
    # Остановка и удаление старых контейнеров
    if command -v docker &> /dev/null; then
        echo "Остановка Docker контейнеров..."
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        
        # Удаление старых образов
        echo "Очистка Docker образов..."
        docker rmi $(docker images -q) 2>/dev/null || true
        docker system prune -af --volumes 2>/dev/null || true
    fi
    
    # Удаление старой директории проекта
    if [ -d "/opt/digroup" ]; then
        echo "Удаление старой директории проекта..."
        rm -rf /opt/digroup
    fi
    
    # Остановка старых systemd сервисов
    if systemctl list-units --type=service | grep -q digroup; then
        echo "Остановка старых сервисов..."
        systemctl stop digroup 2>/dev/null || true
        systemctl disable digroup 2>/dev/null || true
        rm -f /etc/systemd/system/digroup.service
        systemctl daemon-reload
    fi
    
    echo "✓ Сервер очищен"
ENDSSH
echo ""

echo -e "${YELLOW}📦 ШАГ 3: Установка Docker и зависимостей...${NC}"
ssh_exec << 'ENDSSH'
    # Обновление системы
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    
    # Установка необходимых пакетов
    apt-get install -y -qq curl wget git ca-certificates gnupg lsb-release
    
    # Установка Docker если не установлен
    if ! command -v docker &> /dev/null; then
        echo "Установка Docker..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sh /tmp/get-docker.sh
        rm /tmp/get-docker.sh
    else
        echo "Docker уже установлен"
    fi
    
    # Запуск Docker
    systemctl start docker
    systemctl enable docker
    
    # Добавление пользователя в группу docker (если не root)
    if [ "$USER" != "root" ]; then
        usermod -aG docker $USER 2>/dev/null || true
    fi
    
    # Установка Docker Compose если не установлен
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
        echo "Установка Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    else
        echo "Docker Compose уже установлен"
    fi
    
    # Настройка файрволла
    if command -v ufw &> /dev/null; then
        ufw allow 6806/tcp 2>/dev/null || true
        ufw allow 22/tcp 2>/dev/null || true
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=6806/tcp 2>/dev/null || true
        firewall-cmd --permanent --add-port=22/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
    fi
    
    echo "✓ Docker и зависимости установлены"
ENDSSH
echo ""

echo -e "${YELLOW}📁 ШАГ 4: Создание директорий на сервере...${NC}"
ssh_exec "mkdir -p ${SERVER_PATH}/workspace/conf ${SERVER_PATH}/workspace/data ${SERVER_PATH}/workspace/history ${SERVER_PATH}/workspace/temp ${SERVER_PATH}/data ${SERVER_PATH}/backups ${SERVER_PATH}/logs ${SERVER_PATH}/users_db"
echo -e "${GREEN}✓ Директории созданы${NC}"
echo ""

echo -e "${YELLOW}📤 ШАГ 5: Копирование проекта на сервер...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Создание временного файла со списком исключений для rsync
cat > /tmp/rsync-exclude.txt << 'EOF'
.git
.idea
.vscode
node_modules
__pycache__
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
*.log
logs/
backups/
*.tar.gz
*.zip
.DS_Store
.env
.env.local
workspace/data/
workspace/history/
workspace/temp/
workspace/conf/conf.json
digroup-test/
test/
*.tmp
*.temp
*.bak
*.backup
EOF

# Копирование файлов через rsync (если доступен) или scp
if command -v rsync &> /dev/null; then
    echo "Использование rsync для копирования..."
    sshpass -p "${SERVER_PASS}" rsync -avz --progress \
        --exclude-from=/tmp/rsync-exclude.txt \
        -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
        ./ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
else
    echo "Использование scp для копирования..."
    # Копируем основные файлы и директории
    scp_copy docker-compose.yml "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
    scp_copy .gitignore "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
    scp_copy README.md "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
    scp_copy install.sh "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
    scp_copy start.sh "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
    scp_copy bootstrap.sh "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
    scp_copy setup-users-from-csv.py "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
    
    # Копируем директории
    scp_copy siyuan/ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
    scp_copy deploy/ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
    scp_copy monitoring/ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
    scp_copy users_db/ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
fi

rm -f /tmp/rsync-exclude.txt
echo -e "${GREEN}✓ Проект скопирован${NC}"
echo ""

echo -e "${YELLOW}⚙️  ШАГ 6: Настройка проекта на сервере...${NC}"
ssh_exec << ENDSSH
    cd ${SERVER_PATH}
    
    # Установка прав на скрипты
    chmod +x *.sh
    
    # Создание .env файла если его нет
    if [ ! -f ".env" ]; then
        cat > .env << 'EOF'
ACCESS_AUTH_CODE=b226ba0f30a134fe9245792118bca202
TZ=Europe/Moscow
HOST_IP=0.0.0.0
PORT=6806
PUID=1000
PGID=1000
EOF
        echo "✓ .env файл создан"
    fi
    
    # Настройка пользователей из CSV если файл существует
    if [ -f "users_db/users.csv" ] && command -v python3 &> /dev/null; then
        echo "Настройка пользователей из CSV..."
        python3 setup-users-from-csv.py || echo "Предупреждение: Не удалось настроить пользователей"
    fi
    
    echo "✓ Проект настроен"
ENDSSH
echo ""

echo -e "${YELLOW}🐳 ШАГ 7: Сборка и запуск Docker контейнеров...${NC}"
ssh_exec << ENDSSH
    cd ${SERVER_PATH}
    
    # Загрузка переменных окружения
    set -a
    source .env 2>/dev/null || true
    set +a
    
    # Сборка образов
    echo "Сборка Docker образов (это может занять несколько минут)..."
    docker compose build --no-cache digroup
    
    # Запуск контейнеров
    echo "Запуск контейнеров..."
    docker compose up -d
    
    # Ожидание запуска
    sleep 10
    
    # Проверка статуса
    docker compose ps
    
    echo "✓ Контейнеры запущены"
ENDSSH
echo ""

echo -e "${YELLOW}🔍 ШАГ 8: Проверка работоспособности...${NC}"
sleep 5
if ssh_exec "curl -s http://localhost:6806/api/system/version" &>/dev/null; then
    echo -e "${GREEN}✓ Сервис работает корректно${NC}"
else
    echo -e "${YELLOW}⚠ Предупреждение: Сервис может еще запускаться${NC}"
fi
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ УСТАНОВКА ЗАВЕРШЕНА${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Сервис доступен по адресу:"
echo -e "  ${GREEN}http://${SERVER_IP}:6806${NC}"
echo ""
echo "Для управления сервисом на сервере:"
echo "  cd ${SERVER_PATH}"
echo "  docker compose logs -f    # Просмотр логов"
echo "  docker compose restart    # Перезапуск"
echo "  docker compose stop       # Остановка"
echo "  docker compose up -d      # Запуск"
echo ""
