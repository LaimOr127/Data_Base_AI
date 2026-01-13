# 🚀 Полное руководство по развертыванию DIGroup

Включает развертывание приложения, мониторинга (Prometheus + Grafana) и системы аудита (Supabase).

## 📋 Содержание

1. [Требования к серверу](#требования-к-серверу)
2. [Развертывание DIGroup](#развертывание-digroup)
3. [Настройка мониторинга](#настройка-мониторинга)
4. [Настройка аудита в Supabase](#настройка-аудита-в-supabase)
5. [Интеграция всех компонентов](#интеграция-всех-компонентов)

---

## 🖥️ Требования к серверу

### Минимальные (до 20 пользователей):
- **CPU:** 4 ядра
- **RAM:** 8 GB
- **Диск:** SSD, 50+ GB
- **ОС:** Ubuntu 20.04+ / Debian 11+

### Рекомендуемые (50+ пользователей):
- **CPU:** 8+ ядер
- **RAM:** 16+ GB
- **Диск:** SSD, 100+ GB
- **Сеть:** стабильное соединение, 50+ Мбит/с

### ⚠️ Важно: VPS вместо виртуального хостинга

Для полноценной работы с мониторингом **необходим VPS**, так как:
- Виртуальный хостинг не поддерживает Docker
- Нужен полный контроль для Prometheus + Grafana
- VPS дешевле или сопоставим по цене (300-600₽/мес)

**Рекомендуемые провайдеры VPS:**
- Timeweb VPS: от 300₽/месяц
- Selectel: от 400₽/месяц
- DigitalOcean: от $6/месяц

---

## 🚀 Развертывание DIGroup

### Шаг 1: Подготовка сервера

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка Docker
sudo apt install -y docker.io docker-compose
sudo systemctl enable docker
sudo systemctl start docker
```

### Шаг 2: Клонирование проекта

```bash
git clone git@github.com:LaimOr127/Data_Base_AI.git /opt/digroup
cd /opt/digroup
```

### Шаг 3: Автоматическая настройка

```bash
sudo ./deploy/scripts/setup.sh
```

### Шаг 4: Настройка переменных окружения

```bash
cp .env.example .env
nano .env
```

Установите:
```env
ACCESS_AUTH_CODE=ваш_сложный_секретный_код_минимум_16_символов
TZ=Europe/Moscow
```

### Шаг 5: Запуск DIGroup

```bash
cd /opt/digroup
docker-compose up -d
```

### Шаг 6: Проверка

```bash
# Проверка статуса
docker-compose ps

# Проверка API
curl http://127.0.0.1:6806/api/system/version

# Логи
docker-compose logs -f
```

---

## 📊 Настройка мониторинга

### Шаг 1: Настройка переменных окружения

```bash
cd /opt/digroup/deploy/monitoring
cat > .env << EOF
GRAFANA_PASSWORD=ваш_безопасный_пароль
EOF
```

### Шаг 2: Запуск мониторинга

```bash
docker-compose -f docker-compose.monitoring.yml up -d
```

### Шаг 3: Настройка Nginx для внешнего доступа

Добавьте в `/etc/nginx/sites-available/digroup`:

```nginx
# Grafana
location /grafana/ {
    proxy_pass http://127.0.0.1:3000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

# Prometheus (защитите паролем!)
location /prometheus/ {
    proxy_pass http://127.0.0.1:9090/;
    auth_basic "Prometheus Access";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

Создайте пароль для Prometheus:

```bash
sudo apt install -y apache2-utils
sudo htpasswd -c /etc/nginx/.htpasswd prometheus_user
```

Перезагрузите Nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### Шаг 4: Доступ к интерфейсам

- **Grafana:** `http://ваш-сервер/grafana/`
  - Логин: `admin`
  - Пароль: из `.env` файла
- **Prometheus:** `http://ваш-сервер/prometheus/`
  - Логин: `prometheus_user`
  - Пароль: установленный через htpasswd

---

## 🔍 Настройка аудита в Supabase

### Шаг 1: Создание проекта в Supabase

1. Перейдите на https://supabase.com
2. Создайте новый проект
3. Запишите:
   - **Project URL:** `https://xxxxx.supabase.co`
   - **API Key (anon/public):** `eyJhbGc...`

### Шаг 2: Создание таблиц

1. Откройте SQL Editor в Supabase
2. Выполните SQL из `deploy/audit/supabase-setup.sql`

Или через psql:

```bash
psql -h db.xxxxx.supabase.co -U postgres -d postgres \
  -f /opt/digroup/deploy/audit/supabase-setup.sql
```

### Шаг 3: Настройка переменных окружения

Добавьте в `/opt/digroup/.env`:

```env
# Supabase конфигурация
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_KEY=your-anon-key-here
SUPABASE_AUDIT_TABLE=audit_logs
```

### Шаг 4: Интеграция в DIGroup kernel

Добавьте зависимость в `kernel/go.mod`:

```go
require github.com/supabase-community/supabase-go v0.0.0-20231214171723-4b0b0c5e5c3e
```

Импортируйте и используйте в коде (см. `deploy/audit/README.md`).

---

## 🔗 Интеграция всех компонентов

### Общая структура

```
┌─────────────────┐
│   Nginx (80/443)│
└────────┬────────┘
         │
    ┌────┴────┬──────────────┬─────────────┐
    │         │              │             │
┌───▼───┐ ┌──▼────────┐ ┌───▼────┐ ┌──────▼──────┐
│DIGroup│ │ Grafana   │ │Promethe│ │  Supabase   │
│Kernel │ │ :3000     │ │us :9090│ │  (внешний)  │
│ :6806 │ └──────────┘ └────────┘ └─────────────┘
└───────┘
```

### Обновленный docker-compose.yml

Создайте `/opt/digroup/docker-compose.full.yml`:

```yaml
version: '3.8'

services:
  digroup:
    # ... (существующая конфигурация)
    environment:
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_KEY=${SUPABASE_KEY}
      - SUPABASE_AUDIT_TABLE=${SUPABASE_AUDIT_TABLE}

  prometheus:
    # ... (из docker-compose.monitoring.yml)

  grafana:
    # ... (из docker-compose.monitoring.yml)

  node-exporter:
    # ... (из docker-compose.monitoring.yml)
```

### Запуск всего стека

```bash
cd /opt/digroup
docker-compose -f docker-compose.yml -f deploy/monitoring/docker-compose.monitoring.yml up -d
```

---

## 📊 Мониторинг и дашборды

### Доступные дашборды

1. **DIGroup Overview** - общая статистика
2. **System Metrics** - CPU, RAM, Disk
3. **Application Metrics** - WebSocket, HTTP requests
4. **User Activity** - активность пользователей (из Supabase)

### Создание дашборда активности пользователей

В Grafana создайте новый дашборд с запросами к Supabase через API:

```json
{
  "targets": [
    {
      "type": "table",
      "query": "SELECT username, COUNT(*) as actions FROM audit_logs WHERE timestamp > NOW() - INTERVAL '24 hours' GROUP BY username"
    }
  ]
}
```

---

## 🔐 Безопасность

### Рекомендации:

1. **Измените все пароли по умолчанию**
2. **Настройте HTTPS** через Let's Encrypt
3. **Ограничьте доступ к Prometheus** (только через Nginx с паролем)
4. **Настройте RLS в Supabase** для ограничения доступа к логам
5. **Регулярно обновляйте** все компоненты
6. **Настройте бэкапы** всех данных

---

## 📝 Чек-лист развертывания

- [ ] VPS сервер настроен
- [ ] Docker и Docker Compose установлены
- [ ] DIGroup запущен и работает
- [ ] Nginx настроен и работает
- [ ] Prometheus запущен и собирает метрики
- [ ] Grafana запущен и показывает дашборды
- [ ] Supabase проект создан
- [ ] Таблицы аудита созданы в Supabase
- [ ] Переменные окружения настроены
- [ ] Интеграция аудита в kernel добавлена
- [ ] SSL сертификат установлен (если есть домен)
- [ ] Бэкапы настроены
- [ ] Мониторинг доступен извне
- [ ] Все пароли изменены

---

## 🛠️ Устранение неполадок

### Проблема: Prometheus не собирает метрики

```bash
# Проверьте targets
curl http://localhost:9090/api/v1/targets

# Проверьте логи
docker logs prometheus
```

### Проблема: Grafana не подключается к Prometheus

1. Проверьте Data Source в Grafana
2. Проверьте доступность Prometheus: `curl http://localhost:9090`
3. Проверьте сеть Docker: `docker network ls`

### Проблема: Логи не записываются в Supabase

1. Проверьте переменные окружения
2. Проверьте подключение: `curl https://xxxxx.supabase.co/rest/v1/`
3. Проверьте права доступа к таблице
4. Проверьте логи kernel

---

## 📚 Дополнительная документация

- [Руководство по развертыванию](DEPLOYMENT.md)
- [Мониторинг](deploy/monitoring/README.md)
- [Система аудита](deploy/audit/README.md)
- [Настройка для команды](siyuan/TEAM_DEPLOYMENT.md)

---

**Готово! Ваша система полностью развернута с мониторингом и аудитом! 🎉**

