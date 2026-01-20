#!/bin/bash
# Полностью автоматизированное развертывание DIGroup на сервер
# Использование: ./deploy-full-automated.sh

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Параметры сервера
SERVER_IP="85.198.99.150"
SERVER_USER="root"
SERVER_PASS="!K5kUHw6Hc0%"
SERVER_PATH="/opt/digroup"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🚀 ПОЛНОСТЬЮ АВТОМАТИЧЕСКОЕ РАЗВЕРТЫВАНИЕ DIGROUP${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Сервер: ${SERVER_USER}@${SERVER_IP}"
echo "Путь установки: ${SERVER_PATH}"
echo ""

# Проверка наличия sshpass
if ! command -v sshpass &> /dev/null; then
    echo -e "${YELLOW}Установка sshpass...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install hudochenkov/sshpass/sshpass || true
        else
            echo -e "${RED}Ошибка: Установите sshpass: brew install hudochenkov/sshpass/sshpass${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update && sudo apt-get install -y sshpass || sudo yum install -y sshpass || true
    fi
fi

# Функции для работы с сервером
ssh_exec() {
    sshpass -p "${SERVER_PASS}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 "${SERVER_USER}@${SERVER_IP}" "$@"
}

scp_copy() {
    sshpass -p "${SERVER_PASS}" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -r "$@"
}

# ШАГ 1: Подключение к серверу
echo -e "${BLUE}📡 ШАГ 1: Проверка подключения к серверу...${NC}"
if ! ssh_exec "echo 'Connection OK'" &>/dev/null; then
    echo -e "${RED}❌ Ошибка: Не удалось подключиться к серверу${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Подключение установлено${NC}"
echo ""

# ШАГ 2: Полная очистка сервера
echo -e "${BLUE}🧹 ШАГ 2: Полная очистка сервера...${NC}"
ssh_exec << 'ENDSSH'
    set -e
    echo "Остановка всех Docker контейнеров..."
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    echo "Очистка Docker образов и volumes..."
    docker rmi $(docker images -q) 2>/dev/null || true
    docker volume prune -af 2>/dev/null || true
    docker system prune -af 2>/dev/null || true
    
    echo "Удаление старой директории проекта..."
    rm -rf /opt/digroup 2>/dev/null || true
    
    echo "Остановка старых systemd сервисов..."
    systemctl stop digroup 2>/dev/null || true
    systemctl disable digroup 2>/dev/null || true
    rm -f /etc/systemd/system/digroup.service 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    
    echo "✓ Сервер очищен"
ENDSSH
echo ""

# ШАГ 3: Установка Docker и зависимостей
echo -e "${BLUE}📦 ШАГ 3: Установка Docker и зависимостей...${NC}"
ssh_exec << 'ENDSSH'
    set -e
    export DEBIAN_FRONTEND=noninteractive
    
    echo "Обновление системы..."
    apt-get update -qq
    
    echo "Установка базовых пакетов..."
    apt-get install -y -qq curl wget git ca-certificates gnupg lsb-release rsync
    
    echo "Установка Docker..."
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sh /tmp/get-docker.sh
        rm /tmp/get-docker.sh
    fi
    
    systemctl start docker
    systemctl enable docker
    
    echo "Установка Docker Compose..."
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    echo "Настройка файрволла..."
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

# ШАГ 4: Создание директорий на сервере
echo -e "${BLUE}📁 ШАГ 4: Создание директорий на сервере...${NC}"
ssh_exec "mkdir -p ${SERVER_PATH}/workspace/conf ${SERVER_PATH}/workspace/data ${SERVER_PATH}/workspace/history ${SERVER_PATH}/workspace/temp ${SERVER_PATH}/data ${SERVER_PATH}/backups ${SERVER_PATH}/logs ${SERVER_PATH}/users_db ${SERVER_PATH}/monitoring/grafana/provisioning ${SERVER_PATH}/monitoring/grafana/dashboards"
echo -e "${GREEN}✓ Директории созданы${NC}"
echo ""

# ШАГ 5: Копирование проекта на сервер
echo -e "${BLUE}📤 ШАГ 5: Копирование проекта на сервер...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Создание списка исключений для rsync
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
.DS_Store
.env.local
digroup-test/
test/
*.tmp
*.temp
*.bak
*.backup
EOF

# Копирование через rsync (если доступен) или scp
if command -v rsync &> /dev/null; then
    echo "Копирование файлов через rsync (это может занять несколько минут)..."
    sshpass -p "${SERVER_PASS}" rsync -avz --progress \
        --exclude-from=/tmp/rsync-exclude.txt \
        -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10" \
        ./ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/" || {
        echo -e "${YELLOW}Rsync не удался, используем scp...${NC}"
        # Fallback на scp
        scp_copy docker-compose.yml "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
        scp_copy siyuan/ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
        scp_copy deploy/ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
        scp_copy monitoring/ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
        scp_copy users_db/ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
        scp_copy workspace/ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
        scp_copy data/ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/" 2>/dev/null || true
    }
else
    echo "Копирование файлов через scp (это может занять несколько минут)..."
    scp_copy docker-compose.yml "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
    scp_copy siyuan/ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
    scp_copy deploy/ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
    scp_copy monitoring/ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
    scp_copy users_db/ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
    scp_copy workspace/ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
    scp_copy data/ "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/" 2>/dev/null || true
    scp_copy *.sh "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/" 2>/dev/null || true
    scp_copy *.py "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/" 2>/dev/null || true
    scp_copy *.md "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/" 2>/dev/null || true
fi

rm -f /tmp/rsync-exclude.txt
echo -e "${GREEN}✓ Проект скопирован${NC}"
echo ""

# ШАГ 6: Настройка проекта на сервере
echo -e "${BLUE}⚙️  ШАГ 6: Настройка проекта на сервере...${NC}"
ssh_exec << ENDSSH
    set -e
    cd ${SERVER_PATH}
    
    echo "Установка прав на скрипты..."
    chmod +x *.sh 2>/dev/null || true
    
    echo "Создание .env файла..."
    cat > .env << 'EOF'
ACCESS_AUTH_CODE=b226ba0f30a134fe9245792118bca202
TZ=Europe/Moscow
HOST_IP=0.0.0.0
PORT=6806
PUID=1000
PGID=1000
GRAFANA_USER=admin
GRAFANA_PASSWORD=digroup2026
EOF
    
    echo "Настройка прав доступа..."
    chown -R root:root ${SERVER_PATH} 2>/dev/null || true
    chmod -R 755 ${SERVER_PATH} 2>/dev/null || true
    
    echo "✓ Проект настроен"
ENDSSH
echo ""

# ШАГ 7: Сборка и запуск Docker контейнеров
echo -e "${BLUE}🐳 ШАГ 7: Сборка и запуск Docker контейнеров...${NC}"
ssh_exec << ENDSSH
    set -e
    cd ${SERVER_PATH}
    
    echo "Загрузка переменных окружения..."
    set -a
    source .env 2>/dev/null || true
    set +a
    
    echo "Сборка Docker образа digroup (это может занять 5-10 минут)..."
    docker compose build --no-cache digroup || docker-compose build --no-cache digroup
    
    echo "Запуск всех контейнеров..."
    docker compose up -d || docker-compose up -d
    
    echo "Ожидание запуска контейнеров..."
    sleep 15
    
    echo "Проверка статуса контейнеров..."
    docker compose ps || docker-compose ps
    
    echo "✓ Контейнеры запущены"
ENDSSH
echo ""

# ШАГ 8: Проверка работоспособности
echo -e "${BLUE}🔍 ШАГ 8: Проверка работоспособности...${NC}"
echo "Ожидание запуска сервиса (до 2 минут)..."
MAX_ATTEMPTS=40
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if ssh_exec "curl -s http://localhost:6806/api/system/version" &>/dev/null; then
        echo ""
        echo -e "${GREEN}✓ Сервис работает корректно!${NC}"
        break
    fi
    echo -n "."
    sleep 3
    ATTEMPT=$((ATTEMPT + 1))
done

if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo ""
    echo -e "${YELLOW}⚠ Предупреждение: Сервис может еще запускаться${NC}"
    echo "Проверьте логи на сервере: docker compose logs -f"
fi
echo ""

# Финальный отчет
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ РАЗВЕРТЫВАНИЕ ЗАВЕРШЕНО!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}🌐 Сервисы доступны по адресам:${NC}"
echo "   • DIGroup:    http://${SERVER_IP}:6806"
echo "   • Grafana:    http://${SERVER_IP}:3000"
echo "   • Prometheus: http://${SERVER_IP}:9090"
echo ""
echo -e "${BLUE}🔑 Код доступа:${NC} b226ba0f30a134fe9245792118bca202"
echo ""
echo -e "${BLUE}📝 Управление на сервере:${NC}"
echo "   ssh ${SERVER_USER}@${SERVER_IP}"
echo "   cd ${SERVER_PATH}"
echo "   docker compose logs -f    # Просмотр логов"
echo "   docker compose restart    # Перезапуск"
echo "   docker compose stop       # Остановка"
echo "   docker compose ps         # Статус"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
