#!/bin/bash
# Скрипт настройки автозапуска DIGroup через systemd
# Только для Linux
# Использование: sudo ./setup-systemd.sh

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Ошибка: Запустите от root (sudo ./setup-systemd.sh)"
    exit 1
fi

echo "=========================================="
echo " Настройка автозапуска DIGroup"
echo "=========================================="
echo ""

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER="${SUDO_USER:-$USER}"

echo "Директория: $INSTALL_DIR"
echo "Пользователь: $CURRENT_USER"
echo ""

# Создание systemd service
SERVICE_FILE="/etc/systemd/system/digroup.service"

echo "Создание systemd service..."

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=DIGroup Knowledge Base
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
User=$CURRENT_USER
Group=$CURRENT_USER

ExecStart=/usr/bin/docker-compose -f $INSTALL_DIR/docker-compose.yml up -d
ExecStop=/usr/bin/docker-compose -f $INSTALL_DIR/docker-compose.yml down

Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "[OK] Service файл создан"
echo ""

# Перезагрузка systemd
echo "Перезагрузка systemd..."
systemctl daemon-reload
echo "[OK] Daemon перезагружен"
echo ""

# Включение автозапуска
echo "Включение автозапуска..."
systemctl enable digroup.service
echo "[OK] Автозапуск включен"
echo ""

# Запуск сервиса
echo "Запуск сервиса..."
systemctl start digroup.service
echo "[OK] Сервис запущен"
echo ""

# Проверка статуса
sleep 3
systemctl status digroup.service --no-pager || true

echo ""
echo "=========================================="
echo " Автозапуск настроен"
echo "=========================================="
echo ""
echo "Команды управления:"
echo "  Статус:     sudo systemctl status digroup"
echo "  Запуск:     sudo systemctl start digroup"
echo "  Остановка:  sudo systemctl stop digroup"
echo "  Перезапуск: sudo systemctl restart digroup"
echo "  Логи:       sudo journalctl -u digroup -f"
echo ""
