#!/bin/bash
# Синхронизация файлов с локального ПК на сервер
# Удаляет старые скрипты и копирует новые
# Использование: ./sync-to-server.sh [SERVER_IP] [SERVER_USER] [SERVER_PATH]

set -e

# Параметры по умолчанию
SERVER_IP="${1:-85.198.99.150}"
SERVER_USER="${2:-root}"
SERVER_PATH="${3:-/root/digroupdb}"
LOCAL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📤 СИНХРОНИЗАЦИЯ ФАЙЛОВ НА СЕРВЕР"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Сервер: ${SERVER_USER}@${SERVER_IP}"
echo "Путь: ${SERVER_PATH}"
echo "Локальный путь: ${LOCAL_PATH}"
echo ""

# Проверка подключения
echo "🔍 Проверка подключения к серверу..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "${SERVER_USER}@${SERVER_IP}" exit 2>/dev/null; then
    echo "❌ Не удалось подключиться к серверу"
    echo ""
    echo "Проверьте:"
    echo "1. SSH ключи настроены"
    echo "2. Сервер доступен"
    echo "3. Правильный IP: ${SERVER_IP}"
    echo ""
    echo "Или подключитесь вручную:"
    echo "ssh ${SERVER_USER}@${SERVER_IP}"
    exit 1
fi
echo "[OK] Подключение установлено"
echo ""

# Список файлов для синхронизации (один главный скрипт и конфигурации)
FILES_TO_SYNC=(
    "fix-all.sh"
    "docker-compose.yml"
    ".env.example"
)

# Документация
DOCS_TO_SYNC=(
    "ИНСТРУКЦИЯ.md"
)

echo "📦 ШАГ 1: Создание резервной копии на сервере..."
ssh "${SERVER_USER}@${SERVER_IP}" "cd ${SERVER_PATH} && mkdir -p backups && tar -czf backups/backup-before-sync-$(date +%Y%m%d-%H%M%S).tar.gz *.sh *.md *.conf 2>/dev/null || true"
echo "[OK] Резервная копия создана"
echo ""

echo "🗑️  ШАГ 2: Удаление старых скриптов..."
# Удаляем все старые скрипты исправления (кроме fix-all.sh и emergency-fix.sh)
ssh "${SERVER_USER}@${SERVER_IP}" "cd ${SERVER_PATH} && rm -f fix-all-tabs.sh fix-all-user-issues.sh fix-home-wifi-access.sh setup-*.sh replace-*.sh fix-403.sh fix-ai.sh fix-simple.sh 2>/dev/null || true"
echo "[OK] Старые скрипты удалены"
echo ""

echo "📤 ШАГ 3: Копирование новых файлов..."
# Копируем скрипты
for file in "${FILES_TO_SYNC[@]}"; do
    if [ -f "${LOCAL_PATH}/${file}" ]; then
        echo "  → ${file}"
        scp "${LOCAL_PATH}/${file}" "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/${file}"
        # Делаем исполняемым
        ssh "${SERVER_USER}@${SERVER_IP}" "chmod +x ${SERVER_PATH}/${file} 2>/dev/null || true"
    else
        echo "  ⚠️  ${file} не найден, пропуск"
    fi
done

# Копируем документацию
for file in "${DOCS_TO_SYNC[@]}"; do
    if [ -f "${LOCAL_PATH}/${file}" ]; then
        echo "  → ${file}"
        scp "${LOCAL_PATH}/${file}" "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/${file}"
    fi
done

echo "[OK] Файлы скопированы"
echo ""

echo "🔧 ШАГ 4: Проверка и настройка на сервере..."
ssh "${SERVER_USER}@${SERVER_IP}" << 'REMOTE_SCRIPT'
cd /root/digroupdb

# Убеждаемся, что все скрипты исполняемые
chmod +x *.sh 2>/dev/null || true

# Проверяем наличие основных файлов
if [ ! -f "docker-compose.yml" ]; then
    echo "⚠️  docker-compose.yml не найден"
fi

if [ ! -d "workspace" ]; then
    echo "⚠️  Директория workspace не найдена"
fi

echo "[OK] Проверка завершена"
REMOTE_SCRIPT

echo "[OK] Настройка завершена"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ СИНХРОНИЗАЦИЯ ЗАВЕРШЕНА"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 ЧТО БЫЛО СДЕЛАНО:"
echo ""
echo "1. ✅ Создана резервная копия на сервере"
echo "2. ✅ Удалены старые скрипты"
echo "3. ✅ Скопированы новые файлы"
echo "4. ✅ Настроены права доступа"
echo ""
echo "📋 СЛЕДУЮЩИЕ ШАГИ НА СЕРВЕРЕ:"
echo ""
echo "1. Подключитесь к серверу:"
echo "   ssh ${SERVER_USER}@${SERVER_IP}"
echo ""
echo "2. Перейдите в директорию:"
echo "   cd ${SERVER_PATH}"
echo ""
echo "ВАРИАНТ 1: Экстренное исправление (рекомендуется)"
echo "   ./emergency-fix.sh"
echo ""
echo "ВАРИАНТ 2: Полное исправление"
echo "   ./fix-all.sh"
echo ""
echo "💡 БЫСТРЫЙ ЗАПУСК:"
echo ""
echo "   ssh ${SERVER_USER}@${SERVER_IP} 'cd ${SERVER_PATH} && ./emergency-fix.sh'"
echo ""
