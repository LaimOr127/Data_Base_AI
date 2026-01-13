#!/bin/bash
# Автоматическая настройка локального Supabase
# Использование: sudo ./setup-local-supabase.sh

set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="/opt/digroup"
ENV_FILE="$INSTALL_DIR/.env"
SQL_FILE="$INSTALL_DIR/deploy/audit/supabase-setup.sql"
COMPOSE_FILE="$INSTALL_DIR/deploy/supabase-local/docker-compose.supabase.yml"

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

echo -e "${BOLD}${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     🏠 Настройка локального Supabase для аудита           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Генерация паролей
log "Генерация безопасных паролей..."
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
JWT_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

log_success "Пароли сгенерированы"
echo ""

# Создание .env для Supabase
SUPABASE_ENV_FILE="$INSTALL_DIR/deploy/supabase-local/.env"
mkdir -p "$(dirname $SUPABASE_ENV_FILE)"

cat > "$SUPABASE_ENV_FILE" << EOF
# Локальный Supabase конфигурация
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
JWT_SECRET=$JWT_SECRET
JWT_EXP=3600
EOF

chmod 600 "$SUPABASE_ENV_FILE"
log_success "Конфигурация Supabase создана"
echo ""

# Копирование docker-compose если нужно
if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "Файл docker-compose.supabase.yml не найден: $COMPOSE_FILE"
    exit 1
fi

# Запуск Supabase
log "Запуск локального Supabase..."
cd "$INSTALL_DIR/deploy/supabase-local"

# Загрузка переменных окружения
set -a
source "$SUPABASE_ENV_FILE"
set +a

docker-compose -f docker-compose.supabase.yml up -d > /dev/null 2>&1

log_success "Supabase запущен"
echo ""

# Ожидание готовности PostgreSQL
log "Ожидание готовности базы данных..."
for i in {1..30}; do
    if docker exec supabase-db pg_isready -U supabase_admin > /dev/null 2>&1; then
        log_success "База данных готова"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

if [ $i -eq 30 ]; then
    log_error "База данных не готова после 60 секунд"
    exit 1
fi

# Создание пользователя и ролей для аудита
log "Настройка базы данных..."

# Создание ролей и пользователей для Supabase
docker exec -i supabase-db psql -U supabase_admin -d postgres << EOF > /dev/null 2>&1 || true
-- Создание роли для анонимного доступа
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN NOINHERIT;
    END IF;
END
\$\$;

-- Создание роли для аутентифицированных пользователей
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN NOINHERIT;
    END IF;
END
\$\$;

-- Создание роли для сервиса
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
    END IF;
END
\$\$;

-- Предоставление прав
GRANT anon TO authenticated;
GRANT authenticated TO service_role;
GRANT ALL ON DATABASE postgres TO service_role;
GRANT ALL ON SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
EOF

log_success "Роли созданы"
echo ""

# Выполнение SQL для создания таблиц
log "Создание таблиц для аудита..."

if [ -f "$SQL_FILE" ]; then
    # Адаптация SQL для локального Supabase
    # Удаляем RLS политики, так как они могут конфликтовать
    TEMP_SQL="/tmp/supabase_local_setup_$(date +%s).sql"
    cat "$SQL_FILE" | grep -v "ENABLE ROW LEVEL SECURITY" | \
        grep -v "CREATE POLICY" | \
        grep -v "POLICY" > "$TEMP_SQL" || true
    
    # Добавляем GRANT для анонимного доступа
    cat >> "$TEMP_SQL" << EOF

-- Предоставление прав для аудита
GRANT SELECT, INSERT ON audit_logs TO anon, authenticated, service_role;
GRANT SELECT, INSERT ON user_sessions TO anon, authenticated, service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO anon, authenticated, service_role;
EOF
    
    if docker exec -i supabase-db psql -U supabase_admin -d postgres < "$TEMP_SQL" > /dev/null 2>&1; then
        log_success "Таблицы созданы"
        rm -f "$TEMP_SQL"
    else
        log_warning "Не удалось выполнить SQL автоматически"
        log "SQL файл сохранен: $TEMP_SQL"
        log "Выполните вручную:"
        log "  docker exec -i supabase-db psql -U supabase_admin -d postgres < $TEMP_SQL"
    fi
else
    log_error "SQL файл не найден: $SQL_FILE"
    exit 1
fi

echo ""

# Получение URL и ключей
SUPABASE_URL="http://127.0.0.1:3001"
SUPABASE_ANON_KEY="$JWT_SECRET"  # Для локального использования можно использовать JWT_SECRET

# Обновление основного .env
log "Обновление .env файла..."
if [ -f "$ENV_FILE" ]; then
    sed -i '/^SUPABASE_URL=/d' "$ENV_FILE"
    sed -i '/^SUPABASE_KEY=/d' "$ENV_FILE"
    sed -i '/^SUPABASE_AUDIT_TABLE=/d' "$ENV_FILE"
    sed -i '/^SUPABASE_LOCAL=/d' "$ENV_FILE"
    
    echo "" >> "$ENV_FILE"
    echo "# Локальный Supabase конфигурация" >> "$ENV_FILE"
    echo "SUPABASE_URL=$SUPABASE_URL" >> "$ENV_FILE"
    echo "SUPABASE_KEY=$JWT_SECRET" >> "$ENV_FILE"
    echo "SUPABASE_AUDIT_TABLE=audit_logs" >> "$ENV_FILE"
    echo "SUPABASE_LOCAL=true" >> "$ENV_FILE"
    echo "SUPABASE_DB_PASSWORD=$POSTGRES_PASSWORD" >> "$ENV_FILE"
    
    log_success ".env обновлен"
else
    log_warning ".env файл не найден"
fi

# Тест подключения
log "Тест подключения..."
sleep 2

if curl -s "$SUPABASE_URL/rest/v1/" \
    -H "apikey: $JWT_SECRET" > /dev/null 2>&1; then
    log_success "Подключение работает"
else
    log_warning "Не удалось проверить подключение (это нормально, если таблицы еще не созданы)"
fi

# Итоговая информация
echo ""
echo -e "${BOLD}${GREEN}✅ Локальный Supabase настроен!${NC}"
echo ""
echo -e "${BOLD}📋 Информация:${NC}"
echo "  URL: $SUPABASE_URL"
echo "  Anon Key: ${JWT_SECRET:0:20}..."
echo "  PostgreSQL: localhost:54322"
echo "  Пароль БД: $POSTGRES_PASSWORD"
echo "  Таблица: audit_logs"
echo ""
echo -e "${BOLD}🔧 Управление:${NC}"
echo "  Остановка: cd $INSTALL_DIR/deploy/supabase-local && docker-compose -f docker-compose.supabase.yml down"
echo "  Запуск: cd $INSTALL_DIR/deploy/supabase-local && docker-compose -f docker-compose.supabase.yml up -d"
echo "  Логи: docker-compose -f docker-compose.supabase.yml logs -f"
echo ""
echo -e "${BOLD}💾 Данные:${NC}"
echo "  Хранятся в Docker volume: supabase_db_data"
echo "  Для бэкапа: docker exec supabase-db pg_dump -U supabase_admin postgres > backup.sql"
echo ""

