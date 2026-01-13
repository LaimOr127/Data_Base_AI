# 📊 Система мониторинга DIGroup

Prometheus + Grafana для мониторинга работы DIGroup.

## 🚀 Быстрый старт

### 1. Настройте переменные окружения

Создайте `.env` в директории `deploy/monitoring/`:

```env
GRAFANA_PASSWORD=your_secure_password
```

### 2. Запустите мониторинг

```bash
cd deploy/monitoring
docker-compose -f docker-compose.monitoring.yml up -d
```

### 3. Доступ к интерфейсам

- **Grafana:** http://localhost:3000
  - Логин: `admin`
  - Пароль: из `.env` файла
- **Prometheus:** http://localhost:9090

### 4. Настройте Nginx для внешнего доступа

Добавьте в конфигурацию Nginx:

```nginx
# Grafana
location /grafana/ {
    proxy_pass http://127.0.0.1:3000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}

# Prometheus (только для чтения, защитите паролем!)
location /prometheus/ {
    proxy_pass http://127.0.0.1:9090/;
    auth_basic "Prometheus";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

## 📈 Метрики

### Системные метрики (Node Exporter)
- CPU использование
- Использование памяти
- Использование диска
- Сетевая активность

### Метрики приложения (DIGroup Kernel)
- Количество WebSocket соединений
- HTTP запросы (rate, latency)
- Ошибки API
- Активные пользователи

## 🔔 Алерты

Настроенные алерты:
- Kernel недоступен
- Высокое использование CPU (>80%)
- Высокое использование памяти (>85%)
- Мало места на диске (<15%)
- Много WebSocket соединений (>100)

## 📊 Дашборды

### DIGroup Overview
- CPU Usage
- Memory Usage
- Disk Usage
- WebSocket Connections
- Kernel Status
- HTTP Requests Rate

## 🔧 Настройка

### Добавление новых метрик

1. Экспортируйте метрики из DIGroup kernel (см. `kernel/util/metrics.go`)
2. Добавьте в `prometheus.yml` новый scrape_config
3. Создайте дашборд в Grafana

### Настройка алертов

Отредактируйте `prometheus/alerts.yml` и перезагрузите Prometheus:

```bash
curl -X POST http://localhost:9090/-/reload
```

## 🔐 Безопасность

1. **Измените пароль Grafana** при первом входе
2. **Защитите Prometheus** через Nginx с Basic Auth
3. **Ограничьте доступ** по IP адресу
4. **Используйте HTTPS** для внешнего доступа

## 📝 Логи

```bash
# Логи Prometheus
docker logs prometheus

# Логи Grafana
docker logs grafana

# Логи Node Exporter
docker logs node-exporter
```

## 🛠️ Устранение неполадок

### Prometheus не собирает метрики

1. Проверьте доступность targets: http://localhost:9090/targets
2. Проверьте конфигурацию: `prometheus.yml`
3. Проверьте логи: `docker logs prometheus`

### Grafana не показывает данные

1. Проверьте подключение к Prometheus в Data Sources
2. Проверьте запросы в дашбордах
3. Проверьте временной диапазон

### Высокое использование ресурсов

1. Уменьшите `scrape_interval` в `prometheus.yml`
2. Уменьшите retention time: `--storage.tsdb.retention.time=7d`
3. Ограничьте количество метрик

