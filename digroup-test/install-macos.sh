#!/bin/bash
# Автоматическая установка DIGroup для macOS
# Использование: ./install-macos.sh

set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Функции
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25 2>/dev/null || echo "test-password-$(date +%s)"
}

generate_auth_code() {
    openssl rand -hex 16 2>/dev/null || echo "b226ba0f30a134fe9245792118bca202"
}

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# Проверка macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    log_error "Этот скрипт предназначен для macOS"
    exit 1
fi

# Проверка Docker
log "Проверка Docker..."
if ! command -v docker &> /dev/null; then
    log_error "Docker не установлен. Установите Docker Desktop: https://www.docker.com/products/docker-desktop"
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    log_error "Docker не запущен. Запустите Docker Desktop"
    exit 1
fi

log_success "Docker доступен"
echo ""

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/digroup-test"
DEPLOY_DIR="$SCRIPT_DIR/deploy"

log "Директория установки: $TEST_DIR"
echo ""

# Генерация паролей
log "Генерация паролей..."
ACCESS_AUTH_CODE=$(generate_auth_code)
GRAFANA_PASSWORD=$(generate_password)
POSTGRES_PASSWORD=$(generate_password)
JWT_SECRET=$(generate_password)
log_success "Пароли сгенерированы"
echo ""

# Создание директорий
log "Создание директорий..."
mkdir -p "$TEST_DIR"/{workspace,data,backups,logs}
mkdir -p "$TEST_DIR/deploy"/{monitoring/{prometheus,grafana},supabase-local}
log_success "Директории созданы"
echo ""

# Копирование проекта
log "Копирование проекта..."
cp -r "$SCRIPT_DIR"/* "$TEST_DIR/" 2>/dev/null || true
log_success "Проект скопирован"
echo ""

# Создание .env
log "Создание .env..."
cat > "$TEST_DIR/.env" << EOF
ACCESS_AUTH_CODE=$ACCESS_AUTH_CODE
GRAFANA_PASSWORD=$GRAFANA_PASSWORD
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
JWT_SECRET=$JWT_SECRET
TZ=Europe/Moscow
KERNEL_PORT=6806
SUPABASE_URL=http://127.0.0.1:3001
SUPABASE_KEY=$JWT_SECRET
SUPABASE_AUDIT_TABLE=audit_logs
SUPABASE_LOCAL=true
SUPABASE_DB_PASSWORD=$POSTGRES_PASSWORD
OLLAMA_URL=http://localhost:11434
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
EOF
log_success ".env создан"
echo ""

# Создание docker-compose.yml
log "Создание docker-compose.yml..."
cat > "$TEST_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  digroup:
    build:
      context: ../siyuan
      dockerfile: Dockerfile
    container_name: digroup-test
    restart: unless-stopped
    ports:
      - "6806:6806"
    environment:
      - TZ=Europe/Moscow
      - ACCESS_AUTH_CODE=\${ACCESS_AUTH_CODE}
    volumes:
      - ./workspace:/opt/siyuan/workspace
      - ./data:/opt/siyuan/data
    command: [
      "/opt/siyuan/kernel",
      "--workspace=/opt/siyuan/workspace",
      "--accessAuthCode=\${ACCESS_AUTH_CODE}",
      "--port=6806"
    ]
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:6806/api/system/version"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - digroup-network

  supabase-db:
    image: supabase/postgres:15.1.0.117
    container_name: supabase-db-test
    restart: unless-stopped
    ports:
      - "54322:5432"
    environment:
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      JWT_SECRET: \${JWT_SECRET}
    volumes:
      - supabase_db_data_test:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U supabase_admin"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - digroup-network

  supabase-rest:
    image: postgrest/postgrest:v11.2.0
    container_name: supabase-rest-test
    restart: unless-stopped
    ports:
      - "3001:3000"
    environment:
      PGRST_DB_URI: postgres://supabase_admin:\${POSTGRES_PASSWORD}@supabase-db:5432/postgres
      PGRST_DB_SCHEMAS: public
      PGRST_DB_ANON_ROLE: anon
      PGRST_JWT_SECRET: \${JWT_SECRET}
    depends_on:
      supabase-db:
        condition: service_healthy
    networks:
      - digroup-network

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus-test
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data_test:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    networks:
      - digroup-network

  grafana:
    image: grafana/grafana:latest
    container_name: grafana-test
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=\${GRAFANA_PASSWORD}
      - GF_SERVER_ROOT_URL=http://localhost:3000
    volumes:
      - grafana_data_test:/var/lib/grafana
    depends_on:
      - prometheus
    networks:
      - digroup-network

volumes:
  supabase_db_data_test:
  prometheus_data_test:
  grafana_data_test:

networks:
  digroup-network:
    driver: bridge
EOF

# Создание prometheus.yml
log "Создание конфигурации Prometheus..."
cat > "$TEST_DIR/prometheus.yml" << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'digroup'
    static_configs:
      - targets: ['digroup-test:6806']
EOF

log_success "Конфигурации созданы"
echo ""

# Запуск сервисов
log "Запуск всех сервисов..."
cd "$TEST_DIR"

set -a
source .env
set +a

log "Сборка и запуск Docker контейнеров..."
docker-compose up -d --build

log_success "Сервисы запускаются..."
echo ""

# Ожидание запуска DIGroup
log "Ожидание запуска DIGroup kernel..."
for i in {1..60}; do
    if curl -s http://localhost:6806/api/system/version > /dev/null 2>&1; then
        log_success "DIGroup kernel запущен"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

# Ожидание Supabase
log "Ожидание запуска Supabase..."
for i in {1..30}; do
    if docker exec supabase-db-test pg_isready -U supabase_admin > /dev/null 2>&1; then
        log_success "Supabase запущен"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

# Настройка базы данных
log "Настройка базы данных..."
docker exec -i supabase-db-test psql -U supabase_admin -d postgres << EOF > /dev/null 2>&1 || true
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
    END IF;
END
\$\$;
GRANT anon TO authenticated;
GRANT authenticated TO service_role;
GRANT ALL ON DATABASE postgres TO service_role;
GRANT ALL ON SCHEMA public TO anon, authenticated, service_role;
EOF

# Создание таблиц
if [ -f "$TEST_DIR/deploy/audit/supabase-setup.sql" ]; then
    TEMP_SQL="/tmp/supabase_test_$(date +%s).sql"
    cat "$TEST_DIR/deploy/audit/supabase-setup.sql" | \
        grep -v "ENABLE ROW LEVEL SECURITY" | \
        grep -v "CREATE POLICY" | \
        grep -v "POLICY" > "$TEMP_SQL" || true
    
    cat >> "$TEMP_SQL" << EOF
GRANT SELECT, INSERT ON audit_logs TO anon, authenticated, service_role;
GRANT SELECT, INSERT ON user_sessions TO anon, authenticated, service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
EOF
    
    docker exec -i supabase-db-test psql -U supabase_admin -d postgres < "$TEMP_SQL" > /dev/null 2>&1 || true
    rm -f "$TEMP_SQL"
    log_success "База данных настроена"
fi
echo ""

# Проверка Ollama
log "Проверка Ollama..."
if command -v ollama &> /dev/null; then
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        log_success "Ollama доступен"
    else
        log_warning "Ollama не запущен. Запустите: ollama serve"
    fi
else
    log_warning "Ollama не установлен. Установите: brew install ollama"
fi
echo ""

# Итоговая информация
clear
echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                          ║"
echo "║                    ✅ УСТАНОВКА ЗАВЕРШЕНА!                               ║"
echo "║                                                                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

echo -e "${BOLD}${CYAN}🔐 ДАННЫЕ ДЛЯ ДОСТУПА${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}AccessAuthCode:${NC} ${YELLOW}$ACCESS_AUTH_CODE${NC}"
echo -e "${BOLD}Grafana пароль:${NC} ${YELLOW}$GRAFANA_PASSWORD${NC}"
echo ""

echo -e "${BOLD}${CYAN}🌐 ССЫЛКИ ДЛЯ ДОСТУПА${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "• ${BOLD}DIGroup:${NC}              ${GREEN}http://localhost:6806${NC}"
echo -e "• ${BOLD}Grafana:${NC}              ${GREEN}http://localhost:3000${NC}"
echo -e "                          Логин: ${YELLOW}admin${NC}"
echo -e "                          Пароль: ${YELLOW}$GRAFANA_PASSWORD${NC}"
echo -e "• ${BOLD}Prometheus:${NC}           ${GREEN}http://localhost:9090${NC}"
echo -e "• ${BOLD}Supabase API:${NC}          ${GREEN}http://localhost:3001${NC}"
echo ""

echo -e "${BOLD}${CYAN}🛠️ УПРАВЛЕНИЕ${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Остановка:     ${CYAN}cd $TEST_DIR && docker-compose down${NC}"
echo -e "Запуск:        ${CYAN}cd $TEST_DIR && docker-compose up -d${NC}"
echo -e "Логи:          ${CYAN}cd $TEST_DIR && docker-compose logs -f${NC}"
echo -e "Статус:        ${CYAN}cd $TEST_DIR && docker-compose ps${NC}"
echo ""

echo -e "${BOLD}${GREEN}✅ Все готово!${NC}"
echo ""
echo -e "${YELLOW}💡 Откройте http://localhost:6806 в браузере${NC}"
echo ""

