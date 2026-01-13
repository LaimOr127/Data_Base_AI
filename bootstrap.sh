#!/bin/bash
# Полная автоматическая установка DIGroup после клонирования
# Использование: ./bootstrap.sh

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 ПОЛНАЯ УСТАНОВКА DIGROUP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Шаг 1: Установка Docker и зависимостей
echo "📦 ШАГ 1: Установка зависимостей..."
echo ""
if [ ! -f ".env" ]; then
    ./install.sh
else
    echo "[OK] Зависимости уже установлены"
fi
echo ""

# Шаг 2: Создание необходимых директорий
echo "📁 ШАГ 2: Создание директорий..."
mkdir -p workspace/conf workspace/data workspace/history workspace/temp
mkdir -p data backups logs
echo "[OK] Директории созданы"
echo ""

# Шаг 3: Инициализация conf.json если его нет
echo "⚙️  ШАГ 3: Инициализация конфигурации..."
if [ ! -f "workspace/conf/conf.json" ]; then
    echo "Создание базового conf.json..."
    cat > workspace/conf/conf.json << 'EOF'
{
  "appearance": {
    "mode": 0,
    "theme": 0,
    "icon": "material",
    "codeBlockThemeLight": "github",
    "codeBlockThemeDark": "github-dark"
  },
  "publish": {
    "enable": true,
    "port": 6808,
    "auth": {
      "enable": true,
      "accounts": []
    }
  },
  "ai": {}
}
EOF
    echo "[OK] conf.json создан"
else
    echo "[OK] conf.json существует"
fi
echo ""

# Шаг 4: Настройка пользователей
echo "👥 ШАГ 4: Настройка пользователей..."
if [ -f "users_db/users_list.txt" ]; then
    if command -v python3 &> /dev/null; then
        python3 setup-users.py
        echo "[OK] Пользователи настроены"
    else
        echo "⚠️  Python3 не найден, пропускаем настройку пользователей"
        echo "   Запустите позже: python3 setup-users.py"
    fi
else
    echo "⚠️  users_list.txt не найден, пропускаем настройку пользователей"
    echo "   Создайте файл users_db/users_list.txt и запустите: python3 setup-users.py"
fi
echo ""

# Шаг 5: Настройка ИИ
echo "🤖 ШАГ 5: Настройка ИИ..."
if [ -f "workspace/conf/conf.json" ]; then
    if command -v python3 &> /dev/null; then
        python3 setup-ai.py
        echo "[OK] ИИ настроен"
    else
        echo "⚠️  Python3 не найден, пропускаем настройку ИИ"
        echo "   Запустите позже: python3 setup-ai.py"
    fi
else
    echo "⚠️  conf.json не найден, пропускаем настройку ИИ"
fi
echo ""

# Шаг 6: Сборка и запуск Docker контейнеров
echo "🐳 ШАГ 6: Сборка и запуск контейнеров..."
echo ""
echo "Это может занять несколько минут при первом запуске..."
echo ""

# Загружаем переменные из .env
set -a
source .env 2>/dev/null || true
set +a

# Собираем образ
echo "Сборка Docker образа..."
if docker-compose build --no-cache digroup 2>/dev/null || docker compose build --no-cache digroup 2>/dev/null; then
    echo "[OK] Образ собран"
else
    echo "❌ Ошибка при сборке образа"
    exit 1
fi
echo ""

# Запускаем контейнеры
echo "Запуск контейнеров..."
if docker-compose up -d 2>/dev/null || docker compose up -d 2>/dev/null; then
    echo "[OK] Контейнеры запущены"
else
    echo "❌ Ошибка при запуске контейнеров"
    exit 1
fi
echo ""

# Шаг 7: Ожидание запуска сервиса
echo "⏳ ШАГ 7: Ожидание запуска сервиса..."
MAX_ATTEMPTS=60
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
    echo "⚠️  Сервис не отвечает, проверьте логи: docker-compose logs -f"
fi
echo ""

# Шаг 8: Настройка автоматических бэкапов (опционально)
echo "💾 ШАГ 8: Настройка автоматических бэкапов..."
read -p "Настроить автоматические ежедневные бэкапы? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./setup-backup.sh
    echo "[OK] Автоматические бэкапы настроены"
else
    echo "[OK] Пропущено (можно настроить позже: ./setup-backup.sh)"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ УСТАНОВКА ЗАВЕРШЕНА!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Доступные сервисы:"
echo "   • DIGroup:    http://localhost:${PORT:-6806}"
echo "   • Grafana:    http://localhost:3000"
echo "   • Prometheus: http://localhost:9090"
echo ""
echo "🔑 Код доступа: ${ACCESS_AUTH_CODE:-см. .env}"
echo ""
echo "📝 Управление:"
echo "   • Логи:       docker-compose logs -f"
echo "   • Остановка:  docker-compose down"
echo "   • Перезапуск: docker-compose restart"
echo "   • Статус:     docker-compose ps"
echo ""
echo "📚 Документация:"
echo "   • README.md - Основная документация"
echo "   • DEPLOYMENT.md - Развертывание"
echo "   • ИНСТРУКЦИЯ.md - Руководство пользователя"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
