#!/bin/bash
# АВТОМАТИЧЕСКОЕ ИСПРАВЛЕНИЕ ПРОБЛЕМЫ НА СЕРВЕРЕ
# Подключается к серверу и запускает emergency-fix.sh
# Использование: ./auto-fix-server.sh

set -e

# Параметры сервера
SERVER_IP="85.198.99.150"
SERVER_USER="root"
SERVER_PATH="/root/digroupdb"
SERVER_PASSWORD="!K5kUHw6Hc0%"

LOCAL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 АВТОМАТИЧЕСКОЕ ИСПРАВЛЕНИЕ НА СЕРВЕРЕ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Сервер: ${SERVER_USER}@${SERVER_IP}"
echo "Путь: ${SERVER_PATH}"
echo ""

# Проверка наличия sshpass
if ! command -v sshpass &> /dev/null; then
    echo "⚠️  sshpass не установлен"
    echo ""
    echo "Установите sshpass:"
    echo "  macOS: brew install hudochenkov/sshpass/sshpass"
    echo "  Linux: sudo apt-get install sshpass"
    echo ""
    echo "Или выполните вручную:"
    echo "  ssh ${SERVER_USER}@${SERVER_IP}"
    echo "  cd ${SERVER_PATH}"
    echo "  ./emergency-fix.sh"
    exit 1
fi

# ШАГ 1: Синхронизация файлов
echo "📤 ШАГ 1: Синхронизация файлов на сервер..."
echo ""

# Копируем emergency-fix.sh
if [ -f "${LOCAL_PATH}/emergency-fix.sh" ]; then
    sshpass -p "${SERVER_PASSWORD}" scp -o StrictHostKeyChecking=no \
        "${LOCAL_PATH}/emergency-fix.sh" \
        "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/emergency-fix.sh"
    echo "[OK] emergency-fix.sh скопирован"
    
    # Делаем исполняемым
    sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
        "${SERVER_USER}@${SERVER_IP}" \
        "chmod +x ${SERVER_PATH}/emergency-fix.sh"
else
    echo "⚠️  emergency-fix.sh не найден локально"
fi

# Копируем fix-all.sh (на всякий случай)
if [ -f "${LOCAL_PATH}/fix-all.sh" ]; then
    sshpass -p "${SERVER_PASSWORD}" scp -o StrictHostKeyChecking=no \
        "${LOCAL_PATH}/fix-all.sh" \
        "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/fix-all.sh"
    sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
        "${SERVER_USER}@${SERVER_IP}" \
        "chmod +x ${SERVER_PATH}/fix-all.sh"
    echo "[OK] fix-all.sh скопирован"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 ШАГ 2: Запуск экстренного исправления..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Запускаем emergency-fix.sh на сервере
sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
    "${SERVER_USER}@${SERVER_IP}" \
    "cd ${SERVER_PATH} && ./emergency-fix.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ИСПРАВЛЕНИЕ ЗАВЕРШЕНО"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 СЛЕДУЮЩИЕ ШАГИ:"
echo ""
echo "1. Очистите кэш браузера полностью (Ctrl+Shift+Delete)"
echo "2. Закройте ВСЕ вкладки с DIGroup"
echo "3. Откройте заново в режиме инкогнито (Ctrl+Shift+N)"
echo "4. Проверьте, что ошибка исчезла"
echo ""
echo "Если проблема сохраняется, проверьте логи:"
echo "  ssh ${SERVER_USER}@${SERVER_IP} 'cd ${SERVER_PATH} && docker compose logs --tail=50 digroup'"
echo ""
