package notifications

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// TelegramBot - бот для отправки уведомлений
type TelegramBot struct {
	botToken string
	chatID   string
	client   *http.Client
}

// NewTelegramBot создает новый Telegram бот
func NewTelegramBot(botToken, chatID string) *TelegramBot {
	return &TelegramBot{
		botToken: botToken,
		chatID:   chatID,
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// SendMessage отправляет сообщение в Telegram
func (tb *TelegramBot) SendMessage(text string) error {
	url := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", tb.botToken)

	payload := map[string]interface{}{
		"chat_id":    tb.chatID,
		"text":       text,
		"parse_mode": "HTML",
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal payload: %w", err)
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := tb.client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("telegram API returned status %d", resp.StatusCode)
	}

	return nil
}

// SendAlert отправляет алерт
func (tb *TelegramBot) SendAlert(severity, title, message string) error {
	emoji := map[string]string{
		"critical": "🔴",
		"warning":  "🟡",
		"info":     "ℹ️",
	}

	text := fmt.Sprintf(
		"%s <b>%s</b>\n\n%s\n\n<i>%s</i>",
		emoji[severity],
		title,
		message,
		time.Now().Format("2006-01-02 15:04:05"),
	)

	return tb.SendMessage(text)
}

// SendSystemStatus отправляет статус системы
func (tb *TelegramBot) SendSystemStatus(cpu, memory, disk float64, kernelStatus bool) error {
	status := "🟢 Работает"
	if !kernelStatus {
		status = "🔴 Недоступен"
	}

	text := fmt.Sprintf(
		"📊 <b>Статус DIGroup</b>\n\n"+
			"Kernel: %s\n"+
			"CPU: %.1f%%\n"+
			"Память: %.1f%%\n"+
			"Диск: %.1f%%\n\n"+
			"<i>%s</i>",
		status,
		cpu,
		memory,
		disk,
		time.Now().Format("2006-01-02 15:04:05"),
	)

	return tb.SendMessage(text)
}

// SendBackupStatus отправляет статус бэкапа
func (tb *TelegramBot) SendBackupStatus(success bool, size, duration string) error {
	status := "✅ Успешно"
	if !success {
		status = "❌ Ошибка"
	}

	text := fmt.Sprintf(
		"💾 <b>Бэкап DIGroup</b>\n\n"+
			"Статус: %s\n"+
			"Размер: %s\n"+
			"Время: %s\n\n"+
			"<i>%s</i>",
		status,
		size,
		duration,
		time.Now().Format("2006-01-02 15:04:05"),
	)

	return tb.SendMessage(text)
}
