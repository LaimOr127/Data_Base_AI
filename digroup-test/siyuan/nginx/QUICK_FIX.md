# Быстрое решение: Белый экран

## 🚨 Срочное решение

### Шаг 1: Проверьте kernel

```bash
# Проверка
curl http://127.0.0.1:6806/api/system/version

# Если не отвечает - запустите kernel
cd /path/to/digroup/app/kernel
./SiYuan-Kernel --workspace=/path/to/workspace --accessAuthCode=КОД --port=6806 &
```

### Шаг 2: Обновите конфигурацию Nginx

**ВАЖНО:** Map должен быть **вне** блока server!

```nginx
# В НАЧАЛЕ файла /etc/nginx/sites-available/digroup
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    # ... остальная конфигурация
}
```

### Шаг 3: Перезагрузите Nginx

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### Шаг 4: Проверьте в браузере

1. Откройте DevTools (F12)
2. Вкладка Console - проверьте ошибки
3. Вкладка Network → WS - проверьте WebSocket

---

## 🔧 Минимальная рабочая конфигурация

Если ничего не помогает, используйте эту минимальную конфигурацию:

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 443 ssl http2;
    server_name digroup.yourdomain.com;
    
    ssl_certificate /etc/letsencrypt/live/digroup.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/digroup.yourdomain.com/privkey.pem;
    
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
}
```

---

## 🐛 Частые причины белого экрана

1. **Kernel не запущен** - самая частая причина
2. **WebSocket не работает** - неправильный Connection заголовок
3. **Map в неправильном месте** - должен быть вне server блока
4. **Проблемы с SSL** - проверьте сертификат
5. **Кэширование браузера** - очистите кэш (Ctrl+Shift+R)

