#!/bin/bash

set -e

ARCHIVE_NAME="digroup-deployment-$(date +%Y%m%d_%H%M%S).tar.gz"
EXCLUDE_PATTERNS=(
    "--exclude=node_modules"
    "--exclude=workspace/data"
    "--exclude=workspace/history"
    "--exclude=workspace/temp"
    "--exclude=backups"
    "--exclude=.git"
    "--exclude=.DS_Store"
    "--exclude=*.log"
    "--exclude=*.tar.gz"
    "--exclude=*.zip"
    "--exclude=digroup-test"
    "--exclude=test"
    "--exclude=data"
)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 СОЗДАНИЕ АРХИВА ДЛЯ РАЗВЕРТЫВАНИЯ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Архив: $ARCHIVE_NAME"
echo ""

cd "$(dirname "$0")"

tar -czf "$ARCHIVE_NAME" \
    "${EXCLUDE_PATTERNS[@]}" \
    --exclude="$ARCHIVE_NAME" \
    .

ARCHIVE_SIZE=$(du -h "$ARCHIVE_NAME" | cut -f1)

echo "✅ Архив создан: $ARCHIVE_NAME"
echo "📊 Размер: $ARCHIVE_SIZE"
echo ""
echo "📝 Архив содержит:"
echo "  • Конфигурацию Docker (docker-compose.yml)"
echo "  • Скрипты развертывания (deploy/)"
echo "  • Исходный код SiYuan (siyuan/)"
echo "  • Скрипты настройки (setup-*.py, setup-*.sh)"
echo "  • Документацию"
echo ""
echo "❌ Исключено из архива:"
echo "  • node_modules (зависимости)"
echo "  • workspace/data (данные пользователей)"
echo "  • workspace/history (история изменений)"
echo "  • workspace/temp (временные файлы)"
echo "  • backups (резервные копии)"
echo ""
echo "🚀 Для развертывания на сервере:"
echo "  1. Скопируйте архив на сервер"
echo "  2. Распакуйте: tar -xzf $ARCHIVE_NAME"
echo "  3. Запустите: ./install.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
