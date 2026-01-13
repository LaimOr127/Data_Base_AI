#!/bin/bash
# Скрипт автоматического резервного копирования DIGroup
# Использование: ./backup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

mkdir -p "$BACKUP_DIR"

LOG_FILE="./logs/backup.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=========================================="
log "Начало резервного копирования"
log "=========================================="

# Проверка наличия директорий
if [ ! -d "workspace" ]; then
    log "Ошибка: Директория workspace не найдена"
    exit 1
fi

# Создание архива workspace
log "Создание архива workspace..."
tar -czf "$BACKUP_DIR/workspace_$DATE.tar.gz" workspace 2>&1 | tee -a "$LOG_FILE"

if [ $? -eq 0 ]; then
    SIZE=$(du -h "$BACKUP_DIR/workspace_$DATE.tar.gz" | cut -f1)
    log "Создан: workspace_$DATE.tar.gz ($SIZE)"
else
    log "Ошибка при создании архива workspace"
    exit 1
fi

# Архив data (если есть)
if [ -d "data" ] && [ "$(ls -A data 2>/dev/null)" ]; then
    log "Создание архива data..."
    tar -czf "$BACKUP_DIR/data_$DATE.tar.gz" data 2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        SIZE=$(du -h "$BACKUP_DIR/data_$DATE.tar.gz" | cut -f1)
        log "Создан: data_$DATE.tar.gz ($SIZE)"
    fi
fi

# Копирование .env
if [ -f ".env" ]; then
    cp .env "$BACKUP_DIR/.env_$DATE"
    log "Скопирован: .env_$DATE"
fi

# Удаление старых бэкапов
log "Удаление бэкапов старше $RETENTION_DAYS дней..."
find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete 2>&1 | tee -a "$LOG_FILE"
find "$BACKUP_DIR" -name ".env_*" -type f -mtime +$RETENTION_DAYS -delete 2>&1 | tee -a "$LOG_FILE"

# Статистика
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

log "=========================================="
log "Резервное копирование завершено"
log "Количество архивов: $BACKUP_COUNT"
log "Общий размер: $TOTAL_SIZE"
log "=========================================="
