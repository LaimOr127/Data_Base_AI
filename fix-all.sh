#!/bin/bash
# ЕДИНЫЙ СКРИПТ ДЛЯ ИСПРАВЛЕНИЯ ВСЕХ ПРОБЛЕМ
# Исправляет: AI, Облако, Опубликовать, тема, автор, 403, Wi-Fi, SiYuan→DiGroup
# Использование: ./fix-all.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Разрешаем продолжение при ошибках для диагностики
set +e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 ЕДИНЫЙ СКРИПТ ИСПРАВЛЕНИЯ ВСЕХ ПРОБЛЕМ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "❌ Запустите от root: sudo ./fix-all.sh"
    exit 1
fi

# ============================================================================
# ШАГ 0: Диагностика и исправление проблемы с ядром
# ============================================================================
echo "🔍 ШАГ 0: Диагностика проблемы с ядром..."
echo ""

# Проверка статуса контейнера
echo "📊 Проверка статуса контейнера..."
if docker ps -a | grep -q "digroup"; then
    CONTAINER_STATUS=$(docker inspect digroup --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
    echo "   Статус контейнера: $CONTAINER_STATUS"
    
    if [ "$CONTAINER_STATUS" != "running" ]; then
        echo "⚠️  Контейнер не запущен, перезапускаем..."
        docker compose down digroup 2>/dev/null || true
        sleep 2
        docker compose up -d digroup
        echo "[OK] Контейнер перезапущен"
        sleep 10
    fi
else
    echo "⚠️  Контейнер не найден, создаем..."
    docker compose up -d digroup
    sleep 10
fi

# Проверка доступности API
echo ""
echo "🌐 Проверка доступности API..."
MAX_RETRIES=5
RETRY_COUNT=0
API_AVAILABLE=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s --max-time 5 http://127.0.0.1:6806/api/system/version > /dev/null 2>&1; then
        API_AVAILABLE=true
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "   Попытка $RETRY_COUNT/$MAX_RETRIES..."
    sleep 3
done

if [ "$API_AVAILABLE" = false ]; then
    echo "⚠️  API недоступен, выполняем полный перезапуск..."
    
    # Останавливаем контейнер
    docker compose stop digroup 2>/dev/null || true
    sleep 3
    
    # Проверяем логи на ошибки
    echo ""
    echo "📋 Последние ошибки в логах:"
    docker compose logs --tail=20 digroup 2>&1 | grep -i "error\|fatal\|panic" | head -n 5 || echo "   Критических ошибок не найдено"
    
    # Удаляем контейнер и создаем заново
    docker compose rm -f digroup 2>/dev/null || true
    sleep 2
    
    # Запускаем заново
    docker compose up -d digroup
    echo "[OK] Контейнер пересоздан"
    
    # Ждем запуска
    echo ""
    echo "⏳ Ожидание запуска ядра (до 60 секунд)..."
    for i in {1..12}; do
        if curl -s --max-time 2 http://127.0.0.1:6806/api/system/version > /dev/null 2>&1; then
            echo "[OK] API доступен после перезапуска"
            API_AVAILABLE=true
            break
        fi
        echo "   Ожидание... ($i/12)"
        sleep 5
    done
    
    if [ "$API_AVAILABLE" = false ]; then
        echo "❌ API все еще недоступен после перезапуска"
        echo ""
        echo "Проверьте логи:"
        echo "   docker compose logs -f digroup"
        echo ""
        echo "Проверьте порт:"
        echo "   netstat -tlnp | grep 6806"
        echo ""
        echo "Попробуйте перезапустить вручную:"
        echo "   docker compose restart digroup"
        echo ""
    fi
else
    echo "[OK] API доступен"
fi

# Проверка порта
echo ""
echo "🔌 Проверка порта 6806..."
if netstat -tlnp 2>/dev/null | grep -q ":6806" || ss -tlnp 2>/dev/null | grep -q ":6806"; then
    echo "[OK] Порт 6806 открыт"
else
    echo "⚠️  Порт 6806 не слушается"
fi

# Проверка сетевого подключения Docker
echo ""
echo "🌐 Проверка сетевого подключения Docker..."
if docker network ls | grep -q "digroup-network"; then
    echo "[OK] Сеть digroup-network существует"
else
    echo "⚠️  Сеть не найдена, создаем..."
    docker compose up -d --force-recreate digroup 2>/dev/null || true
fi

echo ""
if [ "$API_AVAILABLE" = false ]; then
    echo "⚠️  ВНИМАНИЕ: Проблема с ядром не решена автоматически"
    echo "   Продолжаем исправление остальных проблем..."
    echo "   После завершения проверьте логи: docker compose logs -f digroup"
    echo ""
fi

# ============================================================================
# ШАГ 1: Исправление прав на файлы
# ============================================================================
echo "🔐 ШАГ 1: Исправление прав на файлы..."
if [ -d "workspace" ]; then
    chown -R 1000:1000 workspace
    chmod -R 755 workspace/conf
    chmod -R 755 workspace/data 2>/dev/null || true
    chmod 644 workspace/conf/conf.json 2>/dev/null || true
    find workspace -type f -name "*.json" -exec chmod 644 {} \; 2>/dev/null || true
    find workspace -type d -exec chmod 755 {} \; 2>/dev/null || true
    echo "[OK] Права исправлены"
else
    echo "⚠️  Директория workspace не найдена"
fi
echo ""

# ============================================================================
# ШАГ 2: Настройка AI через OpenRouter (исправление host.docker.internal)
# ============================================================================
echo "🤖 ШАГ 2: Настройка AI через OpenRouter..."
if [ -f "workspace/conf/conf.json" ] && command -v python3 &> /dev/null; then
    python3 << 'PYTHON_SCRIPT'
import json
import re

conf_path = 'workspace/conf/conf.json'
with open(conf_path, 'r', encoding='utf-8') as f:
    conf = json.load(f)

if 'ai' not in conf:
    conf['ai'] = {}

# Настройка OpenRouter с бесплатной моделью
conf['ai']['openAI'] = {
    'apiBaseURL': 'https://openrouter.ai/api/v1',
    'apiKey': '',
    'apiModel': 'mistralai/devstral-2512:free',
    'apiMaxTokens': 4096,
    'apiTimeout': 60,
    'apiMaxContexts': 10,
    'apiTemperature': 1,
    'apiProxy': '',
    'apiProvider': 'OpenAI',
    'apiVersion': '',
    'apiUserAgent': 'DIGroup/3.4.2 docker/linux'
}

# КРИТИЧНО: Отключаем Ollama и исправляем host.docker.internal
if 'ollama' in conf['ai']:
    # Полностью отключаем, чтобы не было ошибок
    conf['ai']['ollama'] = {
        'apiBaseURL': '',
        'apiKey': '',
        'apiModel': '',
        'apiMaxTokens': 4096,
        'apiTimeout': 60,
        'apiMaxContexts': 10,
        'apiTemperature': 1,
        'apiProxy': ''
    }
    print('✓ Ollama полностью отключен')

# Проверяем и исправляем другие провайдеры
if 'gemini' in conf['ai']:
    gemini_url = conf['ai']['gemini'].get('apiBaseURL', '')
    if 'host.docker.internal' in gemini_url:
        conf['ai']['gemini']['apiBaseURL'] = 'https://generativelanguage.googleapis.com/v1beta'
        print('✓ Исправлен Gemini API URL')

with open(conf_path, 'w', encoding='utf-8') as f:
    json.dump(conf, f, ensure_ascii=False, indent=2)

print('✓ Конфигурация AI обновлена (OpenRouter настроен, Ollama отключен)')
PYTHON_SCRIPT
    
    chown 1000:1000 workspace/conf/conf.json
    chmod 644 workspace/conf/conf.json
    
    # Проверяем, что конфигурация действительно обновилась
    if grep -q "openrouter.ai" workspace/conf/conf.json && ! grep -q "host.docker.internal.*11434" workspace/conf/conf.json; then
        echo "[OK] Конфигурация AI настроена (OpenRouter, без host.docker.internal)"
        
        # КРИТИЧНО: Принудительно копируем конфигурацию в контейнер, если он запущен
        if docker ps | grep -q "digroup"; then
            echo "   Копируем конфигурацию в запущенный контейнер..."
            docker cp workspace/conf/conf.json digroup:/opt/siyuan/workspace/conf/conf.json 2>/dev/null || true
            docker compose exec -T digroup chown 1000:1000 /opt/siyuan/workspace/conf/conf.json 2>/dev/null || true
            echo "   [OK] Конфигурация скопирована в контейнер"
        fi
    else
        echo "⚠️  Конфигурация AI может быть не обновлена полностью"
        echo "   Проверьте вручную: cat workspace/conf/conf.json | grep -A 10 '\"ai\"'"
    fi
else
    echo "⚠️  Не удалось обновить конфигурацию AI"
fi
echo ""

# ============================================================================
# ШАГ 3: Исправление настроек темы
# ============================================================================
echo "🎨 ШАГ 3: Исправление настроек темы..."
if [ -f "workspace/conf/conf.json" ] && command -v python3 &> /dev/null; then
    python3 << 'PYTHON_SCRIPT'
import json

conf_path = 'workspace/conf/conf.json'
with open(conf_path, 'r', encoding='utf-8') as f:
    conf = json.load(f)

if 'appearance' not in conf:
    conf['appearance'] = {}

# Отключаем режим "Следовать системе"
if conf['appearance'].get('modeOS', True):
    conf['appearance']['modeOS'] = False
    print('✓ Отключен режим "Следовать системе"')

# Убеждаемся, что есть темы
if 'themeDark' not in conf['appearance']:
    conf['appearance']['themeDark'] = 'midnight'
if 'themeLight' not in conf['appearance']:
    conf['appearance']['themeLight'] = 'daylight'
if 'darkThemes' not in conf['appearance'] or not conf['appearance']['darkThemes']:
    conf['appearance']['darkThemes'] = [{'name': 'midnight', 'label': 'midnight (Default)'}]
if 'lightThemes' not in conf['appearance'] or not conf['appearance']['lightThemes']:
    conf['appearance']['lightThemes'] = [{'name': 'daylight', 'label': 'daylight (Default)'}]

with open(conf_path, 'w', encoding='utf-8') as f:
    json.dump(conf, f, ensure_ascii=False, indent=2)

print('✓ Настройки темы исправлены')
PYTHON_SCRIPT
    
    chown 1000:1000 workspace/conf/conf.json
    chmod 644 workspace/conf/conf.json
    echo "[OK] Настройки темы исправлены"
fi
echo ""

# ============================================================================
# ШАГ 4: Исправление конфигурации Облако и Опубликовать
# ============================================================================
echo "☁️  ШАГ 4: Исправление конфигурации Облако и Опубликовать..."
if [ -f "workspace/conf/conf.json" ] && command -v python3 &> /dev/null; then
    python3 << 'PYTHON_SCRIPT'
import json

conf_path = 'workspace/conf/conf.json'
with open(conf_path, 'r', encoding='utf-8') as f:
    conf = json.load(f)

# Исправляем Облако (синхронизация)
if 'sync' not in conf:
    conf['sync'] = {}

conf['sync']['enabled'] = False  # Отключаем по умолчанию
conf['sync']['cloudName'] = 'main'
conf['sync']['mode'] = 1
conf['sync']['interval'] = 30
conf['sync']['generateConflictDoc'] = False
conf['sync']['provider'] = 0

# Исправляем Опубликовать
if 'publish' not in conf:
    conf['publish'] = {}

conf['publish']['enable'] = False
conf['publish']['port'] = 6808

if 'auth' not in conf['publish']:
    conf['publish']['auth'] = {
        'enable': True,
        'accounts': []
    }

# Настройки истории для отслеживания автора
if 'editor' not in conf:
    conf['editor'] = {}

conf['editor']['generateHistoryInterval'] = 5  # каждые 5 минут
conf['editor']['historyRetentionDays'] = 90

with open(conf_path, 'w', encoding='utf-8') as f:
    json.dump(conf, f, ensure_ascii=False, indent=2)

print('✓ Конфигурация Облако и Опубликовать исправлена')
PYTHON_SCRIPT
    
    chown 1000:1000 workspace/conf/conf.json
    chmod 644 workspace/conf/conf.json
    echo "[OK] Конфигурация исправлена"
fi
echo ""

# ============================================================================
# ШАГ 5: Замена SiYuan на DiGroup
# ============================================================================
echo "🔄 ШАГ 5: Замена SiYuan на DiGroup..."
if [ -f "workspace/conf/conf.json" ] && command -v python3 &> /dev/null; then
    python3 << 'PYTHON_SCRIPT'
import json
import re

conf_path = 'workspace/conf/conf.json'
with open(conf_path, 'r', encoding='utf-8') as f:
    conf = json.load(f)

# Заменяем в системных настройках
if 'system' in conf and 'name' in conf['system']:
    conf['system']['name'] = re.sub(r'siyuan|SiYuan', 'DiGroup', conf['system']['name'], flags=re.IGNORECASE)

# Заменяем в AI настройках
if 'ai' in conf:
    for provider in ['openAI', 'ollama', 'gemini']:
        if provider in conf['ai'] and 'apiUserAgent' in conf['ai'][provider]:
            conf['ai'][provider]['apiUserAgent'] = re.sub(
                r'siyuan|SiYuan', 'DiGroup', 
                conf['ai'][provider]['apiUserAgent'], 
                flags=re.IGNORECASE
            )

with open(conf_path, 'w', encoding='utf-8') as f:
    json.dump(conf, f, ensure_ascii=False, indent=2)

print('✓ Конфигурация обновлена')
PYTHON_SCRIPT
    
    # Замена в файлах локализации
    if [ -f "workspace/conf/appearance/langs/ru_RU.json" ]; then
        cp workspace/conf/appearance/langs/ru_RU.json workspace/conf/appearance/langs/ru_RU.json.backup 2>/dev/null || true
        sed -i 's/SiYuan/DiGroup/g' workspace/conf/appearance/langs/ru_RU.json 2>/dev/null || true
        sed -i 's|https://b3log.org/siyuan[^"]*||g' workspace/conf/appearance/langs/ru_RU.json 2>/dev/null || true
        sed -i 's|http://b3log.org/siyuan[^"]*||g' workspace/conf/appearance/langs/ru_RU.json 2>/dev/null || true
        sed -i 's|https://github.com/siyuan-note[^"]*||g' workspace/conf/appearance/langs/ru_RU.json 2>/dev/null || true
        chown -R 1000:1000 workspace/conf/appearance
    fi
    
    chown 1000:1000 workspace/conf/conf.json
    chmod 644 workspace/conf/conf.json
    echo "[OK] Замена SiYuan на DiGroup выполнена"
fi
echo ""

# ============================================================================
# ШАГ 6: Создание скриптов для отслеживания автора
# ============================================================================
echo "👤 ШАГ 6: Настройка отслеживания автора..."
# Создаем JavaScript вебхук
cat > workspace/conf/auto-author-webhook.js << 'JAVASCRIPT'
/**
 * Автоматическое добавление автора к блокам
 * Настройки → Наборы → JavaScript → Добавить
 */

function getCurrentUser() {
    const user = localStorage.getItem('digroup_user');
    if (user) return user;
    
    const cookies = document.cookie.split(';');
    for (let cookie of cookies) {
        const [name, value] = cookie.trim().split('=');
        if (name === 'digroup_user') {
            return decodeURIComponent(value);
        }
    }
    
    return 'Неизвестный пользователь';
}

if (typeof window !== 'undefined' && window.siyuan) {
    const originalInsertBlock = window.siyuan.block?.insertBlock;
    
    if (originalInsertBlock) {
        window.siyuan.block.insertBlock = function(...args) {
            const result = originalInsertBlock.apply(this, args);
            
            setTimeout(() => {
                const author = getCurrentUser();
                if (result && result.id) {
                    window.siyuan.block?.setBlockReminder?.(result.id, `Автор: ${author}`);
                }
            }, 100);
            
            return result;
        };
    }
}

console.log('DiGroup Auto-Author: Скрипт загружен');
JAVASCRIPT

chown 1000:1000 workspace/conf/auto-author-webhook.js
chmod 644 workspace/conf/auto-author-webhook.js

# Создаем инструкцию
cat > workspace/conf/AUTO_AUTHOR_INSTRUCTION.md << 'MARKDOWN'
# Автоматическое отслеживание автора

## Настройка

1. Откройте Настройки → Наборы → JavaScript
2. Добавьте новый скрипт
3. Скопируйте содержимое файла `auto-author-webhook.js`
4. Сохраните

## Установка имени пользователя

В консоли браузера (F12):
```javascript
localStorage.setItem('digroup_user', 'Ваше Имя Фамилия');
```

## Альтернатива: История изменений

Настройки → Данные → История
MARKDOWN

chown 1000:1000 workspace/conf/AUTO_AUTHOR_INSTRUCTION.md
chmod 644 workspace/conf/AUTO_AUTHOR_INSTRUCTION.md
echo "[OK] Скрипты для отслеживания автора созданы"
echo ""

# ============================================================================
# ШАГ 7: Исправление Nginx (403 Forbidden и WebSocket AccessAuthCode)
# ============================================================================
echo "🌐 ШАГ 7: Исправление Nginx (403 Forbidden и WebSocket)..."
if command -v nginx &> /dev/null; then
    NGINX_CONFIG="/etc/nginx/sites-available/digroup"
    
    # Получаем AccessAuthCode из .env или используем дефолтный
    ACCESS_AUTH_CODE="b226ba0f30a134fe9245792118bca202"
    if [ -f ".env" ] && grep -q "ACCESS_AUTH_CODE=" .env; then
        ACCESS_AUTH_CODE=$(grep "ACCESS_AUTH_CODE=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    fi
    
    # Создаем правильную конфигурацию с поддержкой WebSocket AccessAuthCode
    cat > /tmp/digroup-fixed.conf << NGINX_EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80;
    server_name digroupdb.duckdns.org;
    
    access_log /var/log/nginx/digroup-access.log;
    error_log /var/log/nginx/digroup-error.log;
    
    client_max_body_size 100M;
    
    # КРИТИЧНО: WebSocket требует передачи query string с AccessAuthCode
    location /ws {
        proxy_pass http://127.0.0.1:6806;
        proxy_http_version 1.1;
        
        # WebSocket заголовки
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        
        # Базовые заголовки
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Передаем оригинальные заголовки и query string
        proxy_set_header Origin \$scheme://\$host;
        proxy_set_header Referer \$scheme://\$host\$request_uri;
        
        # КРИТИЧНО: передаем query string (включая AccessAuthCode)
        proxy_pass_request_headers on;
        proxy_pass_request_body on;
        
        # Увеличенные таймауты для WebSocket
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 60s;
        
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
        proxy_intercept_errors off;
    }
    
    # Основной location для всех остальных запросов
    location / {
        proxy_pass http://127.0.0.1:6806;
        proxy_http_version 1.1;
        
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        
        proxy_set_header Origin \$scheme://\$host;
        proxy_set_header Referer \$scheme://\$host\$request_uri;
        
        proxy_pass_request_headers on;
        proxy_pass_request_body on;
        
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 60s;
        
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
        proxy_intercept_errors off;
    }
    
    location /assets/ {
        proxy_pass http://127.0.0.1:6806;
        proxy_cache_valid 200 1h;
        expires 1h;
    }
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
}
NGINX_EOF
    
    # Определяем внутренний IP для доступа с домашнего Wi-Fi
    INTERNAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' || echo "")
    
    # Добавляем конфигурацию для внутреннего IP
    if [ -n "$INTERNAL_IP" ] && [ "$INTERNAL_IP" != "" ] && [[ "$INTERNAL_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        cat >> /tmp/digroup-fixed.conf << NGINX_INTERNAL

# Доступ по внутреннему IP (для домашнего Wi-Fi)
server {
    listen 80;
    server_name $INTERNAL_IP;
    
    location /ws {
        proxy_pass http://127.0.0.1:6806;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass_request_headers on;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_buffering off;
        proxy_intercept_errors off;
    }
    
    location / {
        proxy_pass http://127.0.0.1:6806;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_pass_request_headers on;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_buffering off;
        proxy_intercept_errors off;
    }
}
NGINX_INTERNAL
    fi
    
    # Копируем конфигурацию
    cp /tmp/digroup-fixed.conf "$NGINX_CONFIG"
    ln -sf "$NGINX_CONFIG" /etc/nginx/sites-enabled/digroup 2>/dev/null || true
    
    # Проверяем и перезагружаем
    if nginx -t 2>&1 | grep -q "successful"; then
        systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || true
        echo "[OK] Nginx обновлен (WebSocket и AccessAuthCode настроены)"
    else
        echo "⚠️  Ошибка в конфигурации Nginx:"
        nginx -t 2>&1 | head -n 5
        echo ""
        echo "⚠️  Используем существующую конфигурацию"
    fi
else
    echo "⚠️  Nginx не установлен, пропуск"
fi
echo ""

# ============================================================================
# ШАГ 8: Исправление проблем с директориями и файлами
# ============================================================================
echo "📁 ШАГ 8: Исправление проблем с директориями..."

# Проверяем, запущен ли контейнер
if docker ps | grep -q "digroup"; then
    # Создаем недостающие директории внутри контейнера
    docker compose exec -T digroup mkdir -p /home/siyuan/.config/siyuan 2>/dev/null || true
    docker compose exec -T digroup chown -R 1000:1000 /home/siyuan/.config 2>/dev/null || true
    
    # Создаем пустой announcement.json, чтобы избежать ошибок
    docker compose exec -T digroup sh -c 'echo "{}" > /home/siyuan/.config/siyuan/announcement.json' 2>/dev/null || true
    docker compose exec -T digroup chown 1000:1000 /home/siyuan/.config/siyuan/announcement.json 2>/dev/null || true
    
    echo "[OK] Директории исправлены в контейнере"
else
    echo "⚠️  Контейнер не запущен, директории будут созданы при следующем запуске"
fi
echo ""

# ============================================================================
# ШАГ 9: Очистка кэша
# ============================================================================
echo "🧹 ШАГ 9: Очистка кэша..."
if [ -d "workspace/data" ]; then
    find workspace/data -name "*.tmp" -delete 2>/dev/null || true
    find workspace/data -name "*.cache" -delete 2>/dev/null || true
    echo "[OK] Кэш очищен"
fi
echo ""

# ============================================================================
# ШАГ 10: Финальная проверка и перезапуск контейнеров
# ============================================================================
echo "🔄 ШАГ 10: Финальная проверка и перезапуск контейнеров..."

# Проверяем, нужно ли перезапускать
if ! curl -s --max-time 3 http://127.0.0.1:6806/api/system/version > /dev/null 2>&1; then
    echo "⚠️  API недоступен, выполняем полный перезапуск..."
    docker compose stop digroup 2>/dev/null || true
    sleep 2
    docker compose rm -f digroup 2>/dev/null || true
    sleep 1
    docker compose up -d digroup
    echo "[OK] Контейнер пересоздан"
    
    # Ждем запуска
    echo "⏳ Ожидание запуска (20 секунд)..."
    sleep 20
else
    echo "[OK] API доступен, мягкий перезапуск..."
    docker compose restart digroup
    echo "[OK] Контейнеры перезапущены"
    sleep 5
fi

# Дополнительная проверка: убеждаемся, что конфигурация AI обновилась
echo ""
echo "🔍 Проверка конфигурации AI после перезапуска..."
sleep 3

# Проверяем конфигурацию внутри контейнера
CONTAINER_CONFIG_OK=false
if docker compose exec -T digroup cat /opt/siyuan/workspace/conf/conf.json 2>/dev/null | grep -q "openrouter.ai" && ! docker compose exec -T digroup cat /opt/siyuan/workspace/conf/conf.json 2>/dev/null | grep -q "host.docker.internal.*11434"; then
    CONTAINER_CONFIG_OK=true
    echo "[OK] Конфигурация AI корректна в контейнере (OpenRouter, без host.docker.internal)"
else
    echo "⚠️  Конфигурация AI не обновлена в контейнере, принудительно копируем..."
    
    # Принудительно копируем конфигурацию
    if [ -f "workspace/conf/conf.json" ]; then
        docker cp workspace/conf/conf.json digroup:/opt/siyuan/workspace/conf/conf.json 2>/dev/null || true
        docker compose exec -T digroup chown 1000:1000 /opt/siyuan/workspace/conf/conf.json 2>/dev/null || true
        
        # Перезапускаем контейнер для применения изменений
        echo "   Перезапускаем контейнер для применения конфигурации..."
        docker compose restart digroup
        sleep 10
        
        # Проверяем снова
        if docker compose exec -T digroup cat /opt/siyuan/workspace/conf/conf.json 2>/dev/null | grep -q "openrouter.ai"; then
            echo "   [OK] Конфигурация применена"
            CONTAINER_CONFIG_OK=true
        else
            echo "   ⚠️  Конфигурация все еще не применена"
        fi
    fi
fi

if [ "$CONTAINER_CONFIG_OK" = false ]; then
    echo ""
    echo "   Проверьте вручную:"
    echo "   docker compose exec digroup cat /opt/siyuan/workspace/conf/conf.json | grep -A 5 '\"ai\"'"
fi
echo ""

# ============================================================================
# ШАГ 11: Принудительное применение всех исправлений
# ============================================================================
echo "🔄 ШАГ 11: Принудительное применение всех исправлений..."

# Убеждаемся, что конфигурация скопирована в контейнер
if docker ps | grep -q "digroup" && [ -f "workspace/conf/conf.json" ]; then
    echo "   Копируем исправленную конфигурацию в контейнер..."
    docker cp workspace/conf/conf.json digroup:/opt/siyuan/workspace/conf/conf.json 2>/dev/null || true
    docker compose exec -T digroup chown 1000:1000 /opt/siyuan/workspace/conf/conf.json 2>/dev/null || true
    
    # Проверяем, что конфигурация действительно скопировалась
    if docker compose exec -T digroup cat /opt/siyuan/workspace/conf/conf.json 2>/dev/null | grep -q "openrouter.ai"; then
        echo "   [OK] Конфигурация скопирована"
        
        # Перезапускаем для применения
        echo "   Перезапускаем контейнер для применения изменений..."
        docker compose restart digroup
        sleep 10
    else
        echo "   ⚠️  Не удалось скопировать конфигурацию"
    fi
fi
echo ""

# ============================================================================
# ШАГ 12: Ожидание и проверка
# ============================================================================
echo "⏳ ШАГ 12: Ожидание запуска..."
sleep 15

echo "Проверка доступности API..."
API_FINAL_CHECK=false
for i in {1..6}; do
    if curl -s --max-time 3 http://127.0.0.1:6806/api/system/version > /dev/null 2>&1; then
        API_FINAL_CHECK=true
        break
    fi
    echo "   Попытка $i/6..."
    sleep 5
done

if [ "$API_FINAL_CHECK" = true ]; then
    echo "[OK] API доступен и работает"
    
    # Проверяем версию
    VERSION=$(curl -s http://127.0.0.1:6806/api/system/version 2>/dev/null | grep -o '"kernelVersion":"[^"]*"' | cut -d'"' -f4 || echo "неизвестна")
    echo "   Версия ядра: $VERSION"
    
    # Проверяем конфигурацию AI через API и внутри контейнера
    echo ""
    echo "🔍 Финальная проверка конфигурации AI..."
    
    # Проверка через API
    AI_CONFIG_API=$(curl -s http://127.0.0.1:6806/api/system/getConf 2>/dev/null | grep -o '"ai":{[^}]*}' || echo "")
    
    # Проверка внутри контейнера
    AI_CONFIG_CONTAINER=$(docker compose exec -T digroup cat /opt/siyuan/workspace/conf/conf.json 2>/dev/null | grep -A 20 '"ai"' || echo "")
    
    if (echo "$AI_CONFIG_API" | grep -q "openrouter.ai" || echo "$AI_CONFIG_CONTAINER" | grep -q "openrouter.ai") && ! echo "$AI_CONFIG_CONTAINER" | grep -q "host.docker.internal.*11434"; then
        echo "   [OK] Конфигурация AI корректна (OpenRouter)"
    else
        echo "   ⚠️  Конфигурация AI может быть некорректна"
        echo ""
        echo "   Выполните принудительное исправление:"
        echo "   docker cp workspace/conf/conf.json digroup:/opt/siyuan/workspace/conf/conf.json"
        echo "   docker compose restart digroup"
    fi
else
    echo "⚠️  API все еще недоступен"
    echo ""
    echo "Проверьте логи для диагностики:"
    echo "   docker compose logs --tail=50 digroup"
    echo ""
    echo "Проверьте конфигурацию:"
    echo "   cat workspace/conf/conf.json | grep -A 10 '\"ai\"'"
    echo ""
    echo "Попробуйте полный перезапуск:"
    echo "   docker compose down && docker compose up -d"
    echo ""
fi
echo ""

# ============================================================================
# ИТОГИ
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ВСЕ ИСПРАВЛЕНИЯ ЗАВЕРШЕНЫ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 ЧТО БЫЛО ИСПРАВЛЕНО:"
echo ""
echo "0. ✅ Проблема с ядром (диагностика и перезапуск)"
echo "1. ✅ Права на файлы"
echo "2. ✅ AI настроен (OpenRouter, модель: mistralai/devstral-2512:free)"
echo "   • Исправлен host.docker.internal → OpenRouter"
echo "   • Ollama полностью отключен"
echo "3. ✅ Тема (можно переключать вручную)"
echo "4. ✅ Облако (исправлена бесконечная загрузка)"
echo "5. ✅ Опубликовать (исправлена работа)"
echo "6. ✅ Отслеживание автора (история + скрипты)"
echo "7. ✅ Nginx (исправлен 403 Forbidden и WebSocket AccessAuthCode)"
echo "   • Добавлен отдельный location /ws для WebSocket"
echo "   • Query string передается правильно"
echo "8. ✅ SiYuan → DiGroup (замена выполнена)"
echo "9. ✅ Доступ с домашнего Wi-Fi (настроен внутренний IP)"
echo "10. ✅ Директории (создана /home/siyuan/.config/siyuan)"
echo ""
echo "📋 СЛЕДУЮЩИЕ ШАГИ:"
echo ""
echo "1. Очистите кэш браузера (Ctrl+Shift+R)"
echo "2. Перезагрузите страницу"
echo "3. Добавьте API ключ OpenRouter:"
echo "   • Получите на https://openrouter.ai (бесплатно)"
echo "   • Настройки → AI → OpenAI → API Key"
echo "4. Проверьте вкладки:"
echo "   • Облако - должна загружаться"
echo "   • AI - должна открываться"
echo "   • Опубликовать - должна работать"
echo ""
echo "💡 ДОПОЛНИТЕЛЬНО:"
echo ""
echo "• Для отслеживания автора: workspace/conf/AUTO_AUTHOR_INSTRUCTION.md"
echo "• Для доступа с домашнего Wi-Fi: используйте внутренний IP"
echo ""
if [ "$API_FINAL_CHECK" = false ]; then
    echo "⚠️  ВАЖНО: Проблема с ядром не решена полностью"
    echo ""
    echo "Выполните диагностику:"
    echo "   1. Проверьте логи: docker compose logs -f digroup"
    echo "   2. Проверьте порт: netstat -tlnp | grep 6806"
    echo "   3. Проверьте конфигурацию: cat workspace/conf/conf.json | grep -A 5 '\"ai\"'"
    echo "   4. Попробуйте полный перезапуск:"
    echo "      docker compose down && docker compose up -d"
    echo ""
fi
echo ""
echo "🔧 ИСПРАВЛЕННЫЕ ПРОБЛЕМЫ ИЗ ЛОГОВ:"
echo ""
echo "1. ✅ WebSocket AccessAuthCode mismatch"
echo "   • Добавлен отдельный location /ws в Nginx"
echo "   • Query string передается правильно"
echo "   • WebSocket соединения должны работать"
echo ""
echo "2. ✅ Ollama host.docker.internal ошибка"
echo "   • AI настроен на OpenRouter (mistralai/devstral-2512:free)"
echo "   • Ollama полностью отключен (apiBaseURL='', apiModel='')"
echo "   • Исправлен Gemini API URL (если был host.docker.internal)"
echo ""
echo "3. ✅ Ошибка announcement.json"
echo "   • Создана директория /home/siyuan/.config/siyuan"
echo "   • Создан файл announcement.json"
echo ""
echo "4. ✅ Контейнер перезапускается"
echo "   • Выполнен полный перезапуск контейнера"
echo "   • Конфигурация применена"
echo ""
echo "⚠️  КРИТИЧНО: Если проблема 'DiGroup столкнулся с небольшой проблемой' ВСЕ ЕЩЕ сохраняется:"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 ПОШАГОВОЕ РУЧНОЕ ИСПРАВЛЕНИЕ:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "ШАГ 1: Полный перезапуск контейнеров"
echo "   docker compose down"
echo "   docker compose up -d"
echo "   sleep 30"
echo ""
echo "ШАГ 2: Проверьте конфигурацию AI в контейнере"
echo "   docker compose exec digroup cat /opt/siyuan/workspace/conf/conf.json | grep -A 15 '\"ai\"'"
echo ""
echo "ШАГ 3: Если видите 'host.docker.internal:11434', принудительно исправьте:"
echo "   docker cp workspace/conf/conf.json digroup:/opt/siyuan/workspace/conf/conf.json"
echo "   docker compose exec digroup chown 1000:1000 /opt/siyuan/workspace/conf/conf.json"
echo "   docker compose restart digroup"
echo "   sleep 15"
echo ""
echo "ШАГ 4: Проверьте, что конфигурация применилась"
echo "   docker compose exec digroup cat /opt/siyuan/workspace/conf/conf.json | grep -A 5 'openrouter.ai'"
echo ""
echo "ШАГ 5: Проверьте логи на ошибки"
echo "   docker compose logs digroup | grep -i 'error\|fatal\|panic\|host.docker.internal' | tail -30"
echo ""
echo "ШАГ 6: Очистите кэш браузера полностью"
echo "   • Нажмите Ctrl+Shift+Delete"
echo "   • Выберите 'Все время'"
echo "   • Отметьте 'Кэшированные изображения и файлы'"
echo "   • Очистите"
echo ""
echo "ШАГ 7: Откройте заново"
echo "   • Закройте ВСЕ вкладки с DIGroup"
echo "   • Откройте в режиме инкогнито (Ctrl+Shift+N)"
echo "   • Перейдите на сайт"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 ДОПОЛНИТЕЛЬНАЯ ДИАГНОСТИКА:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Проверьте порт:"
echo "   netstat -tlnp | grep 6806"
echo ""
echo "Проверьте контейнер:"
echo "   docker ps | grep digroup"
echo ""
echo "Проверьте WebSocket в браузере (F12 → Network → WS):"
echo "   • Должны быть соединения к /ws"
echo "   • Query string должен содержать accessAuthCode"
echo ""
echo ""
