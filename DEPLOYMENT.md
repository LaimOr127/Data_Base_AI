# Развертывание DIGroup

Инструкция по развертыванию базы знаний DIGroup на различных платформах.

## Содержание

1. [Локальная разработка (macOS/Windows)](#локальная-разработка)
2. [Production сервер (Linux)](#production-сервер)
3. [Конфигурация](#конфигурация)
4. [Безопасность](#безопасность)

## Локальная разработка

### macOS

```bash
# Установите Docker Desktop
# https://www.docker.com/products/docker-desktop

# Запустите проект
./install.sh
./start.sh
```

### Windows

```bash
# Установите Docker Desktop
# https://www.docker.com/products/docker-desktop

# Запустите через PowerShell
.\install-windows.ps1
```

## Production сервер

### Автоматическая установка

```bash
./install.sh
./start.sh
```

### Настройка автозапуска

```bash
sudo ./setup-systemd.sh
```

### Настройка Nginx

Пример конфигурации:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:6806;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### SSL/TLS

```bash
sudo certbot --nginx -d your-domain.com
```

## Конфигурация

### Файл .env

```bash
# Код доступа (обязательно измените!)
ACCESS_AUTH_CODE=ваш_уникальный_код

# IP для прослушивания
HOST_IP=0.0.0.0  # для доступа из сети
# HOST_IP=127.0.0.1  # только локально

# Порт
PORT=6806

# Часовой пояс
TZ=Europe/Moscow

# User/Group ID (Linux)
PUID=1000
PGID=1000
```

### Docker Compose

Основные параметры в `docker-compose.yml`:

- Порты: настраиваются через `.env`
- Volumes: `./workspace` и `./data`
- Healthcheck: проверка работоспособности
- Restart policy: автоматический перезапуск

## Безопасность

### Базовая настройка

1. Измените `ACCESS_AUTH_CODE` на уникальный:
   ```bash
   openssl rand -hex 16
   ```

2. Настройте файрволл (см. LINUX_DEPLOY.md)

3. Используйте Nginx как reverse proxy

4. Настройте SSL/TLS

### Дополнительные меры

- Регулярное резервное копирование
- Мониторинг логов
- Ограничение доступа по IP
- Использование VPN для удаленного доступа

## Обновление

```bash
# Сохраните данные
docker-compose down
tar -czf backup-$(date +%Y%m%d).tar.gz workspace data .env

# Обновите
git pull  # если используется git
docker-compose pull
docker-compose up -d --build
```

## Мониторинг

### Проверка работоспособности

```bash
# Статус контейнера
docker-compose ps

# Логи
docker-compose logs -f

# Использование ресурсов
docker stats digroup

# Проверка API
curl http://localhost:6806/api/system/version
```

### Метрики

См. `deploy/monitoring/` для настройки Prometheus и Grafana

## Резервное копирование

### Автоматическое

```bash
# Настройте cron задачу
0 2 * * * cd /opt/digroup && docker-compose exec -T digroup tar czf - /opt/siyuan/workspace > backup-$(date +\%Y\%m\%d).tar.gz
```

### Ручное

```bash
./deploy/scripts/backup.sh
```

## Масштабирование

Для увеличения производительности:

1. Увеличьте RAM сервера (рекомендуется 8GB+)
2. Используйте SSD диски
3. Настройте nginx кэширование
4. Используйте CDN для статических файлов

## Дополнительная информация

- Полная инструкция для Linux: `LINUX_DEPLOY.md`
- Настройка ИИ: `НАСТРОЙКА_ИИ.md`
- Основная документация: `README.md`
- Руководство пользователя: `ИНСТРУКЦИЯ.md`

## Поддержка

При возникновении проблем:
1. Проверьте логи: `docker-compose logs`
2. Проверьте статус: `docker-compose ps`
3. Обратитесь к документации SiYuan: https://b3log.org/siyuan/
