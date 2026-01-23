#!/bin/bash
# Проверка статуса установки на сервере
# Использование: ./check-server-status.sh

SERVER_IP="85.198.99.150"
SERVER_USER="root"
SERVER_PASSWORD="!K5kUHw6Hc0%"
INSTALL_DIR="/opt/digroup"

sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$SERVER_USER@$SERVER_IP" << 'REMOTE_CHECK'
cd /opt/digroup

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 СТАТУС УСТАНОВКИ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "🐳 Статус Docker контейнеров:"
docker compose ps
echo ""

echo "📝 Последние 30 строк логов digroup:"
docker compose logs --tail=30 digroup 2>/dev/null | tail -30
echo ""

echo "🌐 Проверка доступности сервиса:"
if curl -f -s http://localhost:6806/api/system/version > /dev/null 2>&1; then
    VERSION=$(curl -s http://localhost:6806/api/system/version 2>/dev/null | grep -o '"data":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    echo "✅ Сервис доступен! Версия: $VERSION"
    echo "   URL: http://85.198.99.150:6806"
else
    echo "⚠️  Сервис еще не отвечает"
    echo "   Проверьте логи: docker compose logs -f digroup"
fi
echo ""

echo "💾 Использование диска:"
df -h / | tail -1
echo ""

echo "🔧 Процессы сборки Docker:"
ps aux | grep -E "docker|build" | grep -v grep | head -5
REMOTE_CHECK
