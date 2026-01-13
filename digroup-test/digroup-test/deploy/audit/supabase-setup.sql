-- SQL скрипт для создания таблицы аудита в Supabase

-- Таблица для логирования действий пользователей
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    username TEXT NOT NULL,
    action TEXT NOT NULL, -- login, logout, create, update, delete, view
    resource TEXT, -- document, block, workspace
    resource_id TEXT,
    ip_address TEXT,
    user_agent TEXT,
    details JSONB,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    session_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON audit_logs(resource);
CREATE INDEX IF NOT EXISTS idx_audit_logs_session_id ON audit_logs(session_id);

-- Индекс для поиска по времени и пользователю
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_timestamp ON audit_logs(user_id, timestamp DESC);

-- Таблица для сессий пользователей
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    username TEXT NOT NULL,
    session_id TEXT UNIQUE NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    login_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    logout_time TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Индексы для сессий
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_session_id ON user_sessions(session_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_active ON user_sessions(is_active) WHERE is_active = TRUE;

-- Представление для статистики активности пользователей
CREATE OR REPLACE VIEW user_activity_stats AS
SELECT 
    user_id,
    username,
    COUNT(*) as total_actions,
    COUNT(DISTINCT DATE(timestamp)) as active_days,
    MIN(timestamp) as first_action,
    MAX(timestamp) as last_action,
    COUNT(*) FILTER (WHERE action = 'login') as login_count,
    COUNT(*) FILTER (WHERE action = 'logout') as logout_count,
    COUNT(*) FILTER (WHERE action = 'create') as create_count,
    COUNT(*) FILTER (WHERE action = 'update') as update_count,
    COUNT(*) FILTER (WHERE action = 'delete') as delete_count
FROM audit_logs
GROUP BY user_id, username;

-- Функция для автоматического обновления logout_time при выходе
CREATE OR REPLACE FUNCTION update_session_logout()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.action = 'logout' AND OLD.action != 'logout' THEN
        UPDATE user_sessions
        SET logout_time = NEW.timestamp,
            is_active = FALSE
        WHERE session_id = NEW.session_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер для автоматического обновления сессий
CREATE TRIGGER trigger_update_session_logout
AFTER INSERT ON audit_logs
FOR EACH ROW
WHEN (NEW.action = 'logout')
EXECUTE FUNCTION update_session_logout();

-- RLS (Row Level Security) политики (опционально, для безопасности)
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- Политика: все могут читать свои логи (если нужно)
-- CREATE POLICY "Users can view their own logs" ON audit_logs
--     FOR SELECT USING (auth.uid()::text = user_id);

-- Политика: только сервис может вставлять логи
-- CREATE POLICY "Service can insert logs" ON audit_logs
--     FOR INSERT WITH CHECK (true);

