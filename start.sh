#!/bin/bash
# Скрипт запуска DIGroup через Docker
# Использование: ./start.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo " Запуск DIGroup"
echo "=========================================="
echo ""

# Проверка Docker
if ! command -v docker &> /dev/null; then
    echo "Ошибка: Docker не установлен"
    echo "Установите Docker: https://www.docker.com/get-started"
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    echo "Ошибка: Docker не запущен"
    echo "Запустите Docker и попробуйте снова"
    exit 1
fi

echo "[OK] Docker доступен"
echo ""

# Проверка docker-compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
    echo "Предупреждение: docker-compose не найден"
fi

# Создание директорий
mkdir -p workspace data backups logs

# Проверка .env
if [ ! -f ".env" ]; then
    echo "Создание .env файла..."
    cat > .env << 'EOF'
ACCESS_AUTH_CODE=b226ba0f30a134fe9245792118bca202
TZ=Europe/Moscow
HOST_IP=0.0.0.0
PORT=6806
PUID=1000
PGID=1000
EOF
    echo "[OK] .env файл создан"
fi

# Загрузка переменных
set -a
source .env 2>/dev/null || true
set +a

echo""
# Остановка старых контейнеров
if docker ps -a --format '{{.Names}}' | grep -q '^digroup$'; then
    echo "Остановка старого контейнера..."
    docker-compose down 2>/dev/null || docker compose down 2>/dev/null || true
fi

echo ""
echo "Запуск контейнера..."
if docker-compose up -d 2>/dev/null || docker compose up -d 2>/dev/null; then
    echo "[OK] Контейнер запущен"
else
    echo "Ошибка при запуске"
    echo "Проверьте логи: docker-compose logs"
    exit 1
fi

echo ""
echo "Ожидание запуска сервиса..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -s http://127.0.0.1:${PORT:-6806}/api/system/version > /dev/null 2>&1; then
        break
    fi
    echo -n "."
    sleep 2
    ATTEMPT=$((ATTEMPT + 1))
done
echo ""

if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
    VERSION=$(curl -s http://127.0.0.1:${PORT:-6806}/api/system/version 2>/dev/null | grep -o '"data":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    echo "[OK] Сервис запущен (версия: $VERSION)"
else
    echo "Предупреждение: Сервис не отвечает"
    echo "Проверьте: docker-compose logs -f"
fi

echo ""
echo "=========================================="
echo " DIGroup запущен"
echo "=========================================="
echo ""
echo "URL: http://localhost:${PORT:-6806}"
echo "Код доступа: ${ACCESS_AUTH_CODE}"
echo ""
echo "Управление:"
echo "  Логи:       docker-compose logs -f"
echo "  Остановка:  docker-compose down"
echo "  Перезапуск: docker-compose restart"
echo "  Статус:     docker-compose ps"
echo ""
