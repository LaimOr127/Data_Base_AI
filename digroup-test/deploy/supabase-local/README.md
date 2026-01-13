# 🏠 Локальный Supabase для аудита

Локальное развертывание Supabase на том же сервере для аудита действий пользователей.

## 🎯 Преимущества локального Supabase

✅ **Полный контроль** - все данные на вашем сервере  
✅ **Без интернета** - работает без внешних зависимостей  
✅ **Бесплатно** - нет лимитов облачного сервиса  
✅ **Быстро** - нет задержек на сеть  
✅ **Безопасно** - данные не покидают сервер  

## 🚀 Быстрая установка

### Автоматическая установка

```bash
sudo ./deploy/supabase-local/setup-local-supabase.sh
```

Скрипт автоматически:
- ✅ Установит и запустит Supabase в Docker
- ✅ Сгенерирует безопасные пароли
- ✅ Создаст все необходимые таблицы
- ✅ Настроит права доступа
- ✅ Обновит .env файл

### Интеграция в auto-install.sh

При запуске основной установки выберите "Локальный Supabase":

```bash
sudo ./deploy/scripts/auto-install.sh
# В процессе установки выберите вариант 1 (локальный)
```

## 📊 Компоненты

Локальный Supabase включает:

1. **PostgreSQL** - база данных (порт 54322)
2. **PostgREST** - REST API (порт 3001)
3. **GoTrue** - аутентификация (порт 9999, опционально)

## 🔧 Управление

### Запуск

```bash
cd /opt/digroup/deploy/supabase-local
docker-compose -f docker-compose.supabase.yml up -d
```

### Остановка

```bash
cd /opt/digroup/deploy/supabase-local
docker-compose -f docker-compose.supabase.yml down
```

### Просмотр логов

```bash
docker-compose -f docker-compose.supabase.yml logs -f
```

### Перезапуск

```bash
docker-compose -f docker-compose.supabase.yml restart
```

## 💾 Бэкап базы данных

```bash
# Создание бэкапа
docker exec supabase-db pg_dump -U supabase_admin postgres > backup.sql

# Восстановление
docker exec -i supabase-db psql -U supabase_admin postgres < backup.sql
```

## 🔍 Доступ к базе данных

### Через psql

```bash
docker exec -it supabase-db psql -U supabase_admin -d postgres
```

### Через REST API

```bash
# Получение данных
curl http://127.0.0.1:3001/rest/v1/audit_logs \
  -H "apikey: YOUR_JWT_SECRET" \
  -H "Authorization: Bearer YOUR_JWT_SECRET"
```

## 📋 Конфигурация

Все настройки хранятся в:
- `/opt/digroup/deploy/supabase-local/.env` - пароли и секреты
- `/opt/digroup/.env` - URL и ключи для приложения

### Переменные окружения

```env
POSTGRES_PASSWORD=your-password
JWT_SECRET=your-jwt-secret
JWT_EXP=3600
```

## 🔐 Безопасность

1. **Пароли генерируются автоматически** при установке
2. **Доступ только локальный** - порты не открыты наружу
3. **Данные в Docker volume** - изолированы от системы
4. **Регулярные бэкапы** - настройте через cron

## 📊 Использование ресурсов

Примерное использование:
- **RAM:** ~200-500 MB
- **Диск:** зависит от объема данных
- **CPU:** минимальное

## 🛠️ Устранение неполадок

### Проблема: Контейнер не запускается

```bash
# Проверьте логи
docker-compose -f docker-compose.supabase.yml logs

# Проверьте порты
netstat -tlnp | grep -E "54322|3001"
```

### Проблема: Не удается подключиться

```bash
# Проверьте статус контейнеров
docker ps | grep supabase

# Проверьте здоровье БД
docker exec supabase-db pg_isready -U supabase_admin
```

### Проблема: SQL не выполняется

```bash
# Выполните вручную
docker exec -i supabase-db psql -U supabase_admin -d postgres < /path/to/sql/file
```

## 🔄 Миграция с облачного Supabase

Если у вас уже есть облачный Supabase:

1. Экспортируйте данные:
```bash
# Из облачного Supabase
pg_dump -h db.xxxxx.supabase.co -U postgres -d postgres > cloud_backup.sql
```

2. Импортируйте в локальный:
```bash
docker exec -i supabase-db psql -U supabase_admin -d postgres < cloud_backup.sql
```

3. Обновите .env файл с новым URL

## 📈 Мониторинг

Добавьте метрики в Prometheus:

```yaml
# В prometheus.yml
- job_name: 'supabase-postgres'
  static_configs:
    - targets: ['supabase-db:5432']
```

## 🎯 Сравнение: Локальный vs Облачный

| Параметр | Локальный | Облачный |
|----------|-----------|----------|
| Контроль данных | ✅ Полный | ⚠️ Ограниченный |
| Зависимость от интернета | ❌ Нет | ✅ Да |
| Стоимость | ✅ Бесплатно | ⚠️ Может быть платно |
| Скорость | ✅ Быстро | ⚠️ Зависит от сети |
| Масштабирование | ⚠️ Ограничено сервером | ✅ Автоматическое |
| Бэкапы | ⚠️ Нужно настраивать | ✅ Автоматические |

## 📚 Дополнительная информация

- [Официальная документация Supabase](https://supabase.com/docs/guides/self-hosting)
- [Docker Compose Supabase](https://github.com/supabase/supabase/tree/master/docker)

