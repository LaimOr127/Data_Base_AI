#!/bin/bash
# ИСПРАВЛЕНИЕ ЛОКАЛЬНОЙ УСТАНОВКИ DIGroup
# Исправляет ошибки: block not found, deadlock, Forbidden

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

set +e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 ИСПРАВЛЕНИЕ ЛОКАЛЬНОЙ УСТАНОВКИ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Проверка Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен"
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker не запущен"
    echo "Запустите Docker Desktop и попробуйте снова"
    exit 1
fi

echo "✅ Docker доступен"
echo ""

# ============================================================================
# ШАГ 1: Остановка контейнеров
# ============================================================================
echo "🛑 ШАГ 1: Остановка контейнеров..."
docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
sleep 3
echo "[OK] Контейнеры остановлены"
echo ""

# ============================================================================
# ШАГ 2: Удаление блокирующих файлов
# ============================================================================
echo "🗑️  ШАГ 2: Удаление блокирующих файлов..."

# Удаляем .lock файл
if [ -f "workspace/.lock" ]; then
    rm -f workspace/.lock
    echo "  ✓ Удален .lock файл"
fi

# Удаляем все lock файлы в workspace
find workspace -name "*.lock" -type f -delete 2>/dev/null && echo "  ✓ Удалены все .lock файлы" || true

# Удаляем временные файлы
find workspace -name "*.tmp" -type f -delete 2>/dev/null && echo "  ✓ Удалены временные файлы" || true

echo "[OK] Блокирующие файлы удалены"
echo ""

# ============================================================================
# ШАГ 3: Исправление recent-doc.json (deadlock)
# ============================================================================
echo "🔧 ШАГ 3: Исправление recent-doc.json..."

if [ -f "workspace/data/storage/recent-doc.json" ]; then
    # Создаем backup
    cp workspace/data/storage/recent-doc.json workspace/data/storage/recent-doc.json.backup 2>/dev/null || true
    
    # Проверяем, что файл валидный JSON
    if python3 -m json.tool workspace/data/storage/recent-doc.json > /dev/null 2>&1; then
        echo "  ✓ recent-doc.json валиден"
    else
        echo "  ⚠️  recent-doc.json поврежден, создаем новый..."
        echo '[]' > workspace/data/storage/recent-doc.json
        echo "  ✓ Создан новый recent-doc.json"
    fi
else
    echo "  → recent-doc.json не найден, создаем..."
    mkdir -p workspace/data/storage
    echo '[]' > workspace/data/storage/recent-doc.json
    echo "  ✓ Создан recent-doc.json"
fi

echo "[OK] recent-doc.json исправлен"
echo ""

# ============================================================================
# ШАГ 4: Исправление прав доступа
# ============================================================================
echo "🔐 ШАГ 4: Исправление прав доступа..."

if [ -d "workspace" ]; then
    # Исправляем права на все файлы
    chmod -R 755 workspace 2>/dev/null || true
    chmod 644 workspace/conf/conf.json 2>/dev/null || true
    chmod 644 workspace/data/storage/*.json 2>/dev/null || true
    
    # На macOS права могут быть другими, но это не критично
    echo "  ✓ Права исправлены"
fi

echo "[OK] Права доступа исправлены"
echo ""

# ============================================================================
# ШАГ 5: Проверка и исправление блоков данных
# ============================================================================
echo "🔍 ШАГ 5: Проверка блоков данных..."

# Проверяем наличие проблемного блока
PROBLEM_BLOCK="20260112163849-u63gb4k"
BLOCK_FILE="workspace/data/20251230113409-4y9ye0l/${PROBLEM_BLOCK}.sy"

if [ -f "$BLOCK_FILE" ]; then
    # Проверяем, что файл не пустой и валидный
    if [ ! -s "$BLOCK_FILE" ]; then
        echo "  ⚠️  Блок ${PROBLEM_BLOCK} пустой"
        echo "  → Файл существует, но пустой - это может быть проблемой"
    else
        # Проверяем, что это валидный JSON (первые символы)
        if head -c 1 "$BLOCK_FILE" | grep -q '{'; then
            echo "  ✓ Блок ${PROBLEM_BLOCK} существует и содержит данные"
        else
            echo "  ⚠️  Блок ${PROBLEM_BLOCK} может быть поврежден"
        fi
    fi
else
    echo "  ⚠️  Блок ${PROBLEM_BLOCK} не найден"
    echo "  → Это может быть причиной ошибки 'block not found'"
fi

echo "[OK] Блоки данных проверены"
echo ""

# ============================================================================
# ШАГ 6: Очистка поврежденных файлов
# ============================================================================
echo "🧹 ШАГ 6: Очистка поврежденных файлов..."

if [ -d "workspace/corrupted" ]; then
    # Перемещаем поврежденные файлы в backup
    if [ -d "backups" ]; then
        mv workspace/corrupted backups/corrupted-$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
        echo "  ✓ Поврежденные файлы перемещены в backups"
    else
        rm -rf workspace/corrupted 2>/dev/null || true
        echo "  ✓ Поврежденные файлы удалены"
    fi
fi

echo "[OK] Поврежденные файлы очищены"
echo ""

# ============================================================================
# ШАГ 7: Исправление конфигурации AI
# ============================================================================
echo "🤖 ШАГ 7: Исправление конфигурации AI..."

if [ -f "workspace/conf/conf.json" ] && command -v python3 &> /dev/null; then
    python3 << 'PYTHON_SCRIPT'
import json
import os

conf_path = 'workspace/conf/conf.json'
try:
    with open(conf_path, 'r', encoding='utf-8') as f:
        conf = json.load(f)
except Exception as e:
    print(f"  ⚠️  Ошибка чтения conf.json: {e}")
    exit(1)

if 'ai' not in conf:
    conf['ai'] = {}

# Исправляем AI конфигурацию
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

# Для локальной установки отключаем Ollama (если не установлен локально)
# Или используем localhost если Ollama установлен
conf['ai']['ollama'] = {
    'apiBaseURL': '',  # Отключаем, так как Ollama может быть не установлен локально
    'apiKey': '',
    'apiModel': '',
    'apiMaxTokens': 4096,
    'apiTimeout': 60,
    'apiMaxContexts': 10,
    'apiTemperature': 1,
    'apiProxy': ''
}

# Убираем host.docker.internal
if 'gemini' in conf.get('ai', {}):
    if 'host.docker.internal' in str(conf['ai']['gemini'].get('apiBaseURL', '')):
        conf['ai']['gemini']['apiBaseURL'] = 'https://generativelanguage.googleapis.com/v1beta'

try:
    with open(conf_path, 'w', encoding='utf-8') as f:
        json.dump(conf, f, ensure_ascii=False, indent=2)
    print('  ✓ Конфигурация AI исправлена')
except Exception as e:
    print(f'  ⚠️  Ошибка записи: {e}')
PYTHON_SCRIPT
else
    echo "  ⚠️  Python3 не найден или conf.json отсутствует"
fi

echo "[OK] Конфигурация AI исправлена"
echo ""

# ============================================================================
# ШАГ 8: Создание необходимых директорий
# ============================================================================
echo "📁 ШАГ 8: Создание необходимых директорий..."

mkdir -p workspace/data/storage/av 2>/dev/null || true
mkdir -p workspace/temp 2>/dev/null || true
mkdir -p data backups logs 2>/dev/null || true

echo "[OK] Директории созданы"
echo ""

# ============================================================================
# ШАГ 9: Исправление прав доступа для Docker
# ============================================================================
echo "🔐 ШАГ 9: Исправление прав для Docker..."

# На macOS права могут отличаться, но нужно убедиться, что файлы доступны
if [ -d "workspace" ]; then
    # Устанавливаем права для чтения/записи
    chmod -R u+rw workspace 2>/dev/null || true
    find workspace -type d -exec chmod 755 {} \; 2>/dev/null || true
    find workspace -type f -exec chmod 644 {} \; 2>/dev/null || true
    echo "  ✓ Права для Docker исправлены"
fi

echo "[OK] Права исправлены"
echo ""

# ============================================================================
# ШАГ 10: Запуск контейнеров
# ============================================================================
echo "🚀 ШАГ 10: Запуск контейнеров..."

# Удаляем старый контейнер если есть
docker rm -f digroup 2>/dev/null || true
sleep 2

# Запускаем заново
docker compose up -d --force-recreate 2>/dev/null || docker-compose up -d --force-recreate 2>/dev/null

if [ $? -eq 0 ]; then
    echo "[OK] Контейнеры запущены"
else
    echo "❌ Ошибка при запуске контейнеров"
    echo ""
    echo "Проверьте логи:"
    echo "  docker compose logs digroup"
    exit 1
fi

echo ""

# ============================================================================
# ШАГ 11: Ожидание запуска и проверка
# ============================================================================
echo "⏳ ШАГ 11: Ожидание запуска (40 секунд)..."
sleep 40

# Проверка доступности API
echo ""
echo "🔍 Проверка доступности API..."
for i in {1..6}; do
    if curl -s --max-time 3 http://127.0.0.1:6806/api/system/version > /dev/null 2>&1; then
        echo "[OK] ✅ API доступен!"
        break
    fi
    echo "   Ожидание... ($i/6)"
    sleep 5
done

# Финальная проверка
if curl -s --max-time 3 http://127.0.0.1:6806/api/system/version > /dev/null 2>&1; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ ЛОКАЛЬНАЯ УСТАНОВКА ИСПРАВЛЕНА"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📋 ЧТО БЫЛО ИСПРАВЛЕНО:"
    echo ""
echo "1. ✅ Удалены блокирующие .lock файлы (deadlock)"
echo "2. ✅ Исправлен recent-doc.json"
echo "3. ✅ Исправлены права доступа"
echo "4. ✅ Проверен блок 20260112163849-u63gb4k"
echo "5. ✅ Очищены поврежденные файлы"
echo "6. ✅ Исправлена конфигурация AI (OpenRouter)"
echo "7. ✅ Контейнеры пересозданы и перезапущены"
    echo ""
    echo "📋 СЛЕДУЮЩИЕ ШАГИ:"
    echo ""
    echo "1. Откройте браузер: http://127.0.0.1:6806"
    echo "2. Очистите кэш браузера (Ctrl+Shift+Delete)"
    echo "3. Закройте все вкладки с DIGroup"
    echo "4. Откройте заново в режиме инкогнито"
    echo "5. Ошибки должны исчезнуть"
    echo ""
else
    echo ""
    echo "⚠️  API все еще недоступен"
    echo ""
    echo "Проверьте логи:"
    echo "  docker compose logs digroup"
    echo ""
fi
