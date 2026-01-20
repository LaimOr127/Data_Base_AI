#!/bin/bash
# ЭКСТРЕННОЕ ИСПРАВЛЕНИЕ ПРОБЛЕМЫ "DiGroup столкнулся с небольшой проблемой"
# Использование: ./emergency-fix.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

set +e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚨 ЭКСТРЕННОЕ ИСПРАВЛЕНИЕ ПРОБЛЕМЫ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "❌ Запустите от root: sudo ./emergency-fix.sh"
    exit 1
fi

# ============================================================================
# ШАГ 1: Полная остановка и очистка
# ============================================================================
echo "🛑 ШАГ 1: Полная остановка контейнеров..."
docker compose down 2>/dev/null || true
sleep 3
echo "[OK] Контейнеры остановлены"
echo ""

# ============================================================================
# ШАГ 2: Исправление конфигурации AI (критично!)
# ============================================================================
echo "🔧 ШАГ 2: Исправление конфигурации AI..."
if [ -f "workspace/conf/conf.json" ] && command -v python3 &> /dev/null; then
    python3 << 'PYTHON_SCRIPT'
import json
import re

conf_path = 'workspace/conf/conf.json'
try:
    with open(conf_path, 'r', encoding='utf-8') as f:
        conf = json.load(f)
    
    if 'ai' not in conf:
        conf['ai'] = {}
    
    # КРИТИЧНО: Полностью настраиваем OpenRouter
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
    
    # КРИТИЧНО: Полностью отключаем Ollama
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
    
    # Исправляем Gemini, если есть
    if 'gemini' in conf.get('ai', {}):
        if 'host.docker.internal' in str(conf['ai']['gemini'].get('apiBaseURL', '')):
            conf['ai']['gemini']['apiBaseURL'] = 'https://generativelanguage.googleapis.com/v1beta'
    
    with open(conf_path, 'w', encoding='utf-8') as f:
        json.dump(conf, f, ensure_ascii=False, indent=2)
    
    print('✓ Конфигурация AI исправлена')
except Exception as e:
    print(f'✗ Ошибка: {e}')
PYTHON_SCRIPT
    
    chown 1000:1000 workspace/conf/conf.json
    chmod 644 workspace/conf/conf.json
    
    # Проверяем результат
    if grep -q "openrouter.ai" workspace/conf/conf.json && ! grep -q "host.docker.internal.*11434" workspace/conf/conf.json; then
        echo "[OK] Конфигурация AI исправлена (OpenRouter, без host.docker.internal)"
    else
        echo "⚠️  Конфигурация может быть некорректна"
    fi
else
    echo "⚠️  Не удалось исправить конфигурацию AI"
fi
echo ""

# ============================================================================
# ШАГ 3: Исправление прав на файлы
# ============================================================================
echo "🔐 ШАГ 3: Исправление прав на файлы..."
if [ -d "workspace" ]; then
    chown -R 1000:1000 workspace
    chmod -R 755 workspace/conf
    chmod -R 755 workspace/data 2>/dev/null || true
    chmod 644 workspace/conf/conf.json 2>/dev/null || true
    echo "[OK] Права исправлены"
fi
echo ""

# ============================================================================
# ШАГ 4: Запуск контейнеров
# ============================================================================
echo "🚀 ШАГ 4: Запуск контейнеров..."
docker compose up -d
echo "[OK] Контейнеры запущены"
echo ""

# ============================================================================
# ШАГ 5: Принудительное копирование конфигурации в контейнер
# ============================================================================
echo "📋 ШАГ 5: Принудительное применение конфигурации..."
sleep 10

if docker ps | grep -q "digroup" && [ -f "workspace/conf/conf.json" ]; then
    echo "   Копируем конфигурацию в контейнер..."
    docker cp workspace/conf/conf.json digroup:/opt/siyuan/workspace/conf/conf.json 2>/dev/null || true
    docker compose exec -T digroup chown 1000:1000 /opt/siyuan/workspace/conf/conf.json 2>/dev/null || true
    
    # Создаем директории
    docker compose exec -T digroup mkdir -p /home/siyuan/.config/siyuan 2>/dev/null || true
    docker compose exec -T digroup sh -c 'echo "{}" > /home/siyuan/.config/siyuan/announcement.json' 2>/dev/null || true
    docker compose exec -T digroup chown -R 1000:1000 /home/siyuan/.config 2>/dev/null || true
    
    echo "   Перезапускаем контейнер для применения..."
    docker compose restart digroup
    sleep 15
    echo "[OK] Конфигурация применена"
else
    echo "⚠️  Контейнер не запущен или конфигурация не найдена"
fi
echo ""

# ============================================================================
# ШАГ 6: Проверка и ожидание
# ============================================================================
echo "⏳ ШАГ 6: Ожидание запуска ядра (до 60 секунд)..."
API_AVAILABLE=false
for i in {1..12}; do
    if curl -s --max-time 3 http://127.0.0.1:6806/api/system/version > /dev/null 2>&1; then
        API_AVAILABLE=true
        echo "[OK] API доступен!"
        break
    fi
    echo "   Ожидание... ($i/12)"
    sleep 5
done
echo ""

# ============================================================================
# ШАГ 7: Финальная проверка конфигурации
# ============================================================================
echo "🔍 ШАГ 7: Финальная проверка конфигурации..."
if [ "$API_AVAILABLE" = true ]; then
    # Проверка через API
    AI_CONFIG=$(curl -s http://127.0.0.1:6806/api/system/getConf 2>/dev/null | grep -o '"ai":{[^}]*}' || echo "")
    
    # Проверка внутри контейнера
    CONTAINER_CONFIG=$(docker compose exec -T digroup cat /opt/siyuan/workspace/conf/conf.json 2>/dev/null | grep -A 20 '"ai"' || echo "")
    
    if echo "$CONTAINER_CONFIG" | grep -q "openrouter.ai" && ! echo "$CONTAINER_CONFIG" | grep -q "host.docker.internal.*11434"; then
        echo "[OK] Конфигурация AI корректна в контейнере"
    else
        echo "⚠️  Конфигурация может быть некорректна, повторно применяем..."
        docker cp workspace/conf/conf.json digroup:/opt/siyuan/workspace/conf/conf.json 2>/dev/null || true
        docker compose restart digroup
        sleep 10
    fi
    
    # Проверка версии
    VERSION=$(curl -s http://127.0.0.1:6806/api/system/version 2>/dev/null | grep -o '"kernelVersion":"[^"]*"' | cut -d'"' -f4 || echo "неизвестна")
    echo "   Версия ядра: $VERSION"
else
    echo "⚠️  API недоступен"
    echo ""
    echo "Проверьте логи:"
    echo "   docker compose logs --tail=50 digroup"
fi
echo ""

# ============================================================================
# ИТОГИ
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$API_AVAILABLE" = true ]; then
    echo "✅ ЭКСТРЕННОЕ ИСПРАВЛЕНИЕ ЗАВЕРШЕНО"
    echo ""
    echo "Проблема должна быть исправлена!"
    echo ""
    echo "📋 СЛЕДУЮЩИЕ ШАГИ:"
    echo ""
    echo "1. Очистите кэш браузера полностью (Ctrl+Shift+Delete)"
    echo "2. Закройте ВСЕ вкладки с DIGroup"
    echo "3. Откройте заново в режиме инкогнито (Ctrl+Shift+N)"
    echo "4. Проверьте, что ошибка исчезла"
else
    echo "⚠️  ПРОБЛЕМА НЕ РЕШЕНА АВТОМАТИЧЕСКИ"
    echo ""
    echo "Выполните диагностику:"
    echo ""
    echo "1. Проверьте логи:"
    echo "   docker compose logs --tail=50 digroup"
    echo ""
    echo "2. Проверьте порт:"
    echo "   netstat -tlnp | grep 6806"
    echo ""
    echo "3. Проверьте конфигурацию:"
    echo "   docker compose exec digroup cat /opt/siyuan/workspace/conf/conf.json | grep -A 10 '\"ai\"'"
    echo ""
    echo "4. Попробуйте еще раз:"
    echo "   ./emergency-fix.sh"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
