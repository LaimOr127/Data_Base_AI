#!/bin/bash
# Скрипт для автоматического бэкапа DIGroup workspace

set -e

# Конфигурация
BACKUP_DIR="/opt/digroup/backups"
WORKSPACE_DIR="/opt/digroup/workspace"
DATA_DIR="/opt/digroup/data"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Создание директории для бэкапов
mkdir -p "$BACKUP_DIR"

# Логирование
LOG_FILE="/var/log/digroup-backup.log"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Начало бэкапа DIGroup"

# Бэкап workspace
if [ -d "$WORKSPACE_DIR" ]; then
    log "Создание бэкапа workspace..."
    tar -czf "$BACKUP_DIR/workspace_$DATE.tar.gz" -C "$(dirname $WORKSPACE_DIR)" "$(basename $WORKSPACE_DIR)" 2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        log "✅ Бэкап workspace создан: workspace_$DATE.tar.gz"
    else
        log "❌ Ошибка при создании бэкапа workspace"
        exit 1
    fi
else
    log "⚠️  Директория workspace не найдена: $WORKSPACE_DIR"
fi

# Бэкап data (если есть)
if [ -d "$DATA_DIR" ] && [ "$(ls -A $DATA_DIR)" ]; then
    log "Создание бэкапа data..."
    tar -czf "$BACKUP_DIR/data_$DATE.tar.gz" -C "$(dirname $DATA_DIR)" "$(basename $DATA_DIR)" 2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        log "✅ Бэкап data создан: data_$DATE.tar.gz"
    else
        log "❌ Ошибка при создании бэкапа data"
    fi
fi

# Удаление старых бэкапов
log "Удаление бэкапов старше $RETENTION_DAYS дней..."
find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
log "✅ Старые бэкапы удалены"

# Проверка размера бэкапов
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
log "Общий размер бэкапов: $TOTAL_SIZE"

log "✅ Бэкап завершен успешно"

