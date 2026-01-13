# Решение проблем: Белый экран и долгая загрузка

## 🔍 Диагностика проблемы

### Шаг 1: Проверьте, запущен ли kernel

```bash
# Проверка процесса
ps aux | grep SiYuan-Kernel

# Проверка порта
netstat -tlnp | grep 6806
# или
lsof -i :6806

# Проверка доступности
curl http://127.0.0.1:6806/api/system/version
# Должен вернуть: {"code":0,"msg":"","data":"3.4.2"}
```

**Если kernel не запущен:**
```bash
cd /path/to/digroup/app/kernel
./SiYuan-Kernel --workspace=/path/to/workspace --accessAuthCode=КОД --port=6806
```

### Шаг 2: Проверьте логи Nginx

```bash
# Ошибки
sudo tail -f /var/log/nginx/digroup-error.log

# Доступы
sudo tail -f /var/log/nginx/digroup-access.log

# Общие логи Nginx
sudo journalctl -u nginx -f
```

**Что искать в логах:**
- `502 Bad Gateway` - kernel не запущен
- `Connection refused` - порт 6806 недоступен
- `upstream timeout` - таймауты соединения
- `WebSocket` ошибки - проблемы с WebSocket

### Шаг 3: Проверьте конфигурацию Nginx

```bash
# Проверка синтаксиса
sudo nginx -t

# Если есть ошибки, исправьте их
```

### Шаг 4: Проверьте WebSocket в браузере

1. Откройте DevTools (F12)
2. Вкладка Network → WS (WebSocket)
3. Обновите страницу
4. Проверьте, есть ли соединение `/ws`

**Если WebSocket не подключается:**
- Проверьте конфигурацию Nginx для `/ws`
- Убедитесь, что заголовки `Upgrade` и `Connection` передаются

---

## 🛠️ Решения проблем

### Проблема 1: 502 Bad Gateway

**Причина:** Kernel не запущен или недоступен

**Решение:**
```bash
# 1. Запустите kernel
cd /path/to/digroup/app/kernel
./SiYuan-Kernel --workspace=/path/to/workspace --accessAuthCode=КОД --port=6806 &

# 2. Проверьте доступность
curl http://127.0.0.1:6806/api/system/version

# 3. Если работает, перезагрузите Nginx
sudo systemctl reload nginx
```

### Проблема 2: WebSocket не работает

**Причина:** Неправильная настройка WebSocket в Nginx

**Решение:**

1. Убедитесь, что в конфигурации есть:
```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

location /ws {
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    # ... остальные настройки
}
```

2. Проверьте, что map находится **вне** блока server (в начале файла)

3. Перезагрузите Nginx:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

### Проблема 3: Белый экран, но нет ошибок в логах

**Причина:** Проблемы с CORS или заголовками

**Решение:**

Добавьте в конфигурацию Nginx:
```nginx
location / {
    # ... существующие настройки ...
    
    # CORS заголовки (если нужно)
    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
    add_header Access-Control-Allow-Headers "Content-Type, Authorization";
}
```

### Проблема 4: Долгая загрузка, затем таймаут

**Причина:** Таймауты слишком короткие или kernel не отвечает

**Решение:**

1. Увеличьте таймауты в Nginx:
```nginx
proxy_read_timeout 300;      # 5 минут для начала
proxy_send_timeout 300;
proxy_connect_timeout 60;
```

2. Проверьте, что kernel запущен и отвечает:
```bash
timeout 5 curl http://127.0.0.1:6806/api/system/version
```

### Проблема 5: SSL ошибки

**Причина:** Проблемы с SSL сертификатом

**Решение:**
```bash
# Проверьте сертификат
sudo certbot certificates

# Обновите сертификат
sudo certbot renew

# Проверьте конфигурацию
sudo nginx -t
```

---

## 🔧 Улучшенная конфигурация для отладки

Создайте временную конфигурацию с подробным логированием:

```nginx
# В начале файла
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 443 ssl http2;
    server_name digroup.yourdomain.com;
    
    # Подробное логирование для отладки
    error_log /var/log/nginx/digroup-error.log debug;
    access_log /var/log/nginx/digroup-access.log;
    
    # ... SSL настройки ...
    
    location / {
        proxy_pass http://127.0.0.1:6806;
        proxy_http_version 1.1;
        
        # Все заголовки
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # WebSocket
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        
        # Таймауты
        proxy_read_timeout 300;
        proxy_send_timeout 300;
        proxy_connect_timeout 60;
        
        # Буферизация
        proxy_buffering off;
        proxy_request_buffering off;
        
        # Отладка - логирование заголовков
        add_header X-Debug-Upgrade $http_upgrade;
        add_header X-Debug-Connection $connection_upgrade;
    }
    
    location /ws {
        proxy_pass http://127.0.0.1:6806;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 60;
        
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
```

---

## 🧪 Тестирование

### Тест 1: Прямой доступ к kernel

```bash
# Должен вернуть версию
curl http://127.0.0.1:6806/api/system/version
```

### Тест 2: Доступ через Nginx (локально)

```bash
# Через HTTP (если не настроен редирект)
curl http://localhost/api/system/version

# Через HTTPS
curl -k https://localhost/api/system/version
```

### Тест 3: WebSocket соединение

```bash
# Установите wscat
npm install -g wscat

# Тест WebSocket
wscat -c ws://127.0.0.1:6806/ws?app=siyuan&id=test
```

### Тест 4: Проверка в браузере

1. Откройте `https://digroup.yourdomain.com`
2. Откройте DevTools (F12)
3. Вкладка Console - проверьте ошибки
4. Вкладка Network:
   - Проверьте статус запросов (должны быть 200)
   - Проверьте WebSocket соединение (должно быть "101 Switching Protocols")

---

## 📋 Чек-лист диагностики

- [ ] Kernel запущен и отвечает на `http://127.0.0.1:6806`
- [ ] Nginx запущен: `sudo systemctl status nginx`
- [ ] Конфигурация корректна: `sudo nginx -t`
- [ ] Порт 6806 доступен локально: `curl http://127.0.0.1:6806/api/system/version`
- [ ] DNS резолвится: `dig digroup.yourdomain.com`
- [ ] SSL сертификат валиден: `sudo certbot certificates`
- [ ] Firewall открыт для портов 80 и 443
- [ ] WebSocket endpoint `/ws` доступен
- [ ] Нет ошибок в логах Nginx
- [ ] Нет ошибок в консоли браузера

---

## 🆘 Если ничего не помогает

1. **Временно отключите SSL** для тестирования:
   - Измените конфигурацию на HTTP
   - Проверьте, работает ли без SSL

2. **Проверьте прямой доступ:**
   ```bash
   # Откройте в браузере (если firewall позволяет)
   http://ваш-ip:6806
   ```

3. **Проверьте логи kernel:**
   ```bash
   # Если kernel запущен через systemd
   sudo journalctl -u digroup -f
   
   # Или проверьте файл логов
   cat ~/.config/siyuan/app.log | tail -50
   ```

4. **Упростите конфигурацию:**
   - Уберите все дополнительные заголовки
   - Оставьте только базовое проксирование
   - Постепенно добавляйте настройки обратно

