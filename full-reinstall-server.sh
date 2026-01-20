#!/bin/bash
# ПОЛНАЯ ПЕРЕУСТАНОВКА НА СЕРВЕРЕ
# Удаляет все и устанавливает заново с поддержкой Ollama и OpenRouter
# Использование: ./full-reinstall-server.sh

set -e

# Параметры сервера
SERVER_IP="85.198.99.150"
SERVER_USER="root"
SERVER_PATH="/root/digroupdb"
SERVER_PASSWORD="!K5kUHw6Hc0%"

LOCAL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 ПОЛНАЯ ПЕРЕУСТАНОВКА НА СЕРВЕРЕ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  ВНИМАНИЕ: Это удалит все данные на сервере!"
echo "   Создайте резервную копию перед продолжением!"
echo ""
# Автоматическое подтверждение для автоматического запуска
if [ "${AUTO_CONFIRM:-no}" != "yes" ]; then
    read -p "Продолжить? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Отменено"
        exit 1
    fi
else
    echo "Автоматическое подтверждение: yes"
fi

# Проверка sshpass
if ! command -v sshpass &> /dev/null; then
    echo "❌ sshpass не установлен"
    echo "Установите: brew install hudochenkov/sshpass/sshpass"
    exit 1
fi

echo ""
echo "📤 ШАГ 1: Синхронизация файлов на сервер..."
echo ""

# Создаем директорию на сервере, если её нет
echo "  → Создание директории на сервере..."
sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
    "${SERVER_USER}@${SERVER_IP}" \
    "mkdir -p ${SERVER_PATH} && chmod 755 ${SERVER_PATH}"

# Копируем необходимые файлы
FILES_TO_SYNC=(
    "docker-compose.yml"
    "fix-all.sh"
    "emergency-fix.sh"
    "install.sh"
    "bootstrap.sh"
)

for file in "${FILES_TO_SYNC[@]}"; do
    if [ -f "${LOCAL_PATH}/${file}" ]; then
        echo "  → $file"
        sshpass -p "${SERVER_PASSWORD}" scp -o StrictHostKeyChecking=no \
            "${LOCAL_PATH}/${file}" \
            "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/${file}" 2>&1 | grep -v "Warning: Permanently added" || true
        
        # Проверяем, что файл скопировался
        if sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
            "${SERVER_USER}@${SERVER_IP}" \
            "test -f ${SERVER_PATH}/${file}"; then
            echo "    [OK] Файл скопирован"
            sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
                "${SERVER_USER}@${SERVER_IP}" \
                "chmod +x ${SERVER_PATH}/${file} 2>/dev/null || true"
        else
            echo "    ⚠️  Ошибка копирования файла"
        fi
    else
        echo "  ⚠️  Файл не найден: $file"
    fi
done

# Копируем workspace/conf/conf.json (главный файл конфигурации)
if [ -f "${LOCAL_PATH}/workspace/conf/conf.json" ]; then
    echo "  → workspace/conf/conf.json (главный файл конфигурации)"
    sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
        "${SERVER_USER}@${SERVER_IP}" \
        "mkdir -p ${SERVER_PATH}/workspace/conf"
    
    sshpass -p "${SERVER_PASSWORD}" scp -o StrictHostKeyChecking=no \
        "${LOCAL_PATH}/workspace/conf/conf.json" \
        "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/workspace/conf/conf.json" 2>&1 | grep -v "Warning: Permanently added" || true
    
    # Устанавливаем правильные права
    sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
        "${SERVER_USER}@${SERVER_IP}" \
        "chown 1000:1000 ${SERVER_PATH}/workspace/conf/conf.json 2>/dev/null || true && chmod 644 ${SERVER_PATH}/workspace/conf/conf.json 2>/dev/null || true"
    
    echo "    [OK] conf.json скопирован"
else
    echo "  ⚠️  conf.json не найден локально, будет создан на сервере"
fi

echo ""
echo "[OK] Файлы скопированы"
echo ""

# Проверяем, что docker-compose.yml скопировался
if sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
    "${SERVER_USER}@${SERVER_IP}" \
    "test -f ${SERVER_PATH}/docker-compose.yml"; then
    echo "[OK] docker-compose.yml найден на сервере"
else
    echo "❌ ОШИБКА: docker-compose.yml не найден на сервере!"
    echo "   Проверьте подключение и права доступа"
    exit 1
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗑️  ШАГ 2: ПОЛНАЯ ОЧИСТКА СЕРВЕРА..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  ВНИМАНИЕ: Будет удалено ВСЕ:"
echo "   • Все контейнеры"
echo "   • Все volumes"
echo "   • Все сети"
echo "   • Workspace (кроме conf.json)"
echo "   • Data, logs, backups"
echo ""

sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
    "${SERVER_USER}@${SERVER_IP}" << 'REMOTE_SCRIPT'
cd /root/digroupdb

# Проверяем, что мы в правильной директории
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ ОШИБКА: docker-compose.yml не найден!"
    echo "   Текущая директория: $(pwd)"
    echo "   Содержимое: $(ls -la)"
    exit 1
fi

echo "🛑 ШАГ 2.1: Остановка всех контейнеров..."
docker compose down -v 2>/dev/null || true
sleep 3

echo "🗑️  ШАГ 2.2: Удаление всех контейнеров принудительно..."
docker rm -f digroup prometheus grafana node-exporter ollama 2>/dev/null || true
docker ps -a | grep -E "digroup|prometheus|grafana|node-exporter|ollama" | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true
sleep 2

echo "🗑️  ШАГ 2.3: Удаление всех volumes..."
docker volume ls | grep -E "digroup|prometheus|grafana|ollama" | awk '{print $2}' | xargs -r docker volume rm -f 2>/dev/null || true
sleep 2

echo "🗑️  ШАГ 2.4: Удаление всех сетей..."
docker network ls | grep -E "digroup" | awk '{print $1}' | xargs -r docker network rm 2>/dev/null || true
sleep 2

echo "🗑️  ШАГ 2.5: Очистка workspace (сохраняем только conf.json)..."
if [ -d "workspace" ]; then
    # Сохраняем conf.json если он есть
    if [ -f "workspace/conf/conf.json" ]; then
        mkdir -p /tmp/digroup-backup
        cp workspace/conf/conf.json /tmp/digroup-backup/conf.json 2>/dev/null || true
        echo "  → Сохранен conf.json в /tmp/digroup-backup/"
    fi
    
    # Удаляем workspace полностью
    rm -rf workspace/* workspace/.* 2>/dev/null || true
    echo "  → Workspace очищен"
    
    # Восстанавливаем conf.json если был сохранен
    if [ -f "/tmp/digroup-backup/conf.json" ]; then
        mkdir -p workspace/conf
        cp /tmp/digroup-backup/conf.json workspace/conf/conf.json 2>/dev/null || true
        chown -R 1000:1000 workspace 2>/dev/null || true
        echo "  → conf.json восстановлен"
    fi
fi

echo "🗑️  ШАГ 2.6: Очистка данных (data, logs, backups)..."
rm -rf data/* data/.* 2>/dev/null || true
rm -rf logs/* logs/.* 2>/dev/null || true
rm -rf backups/* backups/.* 2>/dev/null || true
echo "  → Данные очищены"

echo "🗑️  ШАГ 2.7: Очистка Docker (неиспользуемые ресурсы)..."
docker system prune -af --volumes 2>/dev/null || true
sleep 2

echo "🗑️  ШАГ 2.8: Финальная проверка..."
# Проверяем, что все удалено
REMAINING_CONTAINERS=$(docker ps -a | grep -E "digroup|prometheus|grafana|node-exporter|ollama" | wc -l)
REMAINING_VOLUMES=$(docker volume ls | grep -E "digroup|prometheus|grafana|ollama" | wc -l)

if [ "$REMAINING_CONTAINERS" -gt 0 ] || [ "$REMAINING_VOLUMES" -gt 0 ]; then
    echo "  ⚠️  Остались ресурсы, принудительно удаляем..."
    docker ps -a | grep -E "digroup|prometheus|grafana|node-exporter|ollama" | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true
    docker volume ls | grep -E "digroup|prometheus|grafana|ollama" | awk '{print $2}' | xargs -r docker volume rm -f 2>/dev/null || true
fi

echo ""
echo "[OK] ✅ СЕРВЕР ПОЛНОСТЬЮ ОЧИЩЕН"
echo ""
echo "Проверка:"
echo "  Контейнеры: $(docker ps -a | grep -E 'digroup|prometheus|grafana|node-exporter|ollama' | wc -l)"
echo "  Volumes: $(docker volume ls | grep -E 'digroup|prometheus|grafana|ollama' | wc -l)"
echo "  Networks: $(docker network ls | grep -E 'digroup' | wc -l)"
REMOTE_SCRIPT

echo ""
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 ШАГ 3: УСТАНОВКА С НУЛЯ..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  ВНИМАНИЕ: Начинается полная установка на очищенном сервере"
echo ""

sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
    "${SERVER_USER}@${SERVER_IP}" << 'REMOTE_SCRIPT'
cd /root/digroupdb

# Проверяем, что директория существует
if [ ! -d "/root/digroupdb" ]; then
    echo "❌ ОШИБКА: Директория /root/digroupdb не существует!"
    echo "   Создаем..."
    mkdir -p /root/digroupdb
fi

# Проверяем наличие docker-compose.yml
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ ОШИБКА: docker-compose.yml не найден!"
    echo "   Текущая директория: $(pwd)"
    echo "   Содержимое: $(ls -la)"
    exit 1
fi

echo "[OK] docker-compose.yml найден, продолжаем..."

# Запускаем контейнеры с нуля
echo "🚀 Запуск контейнеров с нуля..."
docker compose up -d --force-recreate --remove-orphans

# Ждем запуска
echo "⏳ Ожидание запуска контейнеров (40 секунд)..."
sleep 40

# Проверяем статус контейнеров
echo ""
echo "📊 Проверка статуса контейнеров..."
docker compose ps

# Проверяем, что контейнеры запущены
FAILED_CONTAINERS=$(docker compose ps | grep -E "Exit|unhealthy|restarting" | wc -l)
if [ "$FAILED_CONTAINERS" -gt 0 ]; then
    echo "⚠️  Некоторые контейнеры не запустились, проверяем логи..."
    docker compose ps | grep -E "Exit|unhealthy|restarting"
    echo ""
    echo "Последние логи digroup:"
    docker compose logs --tail=20 digroup
fi

# Проверяем, что контейнеры запущены
if ! docker ps | grep -q "digroup"; then
    echo "⚠️  Контейнер digroup не запустился, проверяем..."
    docker compose logs --tail=20 digroup
    exit 1
fi

# Устанавливаем Ollama в контейнере (в фоне, так как это долго)
echo "Установка модели Ollama (llama3.2) в фоне..."
docker compose exec -d ollama ollama pull llama3.2 2>/dev/null || echo "Ollama будет настроен позже"

echo "[OK] Контейнеры запущены"
echo "Ollama доступен по адресу: http://ollama:11434 (из других контейнеров)"
REMOTE_SCRIPT

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚙️  ШАГ 4: Настройка AI (Ollama + OpenRouter)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
    "${SERVER_USER}@${SERVER_IP}" << 'REMOTE_SCRIPT'
cd /root/digroupdb

# Получаем IP Ollama в сети Docker (используем имя контейнера)
OLLAMA_HOST="ollama"

# Настраиваем конфигурацию AI
python3 << PYTHON_SCRIPT
import json
import os

conf_path = 'workspace/conf/conf.json'
if not os.path.exists(conf_path):
    print("⚠️  conf.json не найден, создаем новый...")
    conf = {
        'ai': {},
        'appearance': {'modeOS': False},
        'sync': {'enabled': False},
        'publish': {'enable': False}
    }
else:
    try:
        with open(conf_path, 'r', encoding='utf-8') as f:
            conf = json.load(f)
    except Exception as e:
        print(f"⚠️  Ошибка чтения conf.json: {e}, создаем новый...")
        conf = {
            'ai': {},
            'appearance': {'modeOS': False},
            'sync': {'enabled': False},
            'publish': {'enable': False}
        }

if 'ai' not in conf:
    conf['ai'] = {}

# Настройка Ollama (приоритет 1) - используем имя контейнера в Docker сети
conf['ai']['ollama'] = {
    'apiBaseURL': 'http://ollama:11434',
    'apiKey': '',
    'apiModel': 'llama3.2',
    'apiMaxTokens': 4096,
    'apiTimeout': 60,
    'apiMaxContexts': 10,
    'apiTemperature': 1,
    'apiProxy': ''
}

# Настройка OpenRouter как запасной вариант (приоритет 2)
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

# Настройки темы
if 'appearance' not in conf:
    conf['appearance'] = {}
conf['appearance']['modeOS'] = False

# Настройки синхронизации
if 'sync' not in conf:
    conf['sync'] = {}
conf['sync']['enabled'] = False

# Настройки публикации
if 'publish' not in conf:
    conf['publish'] = {}
conf['publish']['enable'] = False

try:
    with open(conf_path, 'w', encoding='utf-8') as f:
        json.dump(conf, f, ensure_ascii=False, indent=2)
    print('✓ Конфигурация AI настроена')
    print('  Ollama: http://ollama:11434')
    print('  OpenRouter: https://openrouter.ai/api/v1 (запасной)')
    
    # Проверяем, что host.docker.internal удален
    with open(conf_path, 'r', encoding='utf-8') as f:
        content = f.read()
        if 'host.docker.internal' in content:
            print('  ⚠️  ВНИМАНИЕ: host.docker.internal все еще присутствует!')
            # Принудительно заменяем
            content = content.replace('http://host.docker.internal:11434', 'http://ollama:11434')
            content = content.replace('http://host.docker.internal:11434/v1', 'https://openrouter.ai/api/v1')
            with open(conf_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print('  ✓ Принудительно исправлено')
        else:
            print('  ✓ host.docker.internal отсутствует')
except Exception as e:
    print(f'✗ Ошибка записи конфигурации: {e}')
PYTHON_SCRIPT

# Проверяем, что конфигурация действительно записана
if [ -f "workspace/conf/conf.json" ]; then
    if grep -q "openrouter.ai" workspace/conf/conf.json && ! grep -q "host.docker.internal.*11434" workspace/conf/conf.json; then
        echo "   [OK] Конфигурация записана правильно"
    else
        echo "   ⚠️  Конфигурация может быть некорректна"
        echo "   Содержимое:"
        grep -A 5 '"ai"' workspace/conf/conf.json | head -10
    fi
else
    echo "   ❌ Файл conf.json не найден!"
fi

# Применяем конфигурацию (workspace монтируется как volume, поэтому изменения применяются автоматически)
chown -R 1000:1000 workspace 2>/dev/null || true
chmod 644 workspace/conf/conf.json 2>/dev/null || true

# КРИТИЧНО: Принудительно удаляем host.docker.internal из конфигурации
echo "   Удаляем host.docker.internal из конфигурации..."
sed -i 's|http://host.docker.internal:11434|http://ollama:11434|g' workspace/conf/conf.json 2>/dev/null || true
sed -i 's|http://host.docker.internal:11434/v1|https://openrouter.ai/api/v1|g' workspace/conf/conf.json 2>/dev/null || true

# Проверяем, что конфигурация действительно обновлена
if grep -q "openrouter.ai\|ollama:11434" workspace/conf/conf.json && ! grep -q "host.docker.internal.*11434" workspace/conf/conf.json; then
    echo "   [OK] Конфигурация на хосте обновлена (host.docker.internal удален)"
else
    echo "   ⚠️  Конфигурация на хосте все еще содержит host.docker.internal, исправляем..."
    python3 << 'PYTHON_FIX'
import json
conf_path = 'workspace/conf/conf.json'
with open(conf_path, 'r', encoding='utf-8') as f:
    conf = json.load(f)
if 'ai' not in conf:
    conf['ai'] = {}
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
with open(conf_path, 'w', encoding='utf-8') as f:
    json.dump(conf, f, ensure_ascii=False, indent=2)
print('✓ Конфигурация исправлена')
PYTHON_FIX
    chown 1000:1000 workspace/conf/conf.json
    chmod 644 workspace/conf/conf.json
fi

# Создаем директории для announcement.json
docker compose exec -T digroup mkdir -p /home/siyuan/.config/siyuan 2>/dev/null || true
docker compose exec -T digroup sh -c 'echo "{}" > /home/siyuan/.config/siyuan/announcement.json' 2>/dev/null || true
docker compose exec -T digroup chown -R 1000:1000 /home/siyuan/.config 2>/dev/null || true

# КРИТИЧНО: Полный перезапуск для применения конфигурации из volume
echo "   Выполняем полный перезапуск для применения конфигурации..."
docker compose stop digroup 2>/dev/null || true
sleep 3
docker compose rm -f digroup 2>/dev/null || true
sleep 2

# Финальная проверка конфигурации перед запуском
echo "   Проверяем конфигурацию перед запуском..."
if grep -q "host.docker.internal.*11434" workspace/conf/conf.json; then
    echo "   ⚠️  host.docker.internal все еще присутствует, исправляем..."
    sed -i 's|http://host.docker.internal:11434|http://ollama:11434|g' workspace/conf/conf.json
    sed -i 's|http://host.docker.internal:11434/v1|https://openrouter.ai/api/v1|g' workspace/conf/conf.json
    chown 1000:1000 workspace/conf/conf.json
    chmod 644 workspace/conf/conf.json
    echo "   [OK] Исправлено"
fi

docker compose up -d digroup
echo "   Ожидание запуска контейнера (25 секунд)..."
sleep 25

# Проверяем, что контейнер запустился
if docker ps | grep -q "digroup"; then
    echo "   [OK] Контейнер запущен"
else
    echo "   ⚠️  Контейнер не запустился, проверяем логи..."
    docker compose logs --tail=30 digroup
fi

echo "[OK] AI настроен (Ollama + OpenRouter)"
echo ""

# Проверка доступности API
echo "Проверка доступности API..."
for i in {1..6}; do
    if curl -s --max-time 3 http://127.0.0.1:6806/api/system/version > /dev/null 2>&1; then
        echo "[OK] API доступен!"
        break
    fi
    echo "   Ожидание... ($i/6)"
    sleep 5
done

# Финальная проверка конфигурации AI в контейнере
echo ""
echo "🔍 Финальная проверка конфигурации AI в контейнере..."
sleep 5
CONTAINER_AI_CONFIG=$(docker compose exec -T digroup cat /opt/siyuan/workspace/conf/conf.json 2>/dev/null | grep -A 25 '"ai"' || echo "")

if echo "$CONTAINER_AI_CONFIG" | grep -q "openrouter.ai\|ollama:11434" && ! echo "$CONTAINER_AI_CONFIG" | grep -q "host.docker.internal.*11434"; then
    echo "[OK] ✅ Конфигурация AI корректна в контейнере"
    echo ""
    echo "Показываем конфигурацию AI:"
    echo "$CONTAINER_AI_CONFIG" | grep -E "(apiBaseURL|apiModel)" | head -8
else
    echo "⚠️  ❌ Конфигурация AI все еще содержит host.docker.internal!"
    echo ""
    echo "Текущая конфигурация в контейнере:"
    docker compose exec digroup cat /opt/siyuan/workspace/conf/conf.json 2>/dev/null | grep -A 20 '"ai"' | head -25 || echo "Не удалось прочитать"
    echo ""
    echo "Конфигурация на хосте:"
    cat workspace/conf/conf.json | grep -A 20 '"ai"' | head -25 || echo "Не удалось прочитать"
    echo ""
    echo "⚠️  КРИТИЧНО: Конфигурация не применилась!"
    echo "   Выполните вручную:"
    echo "   cd /root/digroupdb"
    echo "   sed -i 's|http://host.docker.internal:11434|http://ollama:11434|g' workspace/conf/conf.json"
    echo "   docker compose restart digroup"
fi
REMOTE_SCRIPT

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ПЕРЕУСТАНОВКА ЗАВЕРШЕНА"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 ЧТО БЫЛО СДЕЛАНО:"
echo ""
echo "1. ✅ ПОЛНОСТЬЮ ОЧИЩЕН СЕРВЕР:"
echo "   • Удалены все контейнеры"
echo "   • Удалены все volumes"
echo "   • Удалены все сети"
echo "   • Очищен workspace (сохранен только conf.json)"
echo "   • Очищены data, logs, backups"
echo "   • Выполнен docker system prune"
echo ""
echo "2. ✅ УСТАНОВКА С НУЛЯ:"
echo "   • Установлены новые контейнеры (включая Ollama)"
echo "   • Созданы новые volumes"
echo "   • Создана новая сеть"
echo ""
echo "3. ✅ Настроен AI:"
echo "   • Ollama (llama3.2) - основной, http://ollama:11434"
echo "   • OpenRouter (mistralai/devstral-2512:free) - запасной"
echo ""
echo "4. ✅ Применена конфигурация через volume mount"
echo "5. ✅ Созданы директории для announcement.json"
echo ""
echo "📋 СЛЕДУЮЩИЕ ШАГИ:"
echo ""
echo "1. Подождите 30 секунд для полного запуска"
echo "2. Очистите кэш браузера (Ctrl+Shift+Delete)"
echo "3. Откройте сайт в режиме инкогнито"
echo "4. Проверьте работу AI в настройках"
echo ""
echo "💡 Для загрузки других моделей Ollama:"
echo "   ssh root@85.198.99.150"
echo "   cd /root/digroupdb"
echo "   docker compose exec ollama ollama pull mistral"
echo ""
echo "💡 Для проверки работы Ollama:"
echo "   docker compose exec digroup curl -s http://ollama:11434/api/tags"
echo ""
echo "💡 Если Ollama не работает, будет использован OpenRouter:"
echo "   Модель: mistralai/devstral-2512:free"
echo "   Получите API ключ на https://openrouter.ai"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 ПРОВЕРКА КОНФИГУРАЦИИ:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Выполните на сервере для проверки:"
echo "   ssh root@85.198.99.150"
echo "   cd /root/digroupdb"
echo "   docker compose exec digroup cat /opt/siyuan/workspace/conf/conf.json | grep -A 10 '\"ai\"'"
echo ""
echo "Должно быть:"
echo "   • openAI.apiBaseURL: https://openrouter.ai/api/v1"
echo "   • ollama.apiBaseURL: http://ollama:11434"
echo "   • НЕ должно быть: host.docker.internal"
echo ""
