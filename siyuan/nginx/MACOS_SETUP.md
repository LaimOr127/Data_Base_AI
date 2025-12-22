# Настройка DIGroup на macOS

## 🍎 Быстрая настройка

### Автоматическая установка (рекомендуется)

```bash
cd /Users/alexey_pripadchev/Documents/Work/data_base/siyuan/nginx
./setup-macos.sh
```

Скрипт автоматически:
- ✅ Установит Nginx через Homebrew
- ✅ Создаст workspace
- ✅ Сгенерирует AccessAuthCode
- ✅ Настроит Nginx
- ✅ Запустит kernel и Nginx

---

## 📋 Ручная настройка (по шагам)

### Шаг 1: Установка Nginx

```bash
# Установите Homebrew (если не установлен)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Установите Nginx
brew install nginx
```

### Шаг 2: Создание workspace

```bash
mkdir -p ~/DIGroup-workspace
```

### Шаг 3: Генерация AccessAuthCode

```bash
openssl rand -hex 16
# Сохраните полученный код!
```

### Шаг 4: Запуск kernel

```bash
cd /Users/alexey_pripadchev/Documents/Work/data_base/siyuan/app/kernel

./SiYuan-Kernel \
  --wd=.. \
  --workspace=~/DIGroup-workspace \
  --accessAuthCode=ВАШ_КОД \
  --port=6806 \
  --mode=dev &
```

**Проверка:**
```bash
curl http://127.0.0.1:6806/api/system/version
# Должен вернуть: {"code":0,"msg":"","data":"3.4.2"}
```

### Шаг 5: Настройка Nginx

Определите путь к конфигурации Nginx:

```bash
# Для Apple Silicon (M1/M2/M3)
NGINX_CONF="/opt/homebrew/etc/nginx"

# Для Intel
NGINX_CONF="/usr/local/etc/nginx"
```

Создайте конфигурацию:

```bash
sudo nano $NGINX_CONF/servers/digroup.conf
```

Вставьте:

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 8080;
    server_name localhost;
    
    access_log /opt/homebrew/var/log/nginx/digroup-access.log;
    error_log /opt/homebrew/var/log/nginx/digroup-error.log;
    
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

**Важно:** Замените `/opt/homebrew` на `/usr/local` если у вас Intel Mac.

### Шаг 6: Запуск Nginx

```bash
# Проверка конфигурации
nginx -t

# Запуск через Homebrew
brew services start nginx

# Или запуск вручную
nginx
```

### Шаг 7: Проверка

```bash
# Локально
curl http://localhost:8080/api/system/version

# Узнайте IP
ipconfig getifaddr en0

# Доступ по сети
curl http://ваш-ip:8080/api/system/version
```

---

## 🌐 Доступ

### Локальный доступ:
```
http://localhost:8080
```

### Доступ по сети:
```
http://ваш-ip:8080
```

Узнайте IP:
```bash
ipconfig getifaddr en0  # Wi-Fi
ipconfig getifaddr en1  # Ethernet
```

---

## 🔧 Управление сервисами

### Kernel

```bash
# Запуск
cd /Users/alexey_pripadchev/Documents/Work/data_base/siyuan/app/kernel
./SiYuan-Kernel --wd=.. --workspace=~/DIGroup-workspace --accessAuthCode=КОД --port=6806 --mode=dev &

# Остановка
pkill -f SiYuan-Kernel

# Проверка
ps aux | grep SiYuan-Kernel
curl http://127.0.0.1:6806/api/system/version
```

### Nginx

```bash
# Запуск
brew services start nginx

# Остановка
brew services stop nginx

# Перезапуск
brew services restart nginx

# Статус
brew services list | grep nginx

# Проверка конфигурации
nginx -t

# Перезагрузка конфигурации
nginx -s reload
```

---

## 🐛 Решение проблем

### Проблема 1: Kernel не запускается

**Решение:**
```bash
# Проверьте права
chmod +x /Users/alexey_pripadchev/Documents/Work/data_base/siyuan/app/kernel/SiYuan-Kernel

# Проверьте порт
lsof -i :6806

# Запустите с выводом в консоль (для отладки)
cd /Users/alexey_pripadchev/Documents/Work/data_base/siyuan/app/kernel
./SiYuan-Kernel --wd=.. --workspace=~/DIGroup-workspace --accessAuthCode=КОД --port=6806 --mode=dev
```

### Проблема 2: Nginx не запускается

**Решение:**
```bash
# Проверьте конфигурацию
nginx -t

# Проверьте порт 8080
lsof -i :8080

# Проверьте логи
tail -f /opt/homebrew/var/log/nginx/error.log
```

### Проблема 3: "Address already in use"

**Решение:**
```bash
# Найдите процесс на порту
lsof -i :8080
lsof -i :6806

# Остановите процесс
kill -9 PID
```

### Проблема 4: Белый экран в браузере

**Решение:**
1. Откройте DevTools (F12)
2. Вкладка Console - проверьте ошибки
3. Вкладка Network → WS - проверьте WebSocket
4. Проверьте логи:
   ```bash
   tail -f /opt/homebrew/var/log/nginx/digroup-error.log
   ```

---

## 📝 Полезные команды

```bash
# Проверка всех сервисов
ps aux | grep -E "(SiYuan-Kernel|nginx)"

# Проверка портов
lsof -i :6806
lsof -i :8080

# Логи kernel (если запущен в фоне)
tail -f /tmp/digroup-kernel.log

# Логи Nginx
tail -f /opt/homebrew/var/log/nginx/digroup-access.log
tail -f /opt/homebrew/var/log/nginx/digroup-error.log

# Полная проверка
curl http://127.0.0.1:6806/api/system/version  # Kernel
curl http://localhost:8080/api/system/version  # Nginx
```

---

## ✅ Быстрая проверка

Выполните эти команды:

```bash
# 1. Kernel запущен?
ps aux | grep SiYuan-Kernel

# 2. Kernel отвечает?
curl http://127.0.0.1:6806/api/system/version

# 3. Nginx запущен?
brew services list | grep nginx

# 4. Nginx отвечает?
curl http://localhost:8080/api/system/version

# 5. IP адрес?
ipconfig getifaddr en0
```

Если все работает - откройте `http://localhost:8080` в браузере!

