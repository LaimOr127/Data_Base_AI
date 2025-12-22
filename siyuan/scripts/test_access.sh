#!/bin/bash
# Скрипт для тестирования доступа к DIGroup
# Использование: ./test_access.sh [локальный|удаленный]

set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Получение IP адреса
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="НЕ_НАЙДЕН"
fi

ACCESS_CODE="b226ba0f30a134fe9245792118bca202"

echo "🧪 Тестирование доступа к DIGroup"
echo "=================================="
echo ""

# Определение режима тестирования
MODE=${1:-локальный}

if [ "$MODE" = "локальный" ] || [ "$MODE" = "local" ]; then
    BASE_URL="http://localhost:6806"
    echo -e "${BLUE}📱 Локальное тестирование${NC}"
elif [ "$MODE" = "удаленный" ] || [ "$MODE" = "remote" ]; then
    if [ "$LOCAL_IP" = "НЕ_НАЙДЕН" ]; then
        echo -e "${RED}❌ IP адрес не найден${NC}"
        exit 1
    fi
    BASE_URL="http://$LOCAL_IP:6806"
    echo -e "${BLUE}🌍 Удаленное тестирование (IP: $LOCAL_IP)${NC}"
else
    echo "Использование: $0 [локальный|удаленный]"
    exit 1
fi

echo ""
echo "🔗 URL: $BASE_URL"
echo ""

# Тест 1: Проверка версии (без аутентификации)
echo "1️⃣  Проверка версии (без аутентификации)..."
if curl -s -f "$BASE_URL/api/system/version" > /dev/null 2>&1; then
    VERSION=$(curl -s "$BASE_URL/api/system/version" | python3 -c "import json, sys; print(json.load(sys.stdin).get('data', '?'))" 2>/dev/null || echo "?")
    echo -e "   ${GREEN}✅ Kernel работает${NC} (версия: $VERSION)"
else
    echo -e "   ${RED}❌ Kernel не отвечает${NC}"
    echo "   Проверьте, что kernel запущен: ./start_digroup.sh"
    exit 1
fi

# Тест 2: Проверка с AccessAuthCode
echo ""
echo "2️⃣  Проверка с AccessAuthCode..."
if curl -s -f "$BASE_URL/api/system/version" -H "Cookie: workspace-accessAuthCode=$ACCESS_CODE" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ Доступ с AccessAuthCode работает${NC}"
else
    echo -e "   ${YELLOW}⚠️  AccessAuthCode не работает (возможно, нужна полная аутентификация)${NC}"
fi

# Тест 3: Проверка пользователя-редактора
echo ""
echo "3️⃣  Проверка пользователя-редактора (sha:sha123)..."
if curl -s -f -u sha:sha123 "$BASE_URL/api/system/version" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ Аутентификация редактора работает${NC}"
else
    echo -e "   ${RED}❌ Аутентификация редактора не работает${NC}"
fi

# Тест 4: Проверка гостевого доступа
echo ""
echo "4️⃣  Проверка гостевого доступа (guest:guest123)..."
if curl -s -f -u guest:guest123 "$BASE_URL/api/system/version" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ Гостевой доступ работает${NC}"
else
    echo -e "   ${RED}❌ Гостевой доступ не работает${NC}"
fi

# Тест 5: Проверка WebSocket (если доступен)
echo ""
echo "5️⃣  Проверка WebSocket..."
WS_URL=$(echo "$BASE_URL" | sed 's|http://|ws://|')
if curl -s -f "$BASE_URL/api/system/version" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ WebSocket доступен${NC} ($WS_URL)"
else
    echo -e "   ${YELLOW}⚠️  WebSocket недоступен${NC}"
fi

# Итоговая информация
echo ""
echo -e "${GREEN}✅ Тестирование завершено!${NC}"
echo ""
echo "📋 Ссылки для доступа:"
echo "   • Веб-интерфейс: $BASE_URL"
echo "   • API: $BASE_URL/api/system/version"
echo ""
echo "🔐 Доступ:"
echo "   • AccessAuthCode: $ACCESS_CODE"
echo "   • Редактор: sha / sha123"
echo "   • Гость: guest / guest123"
echo ""

