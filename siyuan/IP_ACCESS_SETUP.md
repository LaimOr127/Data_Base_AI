# Настройка доступа к DIGroup по IP адресу (без домена)

## 📋 Обзор

Это упрощенная настройка для тестирования удаленного доступа к DIGroup по IP адресу без домена и SSL.

**⚠️ ВАЖНО:** Это HTTP (не HTTPS) - данные передаются незашифрованными! Используйте только для тестирования в безопасной сети.

---

## 🚀 Быстрая настройка

### Вариант 1: Автоматическая настройка (рекомендуется)

```bash
# На сервере
cd /path/to/digroup/nginx
sudo ./setup-ip.sh
```

Скрипт автоматически:
- Установит Nginx (если нужно)
- Создаст конфигурацию
- Настроит firewall
- Покажет IP адрес для доступа

### Вариант 2: Ручная настройка

#### Шаг 1: Установите Nginx

```bash
sudo apt update
sudo apt install nginx -y
```

#### Шаг 2: Создайте конфигурацию

```bash
sudo nano /etc/nginx/sites-available/digroup
```

Вставьте содержимое из файла `nginx/digroup-ip.conf` или используйте минимальную конфигурацию:

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80 default_server;
    
    access_log /var/log/nginx/digroup-access.log;
    error_log /var/log/nginx/digroup-error.log;
    
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://127.0.0.1:6806;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_buffering off;
    }
    
    location /ws {
        proxy_pass http://127.0.0.1:6806;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_buffering off;
    }
}
```

#### Шаг 3: Активируйте конфигурацию

```bash
sudo ln -s /etc/nginx/sites-available/digroup /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default  # Удалить дефолтную конфигурацию
sudo nginx -t
sudo systemctl reload nginx
```

#### Шаг 4: Откройте порт в firewall

```bash
# UFW
sudo ufw allow 80/tcp

# firewalld
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

---

## 🔍 Определение IP адреса

### Внешний IP (для доступа из интернета):

```bash
curl ifconfig.me
# или
curl ipinfo.io/ip
```

### Локальный IP (для доступа в локальной сети):

```bash
hostname -I
# или
ip addr show | grep "inet " | grep -v 127.0.0.1
```

---

## 🚀 Запуск DIGroup kernel

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

### Вариант 2: Прямой запуск

```bash
cd /path/to/digroup/app/kernel
./SiYuan-Kernel \
  --workspace=/path/to/workspace \
  --accessAuthCode=ВАШ_СЕКРЕТНЫЙ_КОД \
  --port=6806
```

---

## 🌐 Доступ

### После настройки откройте в браузере:

```
http://ваш-ip-адрес
```

Например:
- Локальная сеть: `http://192.168.1.100`
- Внешний доступ: `http://123.45.67.89`

### При первом входе:

1. Введите AccessAuthCode
2. Нажмите "Войти"
3. Должен открыться интерфейс DIGroup

---

## 🔍 Проверка работы

### 1. Проверка kernel:

```bash
curl http://127.0.0.1:6806/api/system/version
# Должен вернуть: {"code":0,"msg":"","data":"3.4.2"}
```

### 2. Проверка через Nginx (локально):

```bash
curl http://localhost/api/system/version
```

### 3. Проверка с другого компьютера:

```bash
curl http://ip-адрес-сервера/api/system/version
```

### 4. Проверка в браузере:

- Откройте `http://ваш-ip`
- Откройте DevTools (F12)
- Вкладка Network → проверьте запросы
- Вкладка Network → WS → проверьте WebSocket соединение

---

## 🐛 Решение проблем

### Проблема: Белый экран

**Решение:**
1. Проверьте kernel: `curl http://127.0.0.1:6806/api/system/version`
2. Если не отвечает - запустите kernel
3. Проверьте логи: `sudo tail -f /var/log/nginx/digroup-error.log`

### Проблема: 502 Bad Gateway

**Решение:**
- Kernel не запущен или недоступен
- Запустите kernel и проверьте порт 6806

### Проблема: Не могу подключиться удаленно

**Решение:**
1. Проверьте firewall: `sudo ufw status`
2. Убедитесь, что порт 80 открыт: `sudo ufw allow 80/tcp`
3. Проверьте, что Nginx слушает на всех интерфейсах:
   ```bash
   sudo netstat -tlnp | grep :80
   # Должно быть: 0.0.0.0:80 или :::80
   ```

### Проблема: WebSocket не работает

**Решение:**
- Убедитесь, что в конфигурации есть `map` в начале файла
- Проверьте, что location `/ws` настроен
- Проверьте заголовки `Upgrade` и `Connection`

---

## 🔐 Безопасность

### ⚠️ Важные предупреждения:

1. **HTTP не шифрует данные** - все передается в открытом виде
2. **AccessAuthCode виден в сети** - используйте сложный код
3. **Нет защиты от MITM атак** - не используйте в публичных сетях
4. **Рекомендуется использовать только в локальной сети** или через VPN

### Рекомендации:

1. **Используйте сложный AccessAuthCode:**
   ```bash
   # Генерация случайного кода
   openssl rand -hex 32
   ```

2. **Ограничьте доступ по IP (опционально):**
   ```nginx
   # В блоке server добавьте:
   allow 192.168.1.0/24;  # Разрешить только локальную сеть
   deny all;
   ```

3. **Используйте VPN** для удаленного доступа

4. **Для продакшена обязательно настройте HTTPS** (см. `NGINX_SSL_SETUP.md`)

---

## 📊 Мониторинг

### Просмотр логов:

```bash
# Доступы
sudo tail -f /var/log/nginx/digroup-access.log

# Ошибки
sudo tail -f /var/log/nginx/digroup-error.log

# Статус Nginx
sudo systemctl status nginx
```

### Проверка подключений:

```bash
# Активные соединения
sudo netstat -an | grep :80

# Процессы Nginx
ps aux | grep nginx
```

---

## ✅ Чек-лист настройки

- [ ] Nginx установлен и запущен
- [ ] Конфигурация создана и активирована
- [ ] Конфигурация проверена: `sudo nginx -t`
- [ ] Порт 80 открыт в firewall
- [ ] DIGroup kernel запущен на порту 6806
- [ ] Kernel отвечает: `curl http://127.0.0.1:6806/api/system/version`
- [ ] Доступ через Nginx работает: `curl http://localhost/api/system/version`
- [ ] Доступ по IP работает: `curl http://ваш-ip/api/system/version`
- [ ] WebSocket соединение устанавливается (проверка в браузере)

---

## 🎯 Следующие шаги

После успешного тестирования по IP:

1. **Настройте домен** (если есть)
2. **Настройте SSL** (см. `NGINX_SSL_SETUP.md`)
3. **Ограничьте доступ** по IP или используйте VPN
4. **Настройте мониторинг** и логирование

---

## 📝 Примеры использования

### Локальная сеть:

```bash
# IP сервера в локальной сети
http://192.168.1.100
```

### Внешний доступ:

```bash
# Внешний IP сервера
http://123.45.67.89
```

### С ограничением доступа:

```nginx
# В конфигурации Nginx
location / {
    allow 192.168.1.0/24;  # Только локальная сеть
    allow 10.0.0.0/8;      # Или VPN сеть
    deny all;
    
    # ... остальная конфигурация
}
```

