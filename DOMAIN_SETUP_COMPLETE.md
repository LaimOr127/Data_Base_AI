# Настройка доменных имен завершена ✅

## Что было сделано

1. ✅ Установлен и настроен Nginx на сервере
2. ✅ Создан SSL сертификат (самоподписанный для тестирования)
3. ✅ Настроена конфигурация Nginx для всех сервисов
4. ✅ Настроено автообновление сертификатов
5. ✅ Открыты порты 80 и 443 в firewall

## Доступ к сервисам

### Основной домен
- **DIGroup:** https://digroupdb.duckdns.org
- **Grafana:** https://grafana.digroupdb.duckdns.org
- **Prometheus:** https://prometheus.digroupdb.duckdns.org

## Важные замечания

### SSL Сертификат
В данный момент используется **самоподписанный сертификат** для тестирования. Браузеры будут показывать предупреждение о безопасности при первом посещении.

Для получения настоящего сертификата Let's Encrypt:

1. **Убедитесь, что DNS записи настроены:**
   - `digroupdb.duckdns.org` → 85.198.99.150
   - `grafana.digroupdb.duckdns.org` → 85.198.99.150 (если нужен субдомен)
   - `prometheus.digroupdb.duckdns.org` → 85.198.99.150 (если нужен субдомен)

2. **Получите сертификат через DNS-01 challenge:**
   ```bash
   ssh root@85.198.99.150
   certbot certonly --manual --preferred-challenges dns \
     -d digroupdb.duckdns.org \
     -d grafana.digroupdb.duckdns.org \
     -d prometheus.digroupdb.duckdns.org
   ```

3. **Или используйте webroot (если DNS работает):**
   ```bash
   certbot certonly --webroot -w /var/www/certbot -d digroupdb.duckdns.org
   ```

### DuckDNS и субдомены
DuckDNS не поддерживает субдомены напрямую. Если субдомены не работают, используйте конфигурацию с путями:
- https://digroupdb.duckdns.org/grafana/
- https://digroupdb.duckdns.org/prometheus/

Для переключения на конфигурацию с путями:
```bash
ssh root@85.198.99.150
cd /opt/digroup
cp deploy/nginx/digroup-paths.conf /etc/nginx/sites-available/digroup
nginx -t && systemctl reload nginx
```

## Проверка работы

```bash
# Проверка статуса Nginx
ssh root@85.198.99.150 'systemctl status nginx'

# Проверка конфигурации
ssh root@85.198.99.150 'nginx -t'

# Просмотр логов
ssh root@85.198.99.150 'tail -f /var/log/nginx/digroup-error.log'
```

## Файлы на сервере

- **Конфигурация Nginx:** `/etc/nginx/sites-available/digroup`
- **SSL сертификаты:** `/etc/letsencrypt/live/digroupdb.duckdns.org/`
- **Логи Nginx:** `/var/log/nginx/`

## Автоматическое обновление

Автообновление сертификатов настроено через cron:
```bash
0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'
```

## Дополнительная информация

- Подробная документация: `QUICK_START_DOMAIN.md`
- Скрипт автоматической настройки: `setup-domains.sh`
