# Исправление доступа к сервису

## Статус: ✅ Сервис доступен извне

Проверка показала, что сервис работает и доступен через домен `digroupdb.duckdns.org`.

## Проверка доступа

### 1. Через домен (рекомендуется)
Откройте в браузере:
- **DIGroup:** https://digroupdb.duckdns.org
- **Grafana:** https://grafana.digroupdb.duckdns.org  
- **Prometheus:** https://prometheus.digroupdb.duckdns.org

**Важно:** При первом посещении браузер покажет предупреждение о безопасности из-за самоподписанного SSL сертификата. Это нормально для тестирования.

### 2. Через IP (если домен не работает)
- **DIGroup:** http://85.198.99.150:6806 (прямой доступ, без SSL)
- **Grafana:** http://85.198.99.150:3000
- **Prometheus:** http://85.198.99.150:9090

## Возможные проблемы и решения

### Проблема: Браузер блокирует доступ из-за SSL сертификата

**Решение:**
1. Нажмите "Дополнительно" или "Advanced"
2. Выберите "Перейти на сайт" или "Proceed to site"
3. Сертификат самоподписанный, но безопасный для использования

### Проблема: Страница не загружается

**Проверьте:**
1. DNS запись настроена: `digroupdb.duckdns.org` → `85.198.99.150`
2. Порт 80 и 443 открыты в firewall провайдера
3. Сервисы работают на сервере

**Команды для проверки:**
```bash
# Проверка DNS
dig +short digroupdb.duckdns.org
# Должен вернуть: 85.198.99.150

# Проверка доступности портов
curl -I http://85.198.99.150
curl -I -k https://85.198.99.150

# Проверка API
curl -k https://digroupdb.duckdns.org/api/system/version
# Должен вернуть: {"code":0,"msg":"","data":"3.4.2"}
```

### Проблема: Субдомены не работают

DuckDNS не поддерживает субдомены напрямую. Используйте:
- https://digroupdb.duckdns.org (основной сервис)
- Или настройте субдомены через другой DNS-провайдер

## Проверка на сервере

```bash
ssh root@85.198.99.150
# Пароль: !K5kUHw6Hc0%

# Статус сервисов
cd /opt/digroup
docker compose ps

# Статус Nginx
systemctl status nginx

# Логи Nginx
tail -f /var/log/nginx/digroup-access.log
tail -f /var/log/nginx/digroup-error.log

# Проверка конфигурации
nginx -t
```

## Получение настоящего SSL сертификата

Для получения настоящего сертификата Let's Encrypt (без предупреждений в браузере):

```bash
ssh root@85.198.99.150

# Убедитесь, что DNS настроен правильно
dig +short digroupdb.duckdns.org

# Получите сертификат через DNS-01 challenge
certbot certonly --manual --preferred-challenges dns \
  -d digroupdb.duckdns.org \
  -d grafana.digroupdb.duckdns.org \
  -d prometheus.digroupdb.duckdns.org

# Или через webroot (если DNS работает)
certbot certonly --webroot -w /var/www/certbot -d digroupdb.duckdns.org

# Перезагрузите Nginx
systemctl reload nginx
```

## Текущий статус

- ✅ Nginx работает и слушает порты 80 и 443
- ✅ SSL сертификат настроен (самоподписанный)
- ✅ Конфигурация Nginx корректна
- ✅ Сервисы DIGroup, Grafana, Prometheus работают
- ✅ API доступен через домен
- ✅ HTTP редиректит на HTTPS
- ⚠️ SSL сертификат самоподписанный (браузер покажет предупреждение)

## Контакты для диагностики

Если проблема сохраняется, проверьте:
1. Логи Nginx: `/var/log/nginx/digroup-error.log`
2. Логи Docker: `docker compose logs digroup`
3. Статус контейнеров: `docker compose ps`
