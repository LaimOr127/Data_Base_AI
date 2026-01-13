#!/bin/bash
# Бэкап в облачное хранилище (Yandex Object Storage, S3)

set -e

# Конфигурация
BACKUP_DIR="/opt/digroup/backups"
WORKSPACE_DIR="/opt/digroup/workspace"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Загрузка переменных окружения
if [ -f /opt/digroup/.env ]; then
    source /opt/digroup/.env
fi

# Проверка наличия s3cmd или aws cli
if command -v s3cmd &> /dev/null; then
    S3_CMD="s3cmd"
elif command -v aws &> /dev/null; then
    S3_CMD="aws s3"
else
    echo "❌ s3cmd или aws cli не установлены"
    echo "Установите: sudo apt install s3cmd"
    exit 1
fi

# Проверка переменных окружения
if [ -z "$S3_BUCKET" ] || [ -z "$S3_ENDPOINT" ]; then
    echo "❌ Переменные S3_BUCKET и S3_ENDPOINT не установлены"
    echo "Добавьте в .env:"
    echo "  S3_BUCKET=your-bucket-name"
    echo "  S3_ENDPOINT=https://storage.yandexcloud.net  # или другой endpoint"
    echo "  S3_ACCESS_KEY=your-access-key"
    echo "  S3_SECRET_KEY=your-secret-key"
    exit 1
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Начало бэкапа в облако"

# Создание локального бэкапа
BACKUP_FILE="$BACKUP_DIR/workspace_$DATE.tar.gz"
log "Создание архива..."
tar -czf "$BACKUP_FILE" -C "$(dirname $WORKSPACE_DIR)" "$(basename $WORKSPACE_DIR)" 2>&1 | grep -v "Removing leading"

if [ $? -ne 0 ]; then
    log "❌ Ошибка при создании архива"
    exit 1
fi

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log "✅ Архив создан: $BACKUP_SIZE"

# Загрузка в облако
log "Загрузка в облако..."

if [ "$S3_CMD" = "s3cmd" ]; then
    s3cmd put "$BACKUP_FILE" "s3://${S3_BUCKET}/digroup-backups/" \
        --host="${S3_ENDPOINT}" \
        --host-bucket="${S3_BUCKET}.${S3_ENDPOINT}" \
        --access_key="${S3_ACCESS_KEY}" \
        --secret_key="${S3_SECRET_KEY}"
else
    aws s3 cp "$BACKUP_FILE" "s3://${S3_BUCKET}/digroup-backups/" \
        --endpoint-url="${S3_ENDPOINT}" \
        --profile default
fi

if [ $? -eq 0 ]; then
    log "✅ Бэкап загружен в облако"
    
    # Удаление локального файла (опционально)
    # rm "$BACKUP_FILE"
    
    # Удаление старых бэкапов из облака
    log "Удаление старых бэкапов из облака..."
    
    if [ "$S3_CMD" = "s3cmd" ]; then
        s3cmd ls "s3://${S3_BUCKET}/digroup-backups/" | while read -r line; do
            FILE_DATE=$(echo "$line" | awk '{print $1" "$2}')
            FILE_NAME=$(echo "$line" | awk '{print $4}')
            if [ -n "$FILE_NAME" ]; then
                FILE_EPOCH=$(date -d "$FILE_DATE" +%s)
                NOW_EPOCH=$(date +%s)
                DAYS_OLD=$(( (NOW_EPOCH - FILE_EPOCH) / 86400 ))
                
                if [ $DAYS_OLD -gt $RETENTION_DAYS ]; then
                    s3cmd del "$FILE_NAME" \
                        --host="${S3_ENDPOINT}" \
                        --access_key="${S3_ACCESS_KEY}" \
                        --secret_key="${S3_SECRET_KEY}"
                    log "Удален старый бэкап: $(basename $FILE_NAME)"
                fi
            fi
        done
    fi
else
    log "❌ Ошибка при загрузке в облако"
    exit 1
fi

log "✅ Бэкап в облако завершен успешно"

