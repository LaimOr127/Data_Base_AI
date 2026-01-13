# 🔍 Система аудита действий пользователей

Интеграция с Supabase для логирования всех действий сотрудников в DIGroup.

## 📋 Возможности

- ✅ Логирование входов/выходов пользователей
- ✅ Отслеживание действий с документами (создание, изменение, удаление)
- ✅ Отслеживание действий с блоками
- ✅ Хранение IP адресов и User-Agent
- ✅ Статистика активности пользователей
- ✅ История сессий
- ✅ Поиск по времени, пользователю, действию

## 🚀 Настройка Supabase

### 1. Создайте проект в Supabase

1. Перейдите на https://supabase.com
2. Создайте новый проект
3. Запишите:
   - Project URL (например: `https://xxxxx.supabase.co`)
   - API Key (anon/public key)

### 2. Создайте таблицы

Выполните SQL скрипт в Supabase SQL Editor:

```sql
-- Скопируйте содержимое из supabase-setup.sql
```

Или выполните через psql:

```bash
psql -h db.xxxxx.supabase.co -U postgres -d postgres -f supabase-setup.sql
```

### 3. Настройте переменные окружения

Добавьте в `.env`:

```env
# Supabase конфигурация
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_KEY=your-anon-key
SUPABASE_AUDIT_TABLE=audit_logs
```

## 🔧 Интеграция в DIGroup

### Добавление в kernel

1. Добавьте зависимость в `kernel/go.mod`:

```go
require github.com/supabase-community/supabase-go v0.0.0-20231214171723-4b0b0c5e5c3e
```

2. Импортируйте в нужных местах:

```go
import "github.com/your-project/audit"
```

3. Инициализируйте логгер:

```go
auditLogger, err := audit.NewAuditLogger(
    os.Getenv("SUPABASE_URL"),
    os.Getenv("SUPABASE_KEY"),
    os.Getenv("SUPABASE_AUDIT_TABLE"),
)
```

### Примеры использования

#### Логирование входа

```go
auditLogger.LogLogin(ctx, userID, username, ipAddress, userAgent, sessionID)
```

#### Логирование действия с документом

```go
auditLogger.LogDocumentAction(ctx, userID, username, "update", documentID, ipAddress, map[string]interface{}{
    "old_title": oldTitle,
    "new_title": newTitle,
})
```

#### Логирование действия с блоком

```go
auditLogger.LogBlockAction(ctx, userID, username, "delete", blockID, ipAddress, map[string]interface{}{
    "block_type": blockType,
    "content": content,
})
```

## 📊 Запросы к данным

### Получить активность пользователя

```sql
SELECT * FROM audit_logs
WHERE user_id = 'user123'
  AND timestamp >= NOW() - INTERVAL '7 days'
ORDER BY timestamp DESC;
```

### Статистика активности

```sql
SELECT * FROM user_activity_stats
WHERE user_id = 'user123';
```

### Последние действия

```sql
SELECT * FROM audit_logs
ORDER BY timestamp DESC
LIMIT 100;
```

### Активные сессии

```sql
SELECT * FROM user_sessions
WHERE is_active = TRUE;
```

## 🔐 Безопасность

1. **RLS (Row Level Security)** - включен по умолчанию
2. **API Key** - храните в переменных окружения, не коммитьте в репозиторий
3. **Ограничение доступа** - настройте политики RLS в Supabase для ограничения доступа

## 📈 Мониторинг

Интегрируйте метрики в Prometheus:

```go
// Пример метрики
auditActionsTotal := prometheus.NewCounterVec(
    prometheus.CounterOpts{
        Name: "digroup_audit_actions_total",
        Help: "Total number of audit actions",
    },
    []string{"user_id", "action", "resource"},
)
```

## 🛠️ Устранение неполадок

### Проблема: Логи не записываются

1. Проверьте переменные окружения
2. Проверьте подключение к Supabase: `curl https://xxxxx.supabase.co/rest/v1/`
3. Проверьте права доступа к таблице
4. Проверьте логи приложения

### Проблема: Медленные запросы

1. Убедитесь, что индексы созданы
2. Используйте ограничения по времени в запросах
3. Рассмотрите партиционирование таблицы по времени

