# 🚀 Руководство по развертыванию DIGroup на сервере

## 📋 Быстрый старт

### Автоматическая настройка (рекомендуется)

```bash
# 1. Клонируйте репозиторий на сервер
git clone git@github.com:LaimOr127/Data_Base_AI.git /opt/digroup
cd /opt/digroup

# 2. Запустите автоматическую настройку
sudo ./deploy/scripts/setup.sh

# 3. Настройте переменные окружения
cp .env.example .env
nano .env  # Измените ACCESS_AUTH_CODE на сложный код

# 4. Запустите DIGroup
cd /opt/digroup
docker-compose up -d

# 5. Проверьте работу
docker-compose logs -f
curl http://127.0.0.1:6806/api/system/version
```

---

## 📦 Требования к серверу

### Минимальные (до 20 пользователей):
- **CPU:** 4 ядра
- **RAM:** 8 GB
- **Диск:** SSD, 50+ GB
- **ОС:** Ubuntu 20.04+ / Debian 11+ / CentOS 8+

### Рекомендуемые (50+ пользователей):
- **CPU:** 8+ ядер
- **RAM:** 16+ GB
- **Диск:** SSD, 100+ GB
- **Сеть:** стабильное соединение, 50+ Мбит/с

---

## 🔧 Ручная настройка

### Шаг 1: Установка зависимостей

```bash
sudo apt update
sudo apt install -y docker.io docker-compose nginx
```

### Шаг 2: Настройка проекта

```bash
# Создайте директории
sudo mkdir -p /opt/digroup/{workspace,data,backups}
sudo chown -R $USER:$USER /opt/digroup

# Скопируйте проект
cp -r siyuan /opt/digroup/
cp docker-compose.yml /opt/digroup/
cp .env.example /opt/digroup/.env
```

### Шаг 3: Настройка переменных окружения

```bash
nano /opt/digroup/.env
```

Установите:
- `ACCESS_AUTH_CODE` - сложный секретный код (минимум 16 символов)
- `TZ` - часовой пояс
- `DOMAIN` - ваш домен (если есть)

### Шаг 4: Настройка Nginx

```bash
# Копирование конфигурации
sudo cp deploy/nginx/digroup.conf /etc/nginx/sites-available/digroup
sudo ln -s /etc/nginx/sites-available/digroup /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

# Проверка и перезагрузка
sudo nginx -t
sudo systemctl reload nginx
```

### Шаг 5: Настройка Firewall

```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp     # HTTP
sudo ufw allow 443/tcp    # HTTPS
sudo ufw enable
```

### Шаг 6: Запуск

```bash
cd /opt/digroup
docker-compose up -d
```

---

## 🔐 Настройка SSL (HTTPS)

### С доменом:

```bash
sudo ./deploy/scripts/install-ssl.sh your-domain.com your-email@example.com
```

### Без домена (самоподписанный сертификат):

```bash
# Создание самоподписанного сертификата
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/digroup.key \
  -out /etc/ssl/certs/digroup.crt

# Обновление конфигурации Nginx
sudo cp deploy/nginx/digroup-ssl.conf /etc/nginx/sites-available/digroup
# Отредактируйте пути к сертификатам
sudo nano /etc/nginx/sites-available/digroup
sudo systemctl reload nginx
```

---

## 💾 Бэкапы

### Автоматические бэкапы

Скрипт `backup.sh` настроен на автоматический запуск ежедневно в 2:00 через cron.

### Ручной бэкап

```bash
sudo /opt/digroup/backup.sh
```

### Восстановление из бэкапа

```bash
sudo ./deploy/scripts/restore.sh workspace_20240101_120000.tar.gz
```

---

## 🔄 Обновление

```bash
cd /opt/digroup
docker-compose down
git pull
docker-compose build
docker-compose up -d
```

---

## 📊 Мониторинг

### Проверка работы

```bash
# Проверка контейнера
docker-compose ps

# Логи
docker-compose logs -f

# Использование ресурсов
docker stats digroup

# Проверка API
curl http://127.0.0.1:6806/api/system/version
```

### Логи

```bash
# Docker логи
docker-compose logs -f digroup

# Nginx логи
sudo tail -f /var/log/nginx/digroup-access.log
sudo tail -f /var/log/nginx/digroup-error.log

# Логи бэкапов
tail -f /var/log/digroup-backup.log
```

---

## 🛠️ Устранение неполадок

### Проблема: Белый экран

1. Проверьте, запущен ли kernel:
```bash
curl http://127.0.0.1:6806/api/system/version
```

2. Проверьте логи:
```bash
docker-compose logs digroup
sudo tail -f /var/log/nginx/digroup-error.log
```

3. Проверьте WebSocket в браузере (F12 → Network → WS)

### Проблема: 502 Bad Gateway

Kernel не запущен или недоступен:
```bash
docker-compose restart
docker-compose logs -f
```

### Проблема: Медленная работа

1. Проверьте ресурсы:
```bash
htop
df -h
docker stats
```

2. Увеличьте ресурсы сервера или оптимизируйте использование

---

## 🔒 Безопасность

### Рекомендации:

1. **Используйте сложный AccessAuthCode** (минимум 16 символов)
2. **Настройте HTTPS** через Let's Encrypt
3. **Ограничьте доступ по IP** (если возможно):
   ```nginx
   # В /etc/nginx/sites-available/digroup
   allow 192.168.1.0/24;  # Ваша сеть
   deny all;
   ```
4. **Регулярно обновляйте систему**
5. **Настройте регулярные бэкапы**
6. **Мониторьте логи** на подозрительную активность

---

## 📝 Доступ сотрудников

После настройки сотрудники могут подключаться:

1. **По IP:** `http://ваш-ip-адрес`
2. **По домену:** `https://digroup.yourdomain.com`
3. **Вводят AccessAuthCode** при первом входе
4. **Работают через браузер** - никаких дополнительных установок не требуется

---

## 📞 Поддержка

При возникновении проблем:

1. Проверьте логи (см. раздел Мониторинг)
2. Проверьте документацию в `siyuan/`
3. Создайте issue в репозитории

---

## ✅ Чек-лист развертывания

- [ ] Сервер соответствует требованиям
- [ ] Docker и Nginx установлены
- [ ] Проект скопирован на сервер
- [ ] `.env` файл настроен с сложным AccessAuthCode
- [ ] Nginx настроен и работает
- [ ] Firewall настроен
- [ ] Docker контейнер запущен
- [ ] SSL настроен (если есть домен)
- [ ] Бэкапы настроены
- [ ] Автозапуск через systemd настроен
- [ ] Доступ проверен из браузера

---

**Готово! Ваш DIGroup развернут и готов к работе! 🎉**

