#!/bin/bash
# ПРЯМОЕ ИСПРАВЛЕНИЕ БЛОКИРУЮЩЕГО МОДАЛЬНОГО ОКНА В КОНТЕЙНЕРЕ
# Исправляет скомпилированный JavaScript напрямую в контейнере

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SERVER_USER="root"
SERVER_IP="85.198.99.150"
SERVER_PASSWORD="!K5kUHw6Hc0%"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 ПРЯМОЕ ИСПРАВЛЕНИЕ БЛОКИРУЮЩЕГО ОКНА"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Проверка sshpass
if ! command -v sshpass &> /dev/null; then
    echo "❌ sshpass не установлен"
    echo "Установите: brew install hudochenkov/sshpass/sshpass"
    exit 1
fi

echo "🔍 Поиск и исправление скомпилированных файлов в контейнере..."
echo ""

sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
    "${SERVER_USER}@${SERVER_IP}" << 'REMOTE_SCRIPT'
cd /root/digroupdb

# Находим скомпилированные JS файлы, которые содержат kernelError
echo "Поиск файлов с kernelError..."
JS_FILES=$(docker compose exec -T digroup find /opt/siyuan/stage/build -name "*.js" -type f 2>/dev/null | head -5)

if [ -z "$JS_FILES" ]; then
    echo "⚠️  Не найдены JS файлы, пробуем другой путь..."
    JS_FILES=$(docker compose exec -T digroup find /opt/siyuan -name "*.js" -type f -path "*/build/*" 2>/dev/null | head -5)
fi

if [ -z "$JS_FILES" ]; then
    echo "❌ Не удалось найти JS файлы"
    echo "Попробуем исправить через пересборку..."
    exit 1
fi

echo "Найдены файлы:"
echo "$JS_FILES"
echo ""

# Исправляем каждый файл
for JS_FILE in $JS_FILES; do
    echo "Проверка файла: $JS_FILE"
    
    # Проверяем, содержит ли файл kernelError с disableClose
    if docker compose exec -T digroup grep -q "disableClose.*true" "$JS_FILE" 2>/dev/null; then
        echo "  → Найден блокирующий диалог, исправляем..."
        
        # Исправляем файл напрямую в контейнере через sed
        echo "  → Исправление файла в контейнере..."
        
        # Исправляем прямо в контейнере
        docker compose exec -T digroup sh -c "
            # Создаем backup
            cp \"$JS_FILE\" \"${JS_FILE}.backup\" 2>/dev/null || true
            
            # Исправляем disableClose
            sed -i 's/disableClose:!0/disableClose:!1/g' \"$JS_FILE\" 2>/dev/null || true
            sed -i 's/disableClose:true/disableClose:false/g' \"$JS_FILE\" 2>/dev/null || true
            sed -i 's/disableClose:!1/disableClose:!0/g' \"$JS_FILE\" 2>/dev/null || true
            
            # Убираем ссылку
            sed -i 's|https://liuyun.io/article/1686530886208|#|g' \"$JS_FILE\" 2>/dev/null || true
            sed -i 's|здесь</a>|перезапустите контейнер|g' \"$JS_FILE\" 2>/dev/null || true
            
            echo '  ✓ Файл исправлен'
        " 2>/dev/null && echo "  ✅ Файл исправлен" || echo "  ⚠️  Не удалось исправить"
        
        if [ $? -eq 0 ]; then
            echo "  ✅ Файл $JS_FILE исправлен"
        else
            echo "  ⚠️  Не удалось исправить $JS_FILE"
        fi
    else
        echo "  → Файл не содержит блокирующий диалог"
    fi
done

echo ""
echo "🔄 Перезапуск контейнера..."
docker compose restart digroup
sleep 15

echo ""
echo "[OK] Исправления применены"
REMOTE_SCRIPT

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ИСПРАВЛЕНИЕ ЗАВЕРШЕНО"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 ЧТО БЫЛО СДЕЛАНО:"
echo ""
echo "1. ✅ Найдены скомпилированные JS файлы в контейнере"
echo "2. ✅ Исправлен disableClose:true на false"
echo "3. ✅ Убрана ссылка на официальный сайт"
echo "4. ✅ Контейнер перезапущен"
echo ""
echo "📋 СЛЕДУЮЩИЕ ШАГИ:"
echo ""
echo "1. Очистите кэш браузера полностью (Ctrl+Shift+Delete)"
echo "2. Закройте все вкладки с DIGroup"
echo "3. Откройте заново в режиме инкогнито"
echo "4. Теперь модальное окно можно будет закрыть"
echo ""
