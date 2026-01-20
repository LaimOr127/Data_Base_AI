# Быстрый старт: Настройка доступа через домен

Краткая инструкция для настройки доступа к DIGroup через домен `digroupdb.duckdns.org`.

## Шаг 1: Настройка Nginx

```bash
sudo ./setup-nginx.sh digroupdb.duckdns.org
```

## Шаг 2: Настройка DNS

### Вариант A: Только основной домен (используйте пути)

Если DuckDNS не поддерживает субдомены, используйте конфигурацию с путями:

```bash
# Используйте конфигурацию с путями
sudo cp deploy/nginx/digroup-paths.conf /etc/nginx/sites-available/digroup
sudo sed -i 's/digroupdb\.duckdns\.org/digroupdb.duckdns.org/g' /etc/nginx/sites-available/digroup
sudo ln -sf /etc/nginx/sites-available/digroup /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Настройте Grafana для работы с путями
# Добавьте в .env:
# GRAFANA_ROOT_URL=https://digroupdb.duckdns.org/grafana/
# GRAFANA_SERVE_FROM_SUB_PATH=true
# Затем: docker compose restart grafana
```

### Вариант B: С субдоменами

1. Обновите IP в DuckDNS (через веб-интерфейс или API)
2. Если ваш DNS-провайдер поддерживает субдомены, добавьте A-записи:
   - `grafana.digroupdb.duckdns.org` → IP сервера
   - `prometheus.digroupdb.duckdns.org` → IP сервера
   - `node-exporter.digroupdb.duckdns.org` → IP сервера

## Шаг 3: Настройка SSL

```bash
sudo ./setup-ssl.sh digroupdb.duckdns.org
```

## Шаг 4: Проверка

После настройки проверьте доступ:

### С субдоменами:
- https://digroupdb.duckdns.org
- https://grafana.digroupdb.duckdns.org
- https://prometheus.digroupdb.duckdns.org

### С путями:
- https://digroupdb.duckdns.org
- https://digroupdb.duckdns.org/grafana/
- https://digroupdb.duckdns.org/prometheus/

## Решение проблем

### DNS не работает
```bash
dig +short digroupdb.duckdns.org
# Должен вернуть IP вашего сервера
```

### Nginx не запускается
```bash
sudo nginx -t
sudo tail -f /var/log/nginx/error.log
```

### SSL не работает
```bash
sudo certbot certificates
sudo certbot renew --dry-run
```

Подробная документация: `НАСТРОЙКА_ДОМЕНА.md`
