#!/bin/bash
# Скрипт для остановки DIGroup
# Использование: ./stop_digroup.sh

echo "🛑 Остановка DIGroup..."
echo ""

# Остановка процессов
pkill -f "SiYuan-Kernel" && echo "✅ Kernel остановлен" || echo "⚠️  Kernel не был запущен"
pkill -f "electron.*main.js" && echo "✅ Electron остановлен" || echo "⚠️  Electron не был запущен"

sleep 2

# Проверка
if pgrep -f "SiYuan-Kernel" > /dev/null || pgrep -f "electron.*main.js" > /dev/null; then
    echo ""
    echo "⚠️  Некоторые процессы все еще запущены:"
    ps aux | grep -E "(SiYuan-Kernel|electron.*main.js)" | grep -v grep
    echo ""
    echo "Принудительная остановка..."
    pkill -9 -f "SiYuan-Kernel" 2>/dev/null || true
    pkill -9 -f "electron.*main.js" 2>/dev/null || true
    sleep 1
fi

echo ""
echo "✅ DIGroup остановлен"

