#!/bin/bash
# Настройка Telegram бота для уведомлений

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🤖 Настройка Telegram бота для уведомлений${NC}"
echo "=========================================="
echo ""

# Инструкции
echo -e "${YELLOW}Для настройки Telegram бота:${NC}"
echo ""
echo "1. Создайте бота через @BotFather в Telegram:"
echo "   - Откройте @BotFather"
echo "   - Отправьте /newbot"
echo "   - Следуйте инструкциям"
echo "   - Сохраните токен бота"
echo ""
echo "2. Получите Chat ID:"
echo "   - Напишите боту любое сообщение"
echo "   - Откройте: https://api.telegram.org/bot<ВАШ_ТОКЕН>/getUpdates"
echo "   - Найдите 'chat':{'id':123456789}"
echo "   - Сохраните этот ID"
echo ""

read -p "Введите токен бота: " BOT_TOKEN
read -p "Введите Chat ID: " CHAT_ID

# Добавление в .env
ENV_FILE="/opt/digroup/.env"

if [ -f "$ENV_FILE" ]; then
    # Удаляем старые значения если есть
    sed -i '/^TELEGRAM_BOT_TOKEN=/d' "$ENV_FILE"
    sed -i '/^TELEGRAM_CHAT_ID=/d' "$ENV_FILE"
    
    # Добавляем новые
    echo "" >> "$ENV_FILE"
    echo "# Telegram уведомления" >> "$ENV_FILE"
    echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN" >> "$ENV_FILE"
    echo "TELEGRAM_CHAT_ID=$CHAT_ID" >> "$ENV_FILE"
    
    echo -e "${GREEN}✅ Настройки добавлены в .env${NC}"
else
    echo -e "${YELLOW}⚠️  Файл .env не найден, создайте его вручную${NC}"
    echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN"
    echo "TELEGRAM_CHAT_ID=$CHAT_ID"
fi

# Тестовое сообщение
echo ""
read -p "Отправить тестовое сообщение? (yes/no): " SEND_TEST

if [ "$SEND_TEST" = "yes" ]; then
    curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=✅ Telegram бот настроен успешно! Уведомления DIGroup будут приходить сюда." \
        -d "parse_mode=HTML" > /dev/null
    
    echo -e "${GREEN}✅ Тестовое сообщение отправлено!${NC}"
fi

echo ""
echo -e "${GREEN}✅ Настройка завершена!${NC}"
echo ""
echo "Теперь уведомления будут отправляться в Telegram при:"
echo "  - Критических ошибках"
echo "  - Высоком использовании ресурсов"
echo "  - Завершении бэкапов"
echo "  - Изменении статуса системы"

