#!/bin/bash
# Скрипт для восстановления пользователей в conf.json после перезаписи приложением

cd "$(dirname "$0")"

echo "🔄 Восстановление пользователей в conf.json..."

# Загружаем пользователей
python3 setup-users-from-csv.py

# Копируем в контейнер
docker compose cp workspace/conf/conf.json digroup:/opt/siyuan/workspace/conf/conf.json 2>/dev/null || echo "⚠️  Контейнер не запущен, файл обновлен локально"

echo "✅ Готово! Пользователи восстановлены."
