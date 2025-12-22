# Настройка Nginx + SSL для DIGroup

## 📋 Обзор

Это руководство поможет настроить Nginx как reverse proxy с SSL сертификатом от Let's Encrypt для доступа к DIGroup по адресу `https://digroup.yourdomain.com`.

---

## 🔧 Предварительные требования

1. **Сервер с Ubuntu/Debian** (или другой Linux дистрибутив)
2. **Установленный Nginx**
3. **Домен, указывающий на IP вашего сервера** (A-запись)
4. **Docker или запущенный kernel** на порту 6806
5. **Открытые порты:** 80 (HTTP), 443 (HTTPS), 6806 (опционально, только для прямого доступа)

---

## 📝 Шаг 1: Установка Nginx

### Ubuntu/Debian:
```bash
sudo apt update
sudo apt install nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx
```

### Проверка установки:
```bash
sudo systemctl status nginx
```

Откройте в браузере `http://ваш-ip` - должна появиться страница приветствия Nginx.

---

## 📝 Шаг 2: Установка Certbot (Let's Encrypt)

```bash
# Ubuntu/Debian
sudo apt install certbot python3-certbot-nginx -y

# CentOS/RHEL
sudo yum install certbot python3-certbot-nginx -y
```

---

## 📝 Шаг 3: Настройка Nginx для DIGroup

### Создайте конфигурационный файл:

```bash
sudo nano /etc/nginx/sites-available/digroup
```

### Вставьте следующую конфигурацию:

```nginx
# Конфигурация для DIGroup с поддержкой WebSocket
server {
    listen 80;
    server_name digroup.yourdomain.com;  # Замените на ваш домен
    
    # Логирование
    access_log /var/log/nginx/digroup-access.log;
    error_log /var/log/nginx/digroup-error.log;
    
    # Временный редирект на HTTPS (будет настроен после получения SSL)
    # Раскомментируйте после настройки SSL:
    # return 301 https://$server_name$request_uri;
    
    # Пока оставляем HTTP для получения SSL сертификата
    location / {
        proxy_pass http://127.0.0.1:6806;
        proxy_http_version 1.1;
        
        # Заголовки для проксирования
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket поддержка (критически важно для DIGroup)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Таймауты для WebSocket (долгие соединения)
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 60;
        
        # Буферизация
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
```

### Активируйте конфигурацию:

```bash
# Создайте символическую ссылку
sudo ln -s /etc/nginx/sites-available/digroup /etc/nginx/sites-enabled/

# Удалите дефолтную конфигурацию (опционально)
sudo rm /etc/nginx/sites-enabled/default

# Проверьте конфигурацию
sudo nginx -t

# Перезагрузите Nginx
sudo systemctl reload nginx
```

---

## 📝 Шаг 4: Настройка DNS

### Убедитесь, что домен указывает на ваш сервер:

```bash
# Проверьте DNS запись
dig digroup.yourdomain.com
# или
nslookup digroup.yourdomain.com
```

Должен вернуться IP адрес вашего сервера.

### Если домен еще не настроен:

1. Зайдите в панель управления вашего DNS провайдера
2. Создайте A-запись:
   - **Имя:** `digroup` (или `@` для корневого домена)
   - **Тип:** A
   - **Значение:** IP адрес вашего сервера
   - **TTL:** 3600 (или автоматически)

3. Подождите распространения DNS (обычно 5-30 минут)

---

## 📝 Шаг 5: Получение SSL сертификата

### Автоматическая настройка через Certbot:

```bash
sudo certbot --nginx -d digroup.yourdomain.com
```

Certbot автоматически:
- Получит SSL сертификат от Let's Encrypt
- Настроит Nginx для использования HTTPS
- Настроит автоматическое обновление сертификата

### Во время установки Certbot спросит:

1. **Email для уведомлений** - введите ваш email
2. **Согласие с условиями** - нажмите `Y`
3. **Редирект HTTP на HTTPS** - выберите `2` (рекомендуется)

### Проверка SSL:

После установки откройте в браузере:
```
https://digroup.yourdomain.com
```

Должен появиться замок в адресной строке и подключение должно быть безопасным.

---

## 📝 Шаг 6: Финальная конфигурация Nginx (с SSL)

После получения SSL, Certbot автоматически обновит конфигурацию. Проверьте файл:

```bash
sudo nano /etc/nginx/sites-available/digroup
```

### Должна получиться примерно такая конфигурация:

```nginx
# HTTP сервер - редирект на HTTPS
server {
    listen 80;
    server_name digroup.yourdomain.com;
    
    # Редирект всех HTTP запросов на HTTPS
    return 301 https://$server_name$request_uri;
}

# HTTPS сервер
server {
    listen 443 ssl http2;
    server_name digroup.yourdomain.com;
    
    # SSL сертификаты (автоматически настроены Certbot)
    ssl_certificate /etc/letsencrypt/live/digroup.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/digroup.yourdomain.com/privkey.pem;
    
    # SSL настройки (рекомендуемые)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Логирование
    access_log /var/log/nginx/digroup-access.log;
    error_log /var/log/nginx/digroup-error.log;
    
    # Проксирование на DIGroup kernel
    location / {
        proxy_pass http://127.0.0.1:6806;
        proxy_http_version 1.1;
        
        # Заголовки
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket поддержка (критически важно!)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Таймауты для WebSocket
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 60;
        
        # Отключение буферизации для WebSocket
        proxy_buffering off;
        proxy_request_buffering off;
        
        # Размеры буферов
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
    }
}
```

### Примените изменения:

```bash
# Проверьте конфигурацию
sudo nginx -t

# Перезагрузите Nginx
sudo systemctl reload nginx
```

---

## 📝 Шаг 7: Настройка firewall

### UFW (Ubuntu):
```bash
# Разрешить HTTP и HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Опционально: закрыть прямой доступ к порту 6806 извне
# (оставить доступ только через Nginx)
sudo ufw deny 6806/tcp
```

### firewalld (CentOS/RHEL):
```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

---

## 📝 Шаг 8: Автоматическое обновление SSL

Certbot автоматически настроит обновление сертификата. Проверьте:

```bash
# Проверить таймер обновления
sudo systemctl status certbot.timer

# Проверить когда будет следующее обновление
sudo systemctl list-timers | grep certbot
```

Сертификат Let's Encrypt действителен 90 дней и автоматически обновляется каждые 60 дней.

### Ручное обновление (если нужно):
```bash
sudo certbot renew --dry-run
```

---

## 📝 Шаг 9: Запуск DIGroup

### Вариант 1: Docker

```bash
# docker-compose.yml
version: '3.8'

services:
  digroup:
    image: digroup:latest
    container_name: digroup
    restart: unless-stopped
    ports:
      - "127.0.0.1:6806:6806"  # Только локальный доступ
    environment:
      - TZ=Europe/Moscow
    volumes:
      - ./workspace:/opt/siyuan/workspace
      - ./data:/opt/siyuan/data
    command: ["/opt/siyuan/kernel", "--workspace=/opt/siyuan/workspace", "--accessAuthCode=ВАШ_СЕКРЕТНЫЙ_КОД"]
```

```bash
docker-compose up -d
```

### Вариант 2: Прямой запуск kernel

```bash
cd /path/to/digroup/app/kernel
./SiYuan-Kernel \
  --workspace=/opt/digroup/workspace \
  --accessAuthCode=ВАШ_СЕКРЕТНЫЙ_КОД \
  --port=6806
```

---

## 🔍 Проверка работы

### 1. Проверьте доступность через Nginx:

```bash
# Проверка HTTP редиректа
curl -I http://digroup.yourdomain.com
# Должен вернуть: HTTP/1.1 301 Moved Permanently

# Проверка HTTPS
curl -I https://digroup.yourdomain.com
# Должен вернуть: HTTP/1.1 200 OK
```

### 2. Откройте в браузере:

```
https://digroup.yourdomain.com
```

Должен открыться интерфейс DIGroup.

### 3. Проверьте WebSocket:

Откройте консоль разработчика в браузере (F12) и проверьте, что WebSocket соединение установлено без ошибок.

---

## 🛠️ Дополнительные настройки

### Увеличение размера загружаемых файлов:

Добавьте в блок `server`:

```nginx
client_max_body_size 100M;  # Максимальный размер загружаемого файла
```

### Кэширование статических файлов:

```nginx
location /assets/ {
    proxy_pass http://127.0.0.1:6806;
    proxy_cache_valid 200 1h;
    expires 1h;
    add_header Cache-Control "public, immutable";
}
```

### Ограничение скорости (rate limiting):

```nginx
# В начале файла, вне блока server
limit_req_zone $binary_remote_addr zone=digroup_limit:10m rate=10r/s;

# В блоке location /
limit_req zone=digroup_limit burst=20 nodelay;
```

### Безопасность заголовков:

```nginx
# Добавьте в блок server
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
```

---

## 🐛 Решение проблем

### Проблема: Белый экран и долгая загрузка

**Это самая частая проблема!**

**Причины:**
1. Kernel не запущен
2. WebSocket не работает через прокси
3. Map для Connection в неправильном месте

**Быстрое решение:**

1. **Проверьте kernel:**
```bash
curl http://127.0.0.1:6806/api/system/version
# Должен вернуть: {"code":0,"msg":"","data":"3.4.2"}
```

2. **Если не отвечает - запустите kernel:**
```bash
cd /path/to/digroup/app/kernel
./SiYuan-Kernel --workspace=/path/to/workspace --accessAuthCode=КОД --port=6806 &
```

3. **ВАЖНО: Map должен быть ВНЕ блока server!**

В файле `/etc/nginx/sites-available/digroup` должно быть:
```nginx
# В НАЧАЛЕ файла, ДО блока server
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    # ... остальная конфигурация
}
```

4. **Проверьте WebSocket в браузере:**
   - Откройте DevTools (F12)
   - Вкладка Network → WS
   - Должно быть соединение `/ws` со статусом "101 Switching Protocols"

5. **Используйте скрипт диагностики:**
```bash
sudo ./nginx/diagnose.sh
```

**Подробная диагностика:** См. файл `nginx/TROUBLESHOOTING.md`

### Проблема: 502 Bad Gateway

**Причина:** Kernel не запущен или недоступен на порту 6806

**Решение:**
```bash
# Проверьте, запущен ли kernel
ps aux | grep SiYuan-Kernel

# Проверьте доступность порта
curl http://127.0.0.1:6806/api/system/version

# Проверьте логи Nginx
sudo tail -f /var/log/nginx/digroup-error.log
```

### Проблема: WebSocket не работает

**Причина:** Неправильная настройка WebSocket в Nginx

**Решение:**
- Убедитесь, что есть заголовки `Upgrade` и `Connection`
- Проверьте таймауты (должны быть большие значения)
- Проверьте, что `proxy_buffering off`

### Проблема: SSL сертификат не обновляется

**Решение:**
```bash
# Проверить статус
sudo systemctl status certbot.timer

# Включить таймер
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Ручное обновление
sudo certbot renew
```

### Проблема: DNS не резолвится

**Решение:**
```bash
# Проверьте DNS
dig digroup.yourdomain.com

# Подождите распространения DNS (может занять до 24 часов)
# Проверьте настройки DNS у вашего провайдера
```

---

## 📊 Мониторинг

### Просмотр логов Nginx:

```bash
# Доступы
sudo tail -f /var/log/nginx/digroup-access.log

# Ошибки
sudo tail -f /var/log/nginx/digroup-error.log

# Все логи
sudo journalctl -u nginx -f
```

### Проверка статуса:

```bash
# Статус Nginx
sudo systemctl status nginx

# Статус Certbot
sudo systemctl status certbot.timer

# Проверка SSL сертификата
echo | openssl s_client -servername digroup.yourdomain.com -connect digroup.yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates
```

---

## ✅ Чек-лист настройки

- [ ] Nginx установлен и запущен
- [ ] Certbot установлен
- [ ] DNS запись настроена и резолвится
- [ ] Конфигурация Nginx создана и активирована
- [ ] SSL сертификат получен
- [ ] HTTPS работает
- [ ] HTTP редиректит на HTTPS
- [ ] DIGroup kernel запущен на порту 6806
- [ ] Доступ через `https://digroup.yourdomain.com` работает
- [ ] WebSocket соединение устанавливается
- [ ] Firewall настроен (порты 80, 443 открыты)
- [ ] Автоматическое обновление SSL настроено

---

## 🎉 Готово!

Теперь DIGroup доступен по адресу `https://digroup.yourdomain.com` с безопасным SSL соединением.

Все пользователи могут подключаться через браузер, используя AccessAuthCode для входа.

