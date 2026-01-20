#!/bin/bash
# ИСПРАВЛЕНИЕ БЛОКИРУЮЩЕГО МОДАЛЬНОГО ОКНА ОШИБКИ
# Заменяет блокирующее модальное окно на неблокирующее уведомление

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SERVER_USER="root"
SERVER_IP="85.198.99.150"
SERVER_PASSWORD="!K5kUHw6Hc0%"
SERVER_PATH="/root/digroupdb"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 ИСПРАВЛЕНИЕ БЛОКИРУЮЩЕГО МОДАЛЬНОГО ОКНА"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Проверка sshpass
if ! command -v sshpass &> /dev/null; then
    echo "❌ sshpass не установлен"
    echo "Установите: brew install hudochenkov/sshpass/sshpass"
    exit 1
fi

echo "📤 Копирование исправленных файлов на сервер..."
echo ""

# Копируем исправленный файл processSystem.ts
if [ -f "siyuan/app/src/dialog/processSystem.ts" ]; then
    echo "  → processSystem.ts (исправлена функция kernelError)"
    sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
        "${SERVER_USER}@${SERVER_IP}" \
        "mkdir -p ${SERVER_PATH}/siyuan/app/src/dialog"
    
    sshpass -p "${SERVER_PASSWORD}" scp -o StrictHostKeyChecking=no \
        "siyuan/app/src/dialog/processSystem.ts" \
        "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/siyuan/app/src/dialog/processSystem.ts"
fi

# Копируем исправленный языковой файл
if [ -f "siyuan/app/appearance/langs/ru_RU.json" ]; then
    echo "  → ru_RU.json (убран текст со ссылкой)"
    sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
        "${SERVER_USER}@${SERVER_IP}" \
        "mkdir -p ${SERVER_PATH}/siyuan/app/appearance/langs"
    
    sshpass -p "${SERVER_PASSWORD}" scp -o StrictHostKeyChecking=no \
        "siyuan/app/appearance/langs/ru_RU.json" \
        "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/siyuan/app/appearance/langs/ru_RU.json"
fi

echo ""
echo "[OK] Файлы скопированы"
echo ""

echo "🔄 Перезапуск контейнера для применения изменений..."
sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
    "${SERVER_USER}@${SERVER_IP}" << 'REMOTE_SCRIPT'
cd /root/digroupdb

# Перезапускаем контейнер
docker compose restart digroup
sleep 15

echo "[OK] Контейнер перезапущен"
REMOTE_SCRIPT

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ИСПРАВЛЕНИЕ ЗАВЕРШЕНО"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 ЧТО БЫЛО ИСПРАВЛЕНО:"
echo ""
echo "1. ✅ Блокирующее модальное окно заменено на неблокирующее уведомление"
echo "2. ✅ Убрана ссылка на официальный сайт"
echo "3. ✅ Теперь при ошибке показывается только уведомление внизу экрана"
echo "4. ✅ Интерфейс больше не блокируется"
echo ""
echo "📋 СЛЕДУЮЩИЕ ШАГИ:"
echo ""
echo "1. Очистите кэш браузера полностью (Ctrl+Shift+Delete)"
echo "2. Закройте все вкладки с DIGroup"
echo "3. Откройте заново в режиме инкогнито (Ctrl+Shift+N)"
echo "4. При ошибке теперь будет показываться только уведомление, а не блокирующее окно"
echo ""
