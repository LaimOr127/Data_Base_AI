# 🔧 Быстрое решение: Белый экран

## ⚡ За 3 шага

### Шаг 1: Проверьте kernel (90% проблем здесь!)

```bash
# Проверка
curl http://127.0.0.1:6806/api/system/version

# Если ошибка "Connection refused" - запустите kernel:
cd /path/to/digroup/app/kernel
./SiYuan-Kernel --workspace=/path/to/workspace --accessAuthCode=ВАШ_КОД --port=6806 &
```

### Шаг 2: Обновите конфигурацию Nginx

**КРИТИЧЕСКИ ВАЖНО:** Map должен быть **ВНЕ** блока server!

Откройте `/etc/nginx/sites-available/digroup` и убедитесь, что в **начале файла** есть:

```nginx
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

---

## 🔍 Диагностика в браузере

1. Откройте `https://digroup.yourdomain.com`
2. Нажмите F12 (DevTools)
3. Вкладка **Console** - проверьте ошибки
4. Вкладка **Network**:
   - Фильтр: **WS** (WebSocket)
   - Обновите страницу
   - Должно быть соединение `/ws` со статусом **101 Switching Protocols**

**Если WebSocket не подключается:**
- Проверьте, что kernel запущен
- Проверьте конфигурацию Nginx
- Проверьте логи: `sudo tail -f /var/log/nginx/digroup-error.log`

---

## 🐛 Частые ошибки

### Ошибка 1: "Connection refused"
**Решение:** Kernel не запущен - запустите его

### Ошибка 2: WebSocket 404 или 502
**Решение:** 
- Проверьте, что `/ws` location есть в конфигурации
- Проверьте, что `Upgrade` и `Connection` заголовки передаются

### Ошибка 3: "nginx: [emerg] unknown directive 'map'"
**Решение:** Map должен быть в начале файла, вне блока server

### Ошибка 4: Белый экран без ошибок
**Решение:**
- Очистите кэш браузера (Ctrl+Shift+R)
- Проверьте, что kernel отвечает: `curl http://127.0.0.1:6806/api/system/version`
- Проверьте логи kernel

---

## 📋 Чек-лист

- [ ] Kernel запущен: `ps aux | grep SiYuan-Kernel`
- [ ] Kernel отвечает: `curl http://127.0.0.1:6806/api/system/version`
- [ ] Nginx запущен: `sudo systemctl status nginx`
- [ ] Конфигурация корректна: `sudo nginx -t`
- [ ] Map в начале файла (вне server блока)
- [ ] WebSocket location `/ws` настроен
- [ ] Заголовки `Upgrade` и `Connection` передаются
- [ ] Нет ошибок в логах: `sudo tail -f /var/log/nginx/digroup-error.log`

---

## 🆘 Если ничего не помогает

1. **Временно отключите SSL** для тестирования:
   ```nginx
   server {
       listen 80;
       # ... остальная конфигурация без SSL
   }
   ```

2. **Проверьте прямой доступ:**
   ```bash
   # Если firewall позволяет
   curl http://ваш-ip:6806/api/system/version
   ```

3. **Используйте скрипт диагностики:**
   ```bash
   sudo ./nginx/diagnose.sh
   ```

4. **Проверьте логи kernel:**
   ```bash
   cat ~/.config/siyuan/app.log | tail -50
   ```

