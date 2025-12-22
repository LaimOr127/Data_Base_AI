# Простая настройка по шагам (без сложных скриптов)

## 🎯 Цель: Доступ к DIGroup по IP адресу

---

## Шаг 1: Запустите kernel

```bash
cd /path/to/digroup/app/kernel
./SiYuan-Kernel --workspace=/path/to/workspace --accessAuthCode=ВАШ_КОД --port=6806 &
```

**Проверка:**
```bash
curl http://127.0.0.1:6806/api/system/version
# Должен вернуть: {"code":0,"msg":"","data":"3.4.2"}
```

**Если не работает:**
- Проверьте путь к kernel
- Проверьте путь к workspace
- Проверьте, что порт 6806 свободен: `lsof -i :6806`

---

## Шаг 2: Установите Nginx (если не установлен)

```bash
sudo apt update
sudo apt install nginx -y
```

---

## Шаг 3: Создайте конфигурацию

```bash
sudo nano /etc/nginx/sites-available/digroup
```

**Вставьте это (замените ВАШ_КОД на реальный код):**

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
        proxy_read_timeout 300;
        proxy_send_timeout 300;
        proxy_buffering off;
    }
}
```

**Сохраните:** Ctrl+O, Enter, Ctrl+X

---

## Шаг 4: Активируйте конфигурацию

```bash
# Создать ссылку
sudo ln -s /etc/nginx/sites-available/digroup /etc/nginx/sites-enabled/

# Удалить дефолтную (опционально)
sudo rm /etc/nginx/sites-enabled/default

# Проверить конфигурацию
sudo nginx -t

# Если OK - перезагрузить
sudo systemctl reload nginx
```

---

## Шаг 5: Откройте порт в firewall

```bash
# UFW
sudo ufw allow 80/tcp

# Или firewalld
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

---

## Шаг 6: Узнайте IP адрес

```bash
curl ifconfig.me
# или
hostname -I
```

---

## Шаг 7: Проверьте доступ

### Локально:
```bash
curl http://localhost/api/system/version
```

### По IP (с другого компьютера):
```bash
curl http://ваш-ip/api/system/version
```

### В браузере:
```
http://ваш-ip
```

---

## 🐛 Если не работает

### Проблема 1: Kernel не запущен

**Решение:**
```bash
# Проверьте
ps aux | grep SiYuan-Kernel

# Если нет - запустите
cd /path/to/digroup/app/kernel
./SiYuan-Kernel --workspace=/path/to/workspace --accessAuthCode=КОД --port=6806 &
```

### Проблема 2: Kernel не отвечает

**Решение:**
```bash
# Проверьте порт
lsof -i :6806

# Проверьте доступность
curl http://127.0.0.1:6806/api/system/version

# Если ошибка - проверьте логи kernel
cat ~/.config/siyuan/app.log | tail -50
```

### Проблема 3: Nginx не работает

**Решение:**
```bash
# Проверьте статус
sudo systemctl status nginx

# Проверьте конфигурацию
sudo nginx -t

# Если ошибки - проверьте файл конфигурации
sudo nano /etc/nginx/sites-available/digroup
```

### Проблема 4: Белый экран в браузере

**Решение:**
1. Откройте DevTools (F12)
2. Вкладка Console - проверьте ошибки
3. Вкладка Network → WS - проверьте WebSocket
4. Проверьте логи: `sudo tail -f /var/log/nginx/digroup-error.log`

---

## ✅ Минимальная проверка

Выполните эти команды по порядку:

```bash
# 1. Kernel запущен?
ps aux | grep SiYuan-Kernel

# 2. Kernel отвечает?
curl http://127.0.0.1:6806/api/system/version

# 3. Nginx запущен?
sudo systemctl status nginx

# 4. Конфигурация правильная?
sudo nginx -t

# 5. Доступ через Nginx?
curl http://localhost/api/system/version

# 6. IP адрес?
curl ifconfig.me
```

Если все команды работают - откройте в браузере `http://ваш-ip`

---

## 📝 Быстрая команда для копирования

Если нужно быстро скопировать конфигурацию:

```bash
sudo tee /etc/nginx/sites-available/digroup > /dev/null <<'EOF'
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
        proxy_read_timeout 300;
        proxy_send_timeout 300;
        proxy_buffering off;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/digroup /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

