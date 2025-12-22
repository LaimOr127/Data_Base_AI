#!/bin/bash
# Диагностика системы входа и графа

echo "🔍 Диагностика системы входа и графа"
echo "====================================="
echo ""

BASE_URL="http://localhost:6806"

echo "1️⃣  Проверка kernel..."
if curl -s "$BASE_URL/api/system/version" > /dev/null 2>&1; then
    VERSION=$(curl -s "$BASE_URL/api/system/version" | python3 -c "import json, sys; print(json.load(sys.stdin).get('data', '?'))" 2>/dev/null || echo "?")
    echo "   ✅ Kernel работает (версия: $VERSION)"
else
    echo "   ❌ Kernel не отвечает"
    exit 1
fi
echo ""

echo "2️⃣  Проверка загрузки аккаунтов..."
if tail -100 /tmp/digroup-kernel.log 2>/dev/null | grep -q "Initialized.*accounts"; then
    ACCOUNT_COUNT=$(tail -100 /tmp/digroup-kernel.log 2>/dev/null | grep "Initialized.*accounts" | tail -1 | grep -oE "[0-9]+" | head -1)
    echo "   ✅ Аккаунты загружены: $ACCOUNT_COUNT"
else
    echo "   ⚠️  Не найдено сообщение о загрузке аккаунтов в логах"
fi
echo ""

echo "3️⃣  Тест входа с неверными данными..."
RESPONSE=$(curl -s -X POST "$BASE_URL/api/system/loginAuth" \
  -H "Content-Type: application/json" \
  -d '{"username":"wronguser","password":"wrongpass"}')
CODE=$(echo "$RESPONSE" | python3 -c "import json, sys; print(json.load(sys.stdin).get('code', '?'))" 2>/dev/null || echo "?")
if [ "$CODE" = "-1" ]; then
    echo "   ✅ Правильно отклонен (код: $CODE)"
else
    echo "   ❌ НЕПРАВИЛЬНО! Должен быть код -1, получен: $CODE"
    echo "   Ответ: $RESPONSE"
fi
echo ""

echo "4️⃣  Тест входа с правильными данными..."
RESPONSE=$(curl -s -X POST "$BASE_URL/api/system/loginAuth" \
  -H "Content-Type: application/json" \
  -d '{"username":"sha","password":"sha123"}')
CODE=$(echo "$RESPONSE" | python3 -c "import json, sys; print(json.load(sys.stdin).get('code', '?'))" 2>/dev/null || echo "?")
if [ "$CODE" = "0" ]; then
    echo "   ✅ Правильно принят (код: $CODE)"
    ROLE=$(echo "$RESPONSE" | python3 -c "import json, sys; print(json.load(sys.stdin).get('data', {}).get('role', '?'))" 2>/dev/null || echo "?")
    echo "   Роль: $ROLE"
else
    echo "   ⚠️  Код: $CODE (ожидался 0)"
    echo "   Ответ: $RESPONSE"
fi
echo ""

echo "5️⃣  Проверка доступа к API графа (без аутентификации)..."
RESPONSE=$(curl -s -X POST "$BASE_URL/api/graph/getGraph" \
  -H "Content-Type: application/json" \
  -d '{"k":"","conf":{"type":"d3","dailyNote":false,"minRefs":0},"reqId":1}')
CODE=$(echo "$RESPONSE" | python3 -c "import json, sys; print(json.load(sys.stdin).get('code', '?'))" 2>/dev/null || echo "?")
if [ "$CODE" = "-1" ]; then
    echo "   ✅ Правильно требует аутентификацию (код: $CODE)"
else
    echo "   ⚠️  Код: $CODE"
fi
echo ""

echo "6️⃣  Проверка доступа к API графа (с сессией после входа)..."
# Сначала входим
COOKIE=$(curl -s -c - -X POST "$BASE_URL/api/system/loginAuth" \
  -H "Content-Type: application/json" \
  -d '{"username":"sha","password":"sha123"}' | grep -i "sessionid\|workspace" | head -1 | awk '{print $NF}' || echo "")

if [ -n "$COOKIE" ]; then
    echo "   Сессия получена: ${COOKIE:0:20}..."
    RESPONSE=$(curl -s -X POST "$BASE_URL/api/graph/getGraph" \
      -H "Content-Type: application/json" \
      -b "$COOKIE" \
      -d '{"k":"","conf":{"type":"d3","dailyNote":false,"minRefs":0},"reqId":1}')
    CODE=$(echo "$RESPONSE" | python3 -c "import json, sys; print(json.load(sys.stdin).get('code', '?'))" 2>/dev/null || echo "?")
    if [ "$CODE" = "0" ]; then
        NODES=$(echo "$RESPONSE" | python3 -c "import json, sys; d=json.load(sys.stdin).get('data', {}); print(len(d.get('nodes', [])))" 2>/dev/null || echo "?")
        LINKS=$(echo "$RESPONSE" | python3 -c "import json, sys; d=json.load(sys.stdin).get('data', {}); print(len(d.get('links', [])))" 2>/dev/null || echo "?")
        echo "   ✅ Доступ разрешен (код: $CODE)"
        echo "   Узлов: $NODES, Связей: $LINKS"
    else
        echo "   ⚠️  Код: $CODE"
        echo "   Ответ: $RESPONSE"
    fi
else
    echo "   ⚠️  Не удалось получить сессию"
fi
echo ""

echo "7️⃣  Проверка базы данных..."
DB_FILE="$HOME/DIGroup-workspace/data/main.db"
if [ -f "$DB_FILE" ]; then
    BLOCK_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM blocks;" 2>/dev/null || echo "?")
    echo "   ✅ База данных найдена: $DB_FILE"
    echo "   Блоков в базе: $BLOCK_COUNT"
    if [ "$BLOCK_COUNT" = "0" ] || [ "$BLOCK_COUNT" = "?" ]; then
        echo "   ⚠️  База данных пуста - граф не будет отображаться"
    fi
else
    echo "   ⚠️  База данных не найдена: $DB_FILE"
fi
echo ""

echo "✅ Диагностика завершена!"
echo ""
echo "📝 Логи kernel:"
echo "   tail -f /tmp/digroup-kernel.log | grep -i 'login\|account\|graph\|auth'"

