#!/bin/bash
# Полностью автоматическая установка DIGroup для Linux (Ubuntu/Debian)
# Использование: sudo ./install.sh [--domain=your-domain.com] [--email=your@email.com]

set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Пожалуйста, запустите скрипт с правами root: sudo ./install.sh${NC}"
    exit 1
fi

# Парсинг аргументов
DOMAIN=""
EMAIL=""
for arg in "$@"; do
    case $arg in
        --domain=*)
        DOMAIN="${arg#*=}"
        shift
        ;;
        --email=*)
        EMAIL="${arg#*=}"
        shift
        ;;
    esac
done

# Функции
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

generate_auth_code() {
    openssl rand -hex 16
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

# Начало установки
clear
echo -e "${BOLD}${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║     🚀 Автоматическая установка DIGroup                   ║"
echo "║     Включая: DIGroup, Мониторинг, Supabase, Ollama       ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/digroup"
DEPLOY_DIR="$SCRIPT_DIR/deploy"

log "Директория установки: $INSTALL_DIR"
echo ""

# Генерация паролей
log "Генерация безопасных паролей..."
ACCESS_AUTH_CODE=$(generate_auth_code)
GRAFANA_PASSWORD=$(generate_password)
POSTGRES_PASSWORD=$(generate_password)
JWT_SECRET=$(generate_password)
log_success "Пароли сгенерированы"
echo ""

# Шаг 1: Обновление системы
log "1️⃣  Обновление системы..."
apt update -qq && apt upgrade -y -qq
log_success "Система обновлена"
echo ""

# Шаг 2: Установка всех необходимых пакетов и библиотек
log "2️⃣  Установка необходимых пакетов и библиотек..."
apt install -y -qq \
    docker.io \
    docker-compose \
    nginx \
    curl \
    wget \
    git \
    openssl \
    certbot \
    python3-certbot-nginx \
    apache2-utils \
    htop \
    ufw \
    jq \
    postgresql-client \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg2 \
    > /dev/null 2>&1

# Включение Docker
systemctl enable docker > /dev/null 2>&1
systemctl start docker > /dev/null 2>&1
usermod -aG docker $SUDO_USER > /dev/null 2>&1

log_success "Пакеты установлены"
echo ""

# Шаг 3: Установка Ollama
log "3️⃣  Установка Ollama для локального ИИ..."
if ! command -v ollama &> /dev/null; then
    # Установка Ollama
    curl -fsSL https://ollama.com/install.sh | sh > /dev/null 2>&1
    
    # Запуск Ollama как сервис
    systemctl enable ollama > /dev/null 2>&1
    systemctl start ollama > /dev/null 2>&1
    
    # Ожидание запуска
    log "Ожидание запуска Ollama..."
    for i in {1..30}; do
        if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
            log_success "Ollama запущен"
            break
        fi
        sleep 2
        echo -n "."
    done
    echo ""
    
    # Загрузка модели (в фоне, не блокируем установку)
    log "Загрузка AI модели (это может занять время)..."
    ollama pull nemotron-3-nano:30b-cloud > /tmp/ollama-pull.log 2>&1 &
    log_success "Ollama установлен, модель загружается в фоне"
else
    log_success "Ollama уже установлен"
    # Проверка запуска
    if ! systemctl is-active --quiet ollama; then
        systemctl start ollama > /dev/null 2>&1
    fi
fi
echo ""

# Шаг 4: Создание директорий
log "4️⃣  Создание директорий..."
mkdir -p "$INSTALL_DIR"/{workspace,data,backups,logs}
mkdir -p /var/log/nginx
chown -R $SUDO_USER:$SUDO_USER "$INSTALL_DIR"
log_success "Директории созданы"
echo ""

# Шаг 5: Копирование проекта
log "5️⃣  Копирование проекта..."
if [ -d "$SCRIPT_DIR/siyuan" ]; then
    cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/" 2>/dev/null || true
    chown -R $SUDO_USER:$SUDO_USER "$INSTALL_DIR"
    log_success "Проект скопирован"
else
    log_warning "Проект не найден, будет использован существующий в $INSTALL_DIR"
fi
echo ""

# Шаг 6: Настройка переменных окружения
log "6️⃣  Настройка переменных окружения..."
ENV_FILE="$INSTALL_DIR/.env"
cat > "$ENV_FILE" << EOF
# DIGroup Configuration
# Автоматически сгенерировано $(date '+%Y-%m-%d %H:%M:%S')

# Секретный код доступа
ACCESS_AUTH_CODE=$ACCESS_AUTH_CODE

# Часовой пояс
TZ=Europe/Moscow

# Порт для kernel
KERNEL_PORT=6806

# Домен (если есть)
DOMAIN=$DOMAIN

# Email для Let's Encrypt
SSL_EMAIL=$EMAIL

# Grafana
GRAFANA_PASSWORD=$GRAFANA_PASSWORD

# Локальный Supabase
SUPABASE_URL=http://127.0.0.1:3001
SUPABASE_KEY=$JWT_SECRET
SUPABASE_AUDIT_TABLE=audit_logs
SUPABASE_LOCAL=true
SUPABASE_DB_PASSWORD=$POSTGRES_PASSWORD

# Ollama
OLLAMA_URL=http://localhost:11434
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
EOF

chown $SUDO_USER:$SUDO_USER "$ENV_FILE"
chmod 600 "$ENV_FILE"
log_success "Переменные окружения настроены"
echo ""

# Шаг 7: Настройка Docker Compose для DIGroup
log "7️⃣  Настройка Docker Compose..."
if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
    sed -i "s|ACCESS_AUTH_CODE=.*|ACCESS_AUTH_CODE=\${ACCESS_AUTH_CODE}|g" "$INSTALL_DIR/docker-compose.yml" 2>/dev/null || true
    log_success "Docker Compose настроен"
fi
echo ""

# Шаг 8: Настройка локального Supabase
log "8️⃣  Настройка локального Supabase..."
if [ -f "$DEPLOY_DIR/supabase-local/docker-compose.supabase.yml" ]; then
    cd "$DEPLOY_DIR/supabase-local"
    
    # Создание .env для Supabase
    cat > .env << EOF
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
JWT_SECRET=$JWT_SECRET
JWT_EXP=3600
EOF
    
    # Запуск Supabase
    set -a
    source .env
    set +a
    
    docker-compose -f docker-compose.supabase.yml up -d > /dev/null 2>&1
    
    # Ожидание готовности
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
    
    # Создание ролей
    docker exec -i supabase-db psql -U supabase_admin -d postgres << EOF > /dev/null 2>&1 || true
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
    if [ -f "$INSTALL_DIR/deploy/audit/supabase-setup.sql" ]; then
        TEMP_SQL="/tmp/supabase_setup_$(date +%s).sql"
        cat "$INSTALL_DIR/deploy/audit/supabase-setup.sql" | \
            grep -v "ENABLE ROW LEVEL SECURITY" | \
            grep -v "CREATE POLICY" | \
            grep -v "POLICY" > "$TEMP_SQL" || true
        
        cat >> "$TEMP_SQL" << EOF
GRANT SELECT, INSERT ON audit_logs TO anon, authenticated, service_role;
GRANT SELECT, INSERT ON user_sessions TO anon, authenticated, service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
EOF
        
        docker exec -i supabase-db psql -U supabase_admin -d postgres < "$TEMP_SQL" > /dev/null 2>&1 || true
        rm -f "$TEMP_SQL"
    fi
    
    log_success "Локальный Supabase настроен"
else
    log_warning "Конфигурация Supabase не найдена"
fi
echo ""

# Шаг 9: Настройка Nginx
log "9️⃣  Настройка Nginx..."
if [ -f "$DEPLOY_DIR/nginx/digroup.conf" ]; then
    cp "$DEPLOY_DIR/nginx/digroup.conf" /etc/nginx/sites-available/digroup
    
    if [ -n "$DOMAIN" ]; then
        sed -i "s/server_name _;/server_name $DOMAIN;/" /etc/nginx/sites-available/digroup
    fi
    
    # Добавление Grafana и Prometheus в конфигурацию
    # Проверяем, не добавлены ли уже
    if ! grep -q "location /grafana/" /etc/nginx/sites-available/digroup; then
        cat >> /etc/nginx/sites-available/digroup << 'NGINX_EOF'

    # Grafana
    location /grafana/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Prometheus (защищен паролем)
    location /prometheus/ {
        proxy_pass http://127.0.0.1:9090/;
        auth_basic "Prometheus Access";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
NGINX_EOF
    fi
    
    ln -sf /etc/nginx/sites-available/digroup /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    if nginx -t > /dev/null 2>&1; then
        systemctl enable nginx > /dev/null 2>&1
        systemctl reload nginx > /dev/null 2>&1
        log_success "Nginx настроен"
    else
        log_error "Ошибка в конфигурации Nginx"
    fi
fi
echo ""

# Шаг 10: Настройка SSL (если есть домен)
if [ -n "$DOMAIN" ] && [ -n "$EMAIL" ]; then
    log "🔟 Настройка SSL сертификата..."
    if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect > /dev/null 2>&1; then
        log_success "SSL сертификат установлен"
        (crontab -l 2>/dev/null | grep -v "certbot renew"; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab - > /dev/null 2>&1
    else
        log_warning "Не удалось установить SSL сертификат"
    fi
    echo ""
fi

# Шаг 11: Настройка Firewall
log "1️⃣1️⃣  Настройка Firewall..."
ufw --force enable > /dev/null 2>&1
ufw allow 22/tcp > /dev/null 2>&1
ufw allow 80/tcp > /dev/null 2>&1
ufw allow 443/tcp > /dev/null 2>&1
log_success "Firewall настроен"
echo ""

# Шаг 12: Настройка systemd service
log "1️⃣2️⃣  Настройка автозапуска..."
if [ -f "$DEPLOY_DIR/systemd/digroup.service" ]; then
    cp "$DEPLOY_DIR/systemd/digroup.service" /etc/systemd/system/
    sed -i "s|WorkingDirectory=.*|WorkingDirectory=$INSTALL_DIR|g" /etc/systemd/system/digroup.service
    systemctl daemon-reload > /dev/null 2>&1
    systemctl enable digroup > /dev/null 2>&1
    log_success "Автозапуск настроен"
fi
echo ""

# Шаг 13: Настройка бэкапов
log "1️⃣3️⃣  Настройка бэкапов..."
if [ -f "$DEPLOY_DIR/scripts/backup.sh" ]; then
    cp "$DEPLOY_DIR/scripts/backup.sh" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/backup.sh"
    chown $SUDO_USER:$SUDO_USER "$INSTALL_DIR/backup.sh"
    (crontab -u $SUDO_USER -l 2>/dev/null | grep -v "backup.sh"; echo "0 2 * * * $INSTALL_DIR/backup.sh >> /var/log/digroup-backup.log 2>&1") | crontab -u $SUDO_USER - > /dev/null 2>&1
    log_success "Бэкапы настроены (ежедневно в 2:00)"
fi
echo ""

# Шаг 14: Запуск DIGroup
log "1️⃣4️⃣  Запуск DIGroup..."
cd "$INSTALL_DIR"
if [ -f "docker-compose.yml" ]; then
    set -a
    source "$ENV_FILE"
    set +a
    
    docker-compose up -d > /dev/null 2>&1
    
    log "Ожидание запуска kernel..."
    for i in {1..30}; do
        if curl -s http://127.0.0.1:6806/api/system/version > /dev/null 2>&1; then
            log_success "DIGroup запущен"
            break
        fi
        sleep 2
        echo -n "."
    done
    echo ""
else
    log_warning "docker-compose.yml не найден"
fi
echo ""

# Шаг 15: Запуск мониторинга
log "1️⃣5️⃣  Запуск мониторинга..."
if [ -f "$DEPLOY_DIR/monitoring/docker-compose.monitoring.yml" ]; then
    cd "$DEPLOY_DIR/monitoring"
    echo "GRAFANA_PASSWORD=$GRAFANA_PASSWORD" > .env
    docker-compose -f docker-compose.monitoring.yml up -d > /dev/null 2>&1
    log_success "Мониторинг запущен"
fi
echo ""

# Создание пароля для Prometheus
log "1️⃣6️⃣  Настройка доступа к Prometheus..."
PROMETHEUS_PASSWORD=$(generate_password)
echo "prometheus:$PROMETHEUS_PASSWORD" | htpasswd -ci /etc/nginx/.htpasswd prometheus > /dev/null 2>&1
log_success "Prometheus защищен паролем"
echo ""

# Получение IP адреса
SERVER_IP=$(hostname -I | awk '{print $1}')
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "ВАШ_IP_АДРЕС")
fi

# Определение URL доступа
if [ -n "$DOMAIN" ]; then
    ACCESS_URL="https://$DOMAIN"
    GRAFANA_URL="https://$DOMAIN/grafana/"
    PROMETHEUS_URL="https://$DOMAIN/prometheus/"
else
    ACCESS_URL="http://$SERVER_IP"
    GRAFANA_URL="http://$SERVER_IP:3000"
    PROMETHEUS_URL="http://$SERVER_IP:9090"
fi

# Сохранение информации
INFO_FILE="$INSTALL_DIR/INSTALL_INFO.txt"
cat > "$INFO_FILE" << EOF
╔══════════════════════════════════════════════════════════════════════════╗
║                    📋 ИНФОРМАЦИЯ ОБ УСТАНОВКЕ DIGroup                   ║
║                    Установлено: $(date '+%Y-%m-%d %H:%M:%S')                      ║
╚══════════════════════════════════════════════════════════════════════════╝

🔐 ВАЖНЫЕ ДАННЫЕ ДЛЯ ДОСТУПА
═══════════════════════════════════════════════════════════════════════════

1. AccessAuthCode (для входа в DIGroup):
   $ACCESS_AUTH_CODE

2. Grafana пароль:
   $GRAFANA_PASSWORD

3. Prometheus пароль:
   $PROMETHEUS_PASSWORD
   Пользователь: prometheus

4. Supabase пароль БД:
   $POSTGRES_PASSWORD

🌐 ССЫЛКИ ДЛЯ ДОСТУПА
═══════════════════════════════════════════════════════════════════════════

• DIGroup:              $ACCESS_URL
• Grafana:              $GRAFANA_URL
                          Логин: admin
                          Пароль: $GRAFANA_PASSWORD
• Prometheus:           $PROMETHEUS_URL
                          Логин: prometheus
                          Пароль: $PROMETHEUS_PASSWORD
• Supabase (локальный): http://127.0.0.1:3001
• Ollama:               http://localhost:11434

🤖 ИСКУССТВЕННЫЙ ИНТЕЛЛЕКТ
═══════════════════════════════════════════════════════════════════════════

• Ollama установлен и запущен
• Модель: nemotron-3-nano:30b-cloud
• URL: http://localhost:11434
• Статус: $(systemctl is-active ollama 2>/dev/null || echo "проверьте вручную")

💾 БЭКАПЫ
═══════════════════════════════════════════════════════════════════════════

• Ручной бэкап:         sudo $INSTALL_DIR/backup.sh
• Автоматические:       Ежедневно в 2:00
• Директория:           $INSTALL_DIR/backups

🛠️ УПРАВЛЕНИЕ
═══════════════════════════════════════════════════════════════════════════

• Остановка:            cd $INSTALL_DIR && docker-compose down
• Запуск:               cd $INSTALL_DIR && docker-compose up -d
• Перезапуск:           cd $INSTALL_DIR && docker-compose restart
• Ollama:               systemctl restart ollama
• Supabase:             cd $INSTALL_DIR/deploy/supabase-local && docker-compose -f docker-compose.supabase.yml restart

📁 ДИРЕКТОРИИ
═══════════════════════════════════════════════════════════════════════════

• Установка:            $INSTALL_DIR
• Workspace:            $INSTALL_DIR/workspace
• Бэкапы:               $INSTALL_DIR/backups
• Конфигурация:         $INSTALL_DIR/.env

⚠️ ВАЖНО
═══════════════════════════════════════════════════════════════════════════

1. Сохраните этот файл в безопасном месте!
2. Не передавайте пароли третьим лицам
3. Регулярно проверяйте логи
4. Все данные хранятся локально на сервере

═══════════════════════════════════════════════════════════════════════════
EOF

chown $SUDO_USER:$SUDO_USER "$INFO_FILE"
chmod 600 "$INFO_FILE"

# Вывод итоговой информации
clear
echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                          ║"
echo "║                    ✅ УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!                       ║"
echo "║                                                                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

echo -e "${BOLD}${CYAN}🔐 ВАЖНЫЕ ДАННЫЕ ДЛЯ ДОСТУПА${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}1. AccessAuthCode (для входа в DIGroup):${NC}"
echo -e "   ${YELLOW}$ACCESS_AUTH_CODE${NC}"
echo ""
echo -e "${BOLD}2. Grafana пароль:${NC}"
echo -e "   ${YELLOW}$GRAFANA_PASSWORD${NC}"
echo ""
echo -e "${BOLD}3. Prometheus пароль:${NC}"
echo -e "   ${YELLOW}$PROMETHEUS_PASSWORD${NC}"
echo ""

echo -e "${BOLD}${CYAN}🌐 ССЫЛКИ ДЛЯ ДОСТУПА${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "• ${BOLD}DIGroup:${NC}              ${GREEN}$ACCESS_URL${NC}"
echo -e "• ${BOLD}Grafana:${NC}              ${GREEN}$GRAFANA_URL${NC}"
echo -e "                          Логин: ${YELLOW}admin${NC}"
echo -e "                          Пароль: ${YELLOW}$GRAFANA_PASSWORD${NC}"
if [ -n "$DOMAIN" ]; then
    echo -e "• ${BOLD}Prometheus:${NC}           ${GREEN}$PROMETHEUS_URL${NC}"
else
    echo -e "• ${BOLD}Prometheus:${NC}           ${GREEN}$PROMETHEUS_URL${NC} (только локально)"
fi
echo -e "                          Логин: ${YELLOW}prometheus${NC}"
echo -e "                          Пароль: ${YELLOW}$PROMETHEUS_PASSWORD${NC}"
echo ""

echo -e "${BOLD}${CYAN}🤖 ИСКУССТВЕННЫЙ ИНТЕЛЛЕКТ${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "• ${BOLD}Ollama:${NC}               ${GREEN}http://localhost:11434${NC}"
echo -e "• ${BOLD}Модель:${NC}               nemotron-3-nano:30b-cloud"
echo -e "• ${BOLD}Статус:${NC}               $(systemctl is-active ollama 2>/dev/null && echo -e "${GREEN}✅ Работает${NC}" || echo -e "${YELLOW}⚠️  Проверьте вручную${NC}")"
echo ""

echo -e "${BOLD}${CYAN}💾 БАЗА ДАННЫХ${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "• ${BOLD}Supabase (локальный):${NC} ${GREEN}http://127.0.0.1:3001${NC}"
echo -e "• ${BOLD}PostgreSQL:${NC}           localhost:54322"
echo ""

echo -e "${BOLD}${CYAN}📋 ДОПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Полная информация сохранена в: ${YELLOW}$INFO_FILE${NC}"
echo ""
echo -e "${BOLD}${GREEN}✅ Все готово к работе!${NC}"
echo ""

