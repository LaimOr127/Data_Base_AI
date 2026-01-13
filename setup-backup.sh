#!/bin/bash
# Скрипт настройки автоматических бэкапов
# Создает cron задачу для ежедневного бэкапа
# Использование: ./setup-backup.sh [время]
# Пример: ./setup-backup.sh 02:00  (бэкап в 2 часа ночи)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_TIME="${1:-02:00}"

# Разбиваем время на часы и минуты
HOUR=$(echo "$BACKUP_TIME" | cut -d':' -f1)
MINUTE=$(echo "$BACKUP_TIME" | cut -d':' -f2)

echo "=========================================="
echo " Настройка автоматических бэкапов"
echo "=========================================="
echo ""
echo "Директория: $SCRIPT_DIR"
echo "Время бэкапа: $BACKUP_TIME (каждый день)"
echo ""

# Создание cron задачи
CRON_CMD="$MINUTE $HOUR * * * cd $SCRIPT_DIR && ./backup.sh >> ./logs/backup-cron.log 2>&1"

# Проверка существующей задачи
if crontab -l 2>/dev/null | grep -q "backup.sh"; then
    echo "Обнаружена существующая задача бэкапа"
    echo "Удаляю старую..."
    crontab -l 2>/dev/null | grep -v "backup.sh" | crontab -
fi

# Добавление новой задачи
echo "Добавление cron задачи..."
(crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -

echo "[OK] Cron задача добавлена"
echo ""

# Проверка
echo "Текущие cron задачи:"
crontab -l | grep "backup.sh" || echo "Нет задач"
echo ""

# Создание лог директории
mkdir -p "$SCRIPT_DIR/logs"

echo "=========================================="
echo " Автобэкапы настроены"
echo "=========================================="
echo ""
echo "Бэкапы будут создаваться:"
echo "  Время: каждый день в $BACKUP_TIME"
echo "  Директория: $SCRIPT_DIR/backups/"
echo "  Логи: $SCRIPT_DIR/logs/backup-cron.log"
echo ""
echo "Ручной запуск: ./backup.sh"
echo "Просмотр логов: tail -f ./logs/backup-cron.log"
echo ""
echo "Для отмены:"
echo "  crontab -l | grep -v backup.sh | crontab -"
echo ""
