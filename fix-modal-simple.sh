#!/bin/bash
# ПРОСТОЕ ИСПРАВЛЕНИЕ БЛОКИРУЮЩЕГО МОДАЛЬНОГО ОКНА
# Заменяет disableClose:true на disableClose:false во всех JS файлах

SERVER_USER="root"
SERVER_IP="85.198.99.150"
SERVER_PASSWORD="!K5kUHw6Hc0%"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 ИСПРАВЛЕНИЕ БЛОКИРУЮЩЕГО МОДАЛЬНОГО ОКНА"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v sshpass &> /dev/null; then
    echo "❌ sshpass не установлен: brew install hudochenkov/sshpass/sshpass"
    exit 1
fi

sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
    "${SERVER_USER}@${SERVER_IP}" << 'REMOTE_SCRIPT'
cd /root/digroupdb

echo "🔍 Поиск JS файлов с блокирующим диалогом..."

# Находим все JS файлы в stage/build
JS_FILES=$(docker compose exec -T digroup find /opt/siyuan/stage/build -name "*.js" -type f 2>/dev/null)

if [ -z "$JS_FILES" ]; then
    echo "⚠️  JS файлы не найдены в /opt/siyuan/stage/build"
    echo "Пробуем найти в других местах..."
    JS_FILES=$(docker compose exec -T digroup find /opt/siyuan -name "*.js" -type f 2>/dev/null | grep -E "(build|stage)" | head -10)
fi

if [ -z "$JS_FILES" ]; then
    echo "❌ Не удалось найти JS файлы"
    exit 1
fi

echo "Найдено файлов: $(echo "$JS_FILES" | wc -l)"
echo ""

FIXED_COUNT=0

# Исправляем каждый файл
for JS_FILE in $JS_FILES; do
    # Проверяем, содержит ли файл disableClose
    if docker compose exec -T digroup grep -q "disableClose" "$JS_FILE" 2>/dev/null; then
        echo "Исправление: $JS_FILE"
        
        # Исправляем прямо в контейнере
        docker compose exec -T digroup sh -c "
            # Создаем backup
            cp \"$JS_FILE\" \"${JS_FILE}.backup\" 2>/dev/null || true
            
            # Заменяем все варианты disableClose:true на false
            sed -i 's/disableClose:!0/disableClose:!1/g' \"$JS_FILE\" 2>/dev/null || true
            sed -i 's/disableClose:true/disableClose:false/g' \"$JS_FILE\" 2>/dev/null || true
            sed -i 's/disableClose:\"true\"/disableClose:false/g' \"$JS_FILE\" 2>/dev/null || true
            
            # Убираем ссылку на официальный сайт
            sed -i 's|https://liuyun.io/article/1686530886208|#|g' \"$JS_FILE\" 2>/dev/null || true
            sed -i 's|здесь</a>|перезапустите контейнер|g' \"$JS_FILE\" 2>/dev/null || true
            
            echo '  ✓ Исправлено'
        " 2>/dev/null && FIXED_COUNT=$((FIXED_COUNT + 1)) || echo "  ⚠️  Ошибка"
    fi
done

echo ""
echo "✅ Исправлено файлов: $FIXED_COUNT"
echo ""

if [ $FIXED_COUNT -gt 0 ]; then
    echo "🔄 Перезапуск контейнера..."
    docker compose restart digroup
    sleep 15
    echo "[OK] Контейнер перезапущен"
else
    echo "⚠️  Файлы не были исправлены"
    echo "Попробуйте пересобрать образ: docker compose build digroup"
fi
REMOTE_SCRIPT

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ГОТОВО"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 СЛЕДУЮЩИЕ ШАГИ:"
echo ""
echo "1. Очистите кэш браузера (Ctrl+Shift+Delete)"
echo "2. Закройте все вкладки с DIGroup"
echo "3. Откройте заново в режиме инкогнито"
echo "4. Теперь модальное окно можно будет закрыть (крестик в углу)"
echo ""
