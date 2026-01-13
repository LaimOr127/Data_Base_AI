package audit

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/supabase-community/supabase-go"
)

// AuditLogger - логгер для аудита действий в Supabase
type AuditLogger struct {
	client *supabase.Client
	table  string
}

// AuditEvent - событие аудита
type AuditEvent struct {
	UserID     string                 `json:"user_id"`
	Username   string                 `json:"username"`
	Action     string                 `json:"action"`   // login, logout, create, update, delete, view
	Resource   string                 `json:"resource"` // document, block, workspace
	ResourceID string                 `json:"resource_id"`
	IPAddress  string                 `json:"ip_address"`
	UserAgent  string                 `json:"user_agent"`
	Details    map[string]interface{} `json:"details"`
	Timestamp  time.Time              `json:"timestamp"`
	SessionID  string                 `json:"session_id"`
}

// NewAuditLogger создает новый логгер аудита
func NewAuditLogger(supabaseURL, supabaseKey, tableName string) (*AuditLogger, error) {
	client, err := supabase.NewClient(supabaseURL, supabaseKey, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create supabase client: %w", err)
	}

	return &AuditLogger{
		client: client,
		table:  tableName,
	}, nil
}

// LogEvent логирует событие аудита
func (a *AuditLogger) LogEvent(ctx context.Context, event AuditEvent) error {
	if event.Timestamp.IsZero() {
		event.Timestamp = time.Now()
	}

	// Преобразуем в JSON для Supabase
	eventJSON, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("failed to marshal event: %w", err)
	}

	var eventMap map[string]interface{}
	if err := json.Unmarshal(eventJSON, &eventMap); err != nil {
		return fmt.Errorf("failed to unmarshal event: %w", err)
	}

	// Вставляем в Supabase
	_, _, err = a.client.From(a.table).Insert(eventMap, false, "", "", "").Execute()
	if err != nil {
		return fmt.Errorf("failed to insert audit event: %w", err)
	}

	return nil
}

// LogLogin логирует вход пользователя
func (a *AuditLogger) LogLogin(ctx context.Context, userID, username, ipAddress, userAgent, sessionID string) error {
	return a.LogEvent(ctx, AuditEvent{
		UserID:    userID,
		Username:  username,
		Action:    "login",
		IPAddress: ipAddress,
		UserAgent: userAgent,
		SessionID: sessionID,
		Details: map[string]interface{}{
			"login_time": time.Now().Format(time.RFC3339),
		},
	})
}

// LogLogout логирует выход пользователя
func (a *AuditLogger) LogLogout(ctx context.Context, userID, username, sessionID string) error {
	return a.LogEvent(ctx, AuditEvent{
		UserID:    userID,
		Username:  username,
		Action:    "logout",
		SessionID: sessionID,
		Details: map[string]interface{}{
			"logout_time": time.Now().Format(time.RFC3339),
		},
	})
}

// LogDocumentAction логирует действие с документом
func (a *AuditLogger) LogDocumentAction(ctx context.Context, userID, username, action, documentID, ipAddress string, details map[string]interface{}) error {
	return a.LogEvent(ctx, AuditEvent{
		UserID:     userID,
		Username:   username,
		Action:     action,
		Resource:   "document",
		ResourceID: documentID,
		IPAddress:  ipAddress,
		Details:    details,
	})
}

// LogBlockAction логирует действие с блоком
func (a *AuditLogger) LogBlockAction(ctx context.Context, userID, username, action, blockID, ipAddress string, details map[string]interface{}) error {
	return a.LogEvent(ctx, AuditEvent{
		UserID:     userID,
		Username:   username,
		Action:     action,
		Resource:   "block",
		ResourceID: blockID,
		IPAddress:  ipAddress,
		Details:    details,
	})
}

// GetUserActivity получает активность пользователя
func (a *AuditLogger) GetUserActivity(ctx context.Context, userID string, from, to time.Time) ([]AuditEvent, error) {
	query := a.client.From(a.table).
		Select("*", "", false).
		Eq("user_id", userID).
		Gte("timestamp", from.Format(time.RFC3339)).
		Lte("timestamp", to.Format(time.RFC3339)).
		Order("timestamp", false)

	var events []AuditEvent
	_, err := query.ExecuteTo(&events)
	if err != nil {
		return nil, fmt.Errorf("failed to get user activity: %w", err)
	}

	return events, nil
}

// GetRecentActions получает последние действия
func (a *AuditLogger) GetRecentActions(ctx context.Context, limit int) ([]AuditEvent, error) {
	query := a.client.From(a.table).
		Select("*", "", false).
		Order("timestamp", false).
		Limit(limit)

	var events []AuditEvent
	_, err := query.ExecuteTo(&events)
	if err != nil {
		return nil, fmt.Errorf("failed to get recent actions: %w", err)
	}

	return events, nil
}
