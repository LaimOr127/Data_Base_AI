# Быстрый старт: Настройка доступа через домен

Краткая инструкция для настройки доступа к DIGroup через домен `digroupdb.duckdns.org`.

## Автоматическая настройка (рекомендуется)

Для автоматической настройки всех доменов и SSL используйте скрипт:

```bash
./setup-domains.sh
```

Этот скрипт автоматически:
- Установит и настроит Nginx
- Получит SSL сертификаты (или создаст самоподписанные для тестирования)
- Настроит домены для всех сервисов
- Настроит автообновление сертификатов

## Ручная настройка

### Шаг 1: Настройка DNS

**Важно:** Убедитесь, что DNS запись настроена в DuckDNS:
- `digroupdb.duckdns.org` → IP вашего сервера (85.198.99.150)

**Примечание:** DuckDNS не поддерживает субдомены напрямую. Для работы субдоменов (`grafana.digroupdb.duckdns.org`, `prometheus.digroupdb.duckdns.org`) необходимо настроить их через другой DNS-провайдер или использовать конфигурацию с путями (см. ниже).

### Шаг 2: Настройка Nginx

```bash
# На сервере
sudo cp deploy/nginx/digroup-full.conf /etc/nginx/sites-available/digroup
sudo ln -sf /etc/nginx/sites-available/digroup /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### Шаг 3: Настройка SSL

```bash
# На сервере
sudo certbot certonly --webroot -w /var/www/certbot -d digroupdb.duckdns.org
# Или используйте DNS-01 challenge для субдоменов
sudo certbot certonly --manual --preferred-challenges dns -d digroupdb.duckdns.org -d grafana.digroupdb.duckdns.org -d prometheus.digroupdb.duckdns.org
```

## Проверка

После настройки проверьте доступ:

### С субдоменами (если настроены в DNS):
- https://digroupdb.duckdns.org - основной сервис DIGroup
- https://grafana.digroupdb.duckdns.org - Grafana
- https://prometheus.digroupdb.duckdns.org - Prometheus

**Примечание:** Если используется самоподписанный сертификат, браузеры будут показывать предупреждение о безопасности. Это нормально для тестирования. Для продакшена необходимо получить настоящий сертификат Let's Encrypt через DNS-01 challenge.

### Альтернатива: Конфигурация с путями

Если субдомены не настроены, можно использовать конфигурацию с путями:

```bash
sudo cp deploy/nginx/digroup-paths.conf /etc/nginx/sites-available/digroup
sudo sed -i 's/digroupdb\.duckdns\.org/digroupdb.duckdns.org/g' /etc/nginx/sites-available/digroup
sudo ln -sf /etc/nginx/sites-available/digroup /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

Тогда доступ будет через:
- https://digroupdb.duckdns.org - основной сервис
- https://digroupdb.duckdns.org/grafana/ - Grafana
- https://digroupdb.duckdns.org/prometheus/ - Prometheus

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
