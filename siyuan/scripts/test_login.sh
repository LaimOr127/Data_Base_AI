#!/bin/bash
# Скрипт для тестирования входа по логину/паролю

echo "🧪 Тестирование входа по логину/паролю"
echo "======================================"
echo ""

BASE_URL="http://localhost:6806"

echo "1️⃣  Тест с неверным логином..."
RESPONSE=$(curl -s -X POST "$BASE_URL/api/system/loginAuth" \
  -H "Content-Type: application/json" \
  -d '{"username":"wronguser","password":"wrongpass"}')
echo "Ответ: $RESPONSE"
CODE=$(echo "$RESPONSE" | python3 -c "import json, sys; print(json.load(sys.stdin).get('code', '?'))" 2>/dev/null || echo "?")
if [ "$CODE" = "-1" ]; then
    echo "✅ Правильно отклонен (код: $CODE)"
else
    echo "❌ НЕПРАВИЛЬНО! Должен быть код -1, получен: $CODE"
fi
echo ""

echo "2️⃣  Тест с неверным паролем..."
RESPONSE=$(curl -s -X POST "$BASE_URL/api/system/loginAuth" \
  -H "Content-Type: application/json" \
  -d '{"username":"sha","password":"wrongpass"}')
echo "Ответ: $RESPONSE"
CODE=$(echo "$RESPONSE" | python3 -c "import json, sys; print(json.load(sys.stdin).get('code', '?'))" 2>/dev/null || echo "?")
if [ "$CODE" = "-1" ]; then
    echo "✅ Правильно отклонен (код: $CODE)"
else
    echo "❌ НЕПРАВИЛЬНО! Должен быть код -1, получен: $CODE"
fi
echo ""

echo "3️⃣  Тест с правильным логином и паролем..."
RESPONSE=$(curl -s -X POST "$BASE_URL/api/system/loginAuth" \
  -H "Content-Type: application/json" \
  -d '{"username":"sha","password":"sha123"}')
echo "Ответ: $RESPONSE"
CODE=$(echo "$RESPONSE" | python3 -c "import json, sys; print(json.load(sys.stdin).get('code', '?'))" 2>/dev/null || echo "?")
if [ "$CODE" = "0" ]; then
    echo "✅ Правильно принят (код: $CODE)"
else
    echo "⚠️  Код: $CODE (ожидался 0 для правильного входа)"
fi
echo ""

echo "4️⃣  Тест с пустым логином..."
RESPONSE=$(curl -s -X POST "$BASE_URL/api/system/loginAuth" \
  -H "Content-Type: application/json" \
  -d '{"username":"","password":"test"}')
echo "Ответ: $RESPONSE"
CODE=$(echo "$RESPONSE" | python3 -c "import json, sys; print(json.load(sys.stdin).get('code', '?'))" 2>/dev/null || echo "?")
if [ "$CODE" = "-1" ]; then
    echo "✅ Правильно отклонен (код: $CODE)"
else
    echo "❌ НЕПРАВИЛЬНО! Должен быть код -1, получен: $CODE"
fi
echo ""

echo "✅ Тестирование завершено!"
echo ""
echo "📝 Проверьте логи kernel:"
echo "   tail -f /tmp/digroup-kernel.log | grep -i login"

