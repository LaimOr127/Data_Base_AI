#!/bin/bash
# Автоматическая установка DIGroup для Ubuntu 24.04 LTS
# Использование: sudo bash install-ubuntu.sh
# Требуется: Ubuntu 24.04 LTS и права root

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

function print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

function print_error() {
    echo -e "${RED}❌ $1${NC}"
}

function print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

function print_log() {
    echo -e "${CYAN}[$(date +%H:%M:%S)] $1${NC}"
}

# Генерация паролей
function generate_password() {
    openssl rand -base64 25 | tr -d '+/=' | head -c 25
}

function generate_auth_code() {
    openssl rand -hex 16
}

clear
echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║     🚀 Автоматическая установка DIGroup для Ubuntu         ║
║     Включая: DIGroup, Мониторинг, Ollama                  ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   print_error "Скрипт должен быть запущен с правами root (sudo)"
   exit 1
fi

# Проверка версии Ubuntu
print_log "Проверка версии Ubuntu..."
if ! grep -q "Ubuntu 24.04" /etc/os-release 2>/dev/null && ! grep -q "Ubuntu 22.04" /etc/os-release 2>/dev/null; then
    print_warning "Рекомендуется Ubuntu 24.04 LTS, но установка продолжится"
fi
print_success "Проверка ОС пройдена"
echo ""

# Обновление системы
print_log "Обновление списка пакетов..."
apt-get update -qq
print_success "Список пакетов обновлен"
echo ""

# Установка зависимостей
print_log "Установка необходимых пакетов..."
apt-get install -y -qq curl wget git ca-certificates gnupg lsb-release openssl > /dev/null 2>&1
print_success "Пакеты установлены"
echo ""

# Проверка и установка Docker
print_log "Проверка Docker..."
if ! command -v docker &> /dev/null; then
    print_log "Docker не найден. Установка Docker..."
    
    # Удаление старых версий
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Добавление официального GPG ключа Docker
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    
    # Добавление репозитория Docker
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Установка Docker
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Запуск Docker
    systemctl start docker
    systemctl enable docker
    
    print_success "Docker установлен и запущен"
else
    print_success "Docker уже установлен"
    systemctl start docker 2>/dev/null || true
fi
echo ""

# Проверка Docker Compose
print_log "Проверка Docker Compose..."
if ! docker compose version &> /dev/null; then
    print_error "Docker Compose не найден"
    exit 1
fi
print_success "Docker Compose доступен"
echo ""

# Определение директорий
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/digroup"

print_log "Директория установки: $INSTALL_DIR"
echo ""

# Создание директорий
print_log "Создание директорий..."
mkdir -p "$INSTALL_DIR"/{workspace,data,backups,logs,monitoring/{prometheus,grafana}}
print_success "Директории созданы"
echo ""

# Копирование файлов проекта
print_log "Копирование проекта..."
cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/" 2>/dev/null || true
cd "$INSTALL_DIR"
print_success "Проект скопирован"
echo ""

# Генерация паролей
print_log "Генерация паролей..."
ACCESS_AUTH_CODE=$(generate_auth_code)
GRAFANA_PASSWORD=$(generate_password)
print_success "Пароли сгенерированы"
echo ""

# Создание .env файла
print_log "Создание .env файла..."
cat > "$INSTALL_DIR/.env" << EOF
# DIGroup Configuration
ACCESS_AUTH_CODE=$ACCESS_AUTH_CODE
GRAFANA_PASSWORD=$GRAFANA_PASSWORD
TZ=Europe/Moscow
HOST_IP=0.0.0.0
PORT=6806

# Ollama
OLLAMA_URL=http://ollama:11434
OLLAMA_MODEL=llama3.2:1b
EOF
print_success ".env создан"
echo ""

# Проверка наличия docker-compose.yml
if [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
    print_error "Файл docker-compose.yml не найден в $INSTALL_DIR"
    exit 1
fi

# Остановка существующих контейнеров
print_log "Остановка существующих контейнеров (если есть)..."
docker compose down 2>/dev/null || true
print_success "Старые контейнеры остановлены"
echo ""

# Запуск сервисов
print_log "Запуск сервисов..."
docker compose up -d --build

# Проверка статуса
sleep 5
if docker compose ps | grep -q "Up"; then
    print_success "Сервисы запущены"
else
    print_warning "Некоторые сервисы могут еще запускаться"
fi
echo ""

# Загрузка модели Ollama
print_log "Ожидание запуска Ollama..."
sleep 10

print_log "Загрузка модели llama3.2:1b в Ollama..."
docker exec ollama ollama pull llama3.2:1b &
OLLAMA_PID=$!

# Настройка конфигурации DIGroup
print_log "Настройка конфигурации DIGroup..."
sleep 15

# Проверка и обновление конфигурации
CONF_FILE="$INSTALL_DIR/workspace/conf/conf.json"
if [ -f "$CONF_FILE" ]; then
    print_log "Обновление конфигурации Ollama..."
    # Создание резервной копии
    cp "$CONF_FILE" "$CONF_FILE.backup"
    
    # Обновление конфигурации с помощью sed
    sed -i 's|"apiBaseURL": "http://localhost:11434"|"apiBaseURL": "http://ollama:11434"|g' "$CONF_FILE"
    sed -i 's|"apiTimeout": 30|"apiTimeout": 120|g' "$CONF_FILE"
    sed -i 's|"apiModel": "nemotron-3-nano:30b-cloud"|"apiModel": "llama3.2:1b"|g' "$CONF_FILE"
    
    print_success "Конфигурация обновлена"
    
    # Перезапуск digroup
    print_log "Перезапуск DIGroup для применения настроек..."
    docker compose restart digroup
fi
echo ""

# Ожидание загрузки модели Ollama
print_log "Ожидание завершения загрузки модели Ollama..."
wait $OLLAMA_PID 2>/dev/null || true
print_success "Модель Ollama загружена"
echo ""

# Получение IP-адреса сервера
SERVER_IP=$(hostname -I | awk '{print $1}')

# Итоговая информация
clear
echo -e "${GREEN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                    ✅ УСТАНОВКА ЗАВЕРШЕНА!                               ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}🔐 ДАННЫЕ ДЛЯ ДОСТУПА${NC}"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo "AccessAuthCode: $ACCESS_AUTH_CODE"
echo "Grafana пароль: $GRAFANA_PASSWORD"
echo ""

echo -e "${CYAN}🌐 ССЫЛКИ ДЛЯ ДОСТУПА${NC}"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo "• DIGroup:              http://$SERVER_IP:6806"
echo "• Grafana:              http://$SERVER_IP:3000"
echo "                          Логин: admin"
echo "                          Пароль: $GRAFANA_PASSWORD"
echo "• Prometheus:           http://$SERVER_IP:9090"
echo ""

echo -e "${CYAN}🛠️ УПРАВЛЕНИЕ${NC}"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo "Остановка:     cd $INSTALL_DIR && docker compose down"
echo "Запуск:        cd $INSTALL_DIR && docker compose up -d"
echo "Логи:          cd $INSTALL_DIR && docker compose logs -f"
echo "Статус:        cd $INSTALL_DIR && docker compose ps"
echo ""

echo -e "${CYAN}📝 ДОПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ${NC}"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo "Директория установки: $INSTALL_DIR"
echo "Конфигурация: $INSTALL_DIR/.env"
echo "Данные: $INSTALL_DIR/workspace"
echo "Резервные копии: $INSTALL_DIR/backups"
echo ""

echo -e "${CYAN}🔒 БЕЗОПАСНОСТЬ${NC}"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo "Рекомендуется:"
echo "1. Настроить firewall (ufw allow 6806/tcp)"
echo "2. Использовать reverse proxy (Nginx/Caddy) с SSL"
echo "3. Сменить пароли в production окружении"
echo ""

print_success "Все готово!"
echo ""
echo -e "${YELLOW}💡 Откройте http://$SERVER_IP:6806 в браузере${NC}"
echo ""

# Сохранение данных доступа
cat > "$INSTALL_DIR/ACCESS_INFO.txt" << EOF
DIGroup Access Information
==========================

Generated: $(date)

Access Code: $ACCESS_AUTH_CODE
Grafana Password: $GRAFANA_PASSWORD

URLs:
- DIGroup: http://$SERVER_IP:6806
- Grafana: http://$SERVER_IP:3000
- Prometheus: http://$SERVER_IP:9090

Installation Directory: $INSTALL_DIR
EOF

print_success "Данные доступа сохранены в $INSTALL_DIR/ACCESS_INFO.txt"
echo ""
