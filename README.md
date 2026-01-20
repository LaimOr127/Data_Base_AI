# DIGroup Knowledge Base

База знаний на платформе SiYuan для команды DIGroup с мониторингом и автоматическими бэкапами.

## Установка из GitHub

```bash
# Клонируйте репозиторий
git clone git@github.com:LaimOr127/Data_Base_AI.git
cd Data_Base_AI

# Полная автоматическая установка (рекомендуется)
./bootstrap.sh
```

Скрипт `bootstrap.sh` автоматически:
- Установит Docker и Docker Compose (если нужно)
- Создаст необходимые директории
- Настроит пользователей из `users_db/users_list.txt`
- Настроит ИИ (Ollama Cloud)
- Соберет и запустит Docker контейнеры
- Настроит автоматические бэкапы (опционально)

## Быстрый старт (если уже установлено)

```bash
./install.sh      # Установка зависимостей
./start.sh        # Запуск приложения
```

Откройте: http://localhost:6806

Код доступа указан в файле `.env`

## Сервисы

После запуска доступны:

- **DIGroup** - http://localhost:6806 (база знаний)
- **Grafana** - http://localhost:3000 (мониторинг)
- **Prometheus** - http://localhost:9090 (метрики)

Логин Grafana: admin / digroup2026 (указан в `.env`)

## Мониторинг

Система мониторинга автоматически отслеживает:
- Использование CPU
- Использование памяти
- Использование диска
- Статус контейнеров
- Доступность сервисов

Dashboard доступен в Grafana: http://localhost:3000

## Автоматические бэкапы

### Настройка ежедневных бэкапов

```bash
./setup-backup.sh          # По умолчанию в 02:00
./setup-backup.sh 03:30    # В указанное время
```

### Ручной бэкап

```bash
./backup.sh
```

Бэкапы сохраняются в `./backups/` и хранятся 30 дней.

### Восстановление

```bash
docker-compose down
tar -xzf backups/workspace_YYYYMMDD_HHMMSS.tar.gz
docker-compose up -d
```

## Локальное хранение

Все данные хранятся локально:

- `./workspace/` - документы пользователей
- `./data/` - служебные данные
- `./backups/` - резервные копии
- `./logs/` - логи системы
- Docker volumes - метрики Prometheus и данные Grafana

Никакие данные не отправляются в облако.

## Управление

```bash
# Запуск
docker-compose up -d

# Остановка
docker-compose down

# Перезапуск
docker-compose restart

# Логи
docker-compose logs -f

# Логи конкретного сервиса
docker-compose logs -f digroup
docker-compose logs -f grafana

# Статус
docker-compose ps
```

## Конфигурация

Редактируйте `.env`:

```bash
# Приложение
ACCESS_AUTH_CODE=ваш_код_доступа
PORT=6806
HOST_IP=0.0.0.0

# Мониторинг
GRAFANA_USER=admin
GRAFANA_PASSWORD=ваш_пароль

# Система
TZ=Europe/Moscow
PUID=1000
PGID=1000
```

После изменений: `docker-compose restart`

## Автозапуск (Linux)

```bash
sudo ./setup-systemd.sh
```

Управление:
```bash
sudo systemctl start digroup
sudo systemctl stop digroup
sudo systemctl status digroup
```

## Доступ через домен

Для доступа к сервисам через домен (например, digroupdb.duckdns.org) с SSL:

```bash
# 1. Настройте Nginx
sudo ./setup-nginx.sh digroupdb.duckdns.org

# 2. Настройте DNS записи (см. НАСТРОЙКА_ДОМЕНА.md)

# 3. Настройте SSL
sudo ./setup-ssl.sh digroupdb.duckdns.org
```

После настройки сервисы будут доступны:
- **DIGroup**: https://digroupdb.duckdns.org
- **Grafana**: https://grafana.digroupdb.duckdns.org
- **Prometheus**: https://prometheus.digroupdb.duckdns.org
- **Node Exporter**: https://node-exporter.digroupdb.duckdns.org

Подробная инструкция: `НАСТРОЙКА_ДОМЕНА.md`

## Безопасность

1. Измените код доступа в `.env`
2. Измените пароль Grafana
3. Настройте файрволл (только для Linux серверов)
4. Используйте Nginx для SSL (см. НАСТРОЙКА_ДОМЕНА.md)

## Требования

- Docker 20.10+
- Docker Compose 1.29+
- 4 GB RAM (рекомендуется)
- 20 GB свободного места

## Дополнительная документация

- `DEPLOYMENT.md` - Развертывание на серверах
- `LINUX_DEPLOY.md` - Детальная инструкция для Linux
- `НАСТРОЙКА_ДОМЕНА.md` - Настройка доступа через домен с SSL
- `ИНСТРУКЦИЯ.md` - Руководство пользователя
- `НАСТРОЙКА_ИИ.md` - Настройка ИИ
- `МОНИТОРИНГ_И_БЭКАПЫ.md` - Подробности о мониторинге и бэкапах

## Поддержка

Версия: SiYuan v3.4.2  
Проект: DIGroup Knowledge Base
