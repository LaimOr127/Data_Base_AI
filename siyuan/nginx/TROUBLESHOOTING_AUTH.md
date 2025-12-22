# Решение проблемы с аутентификацией

## Проблема: После ввода AccessAuthCode ничего не происходит

### Решение 1: Очистить кэш браузера и cookies

1. Откройте DevTools (F12)
2. Вкладка Application → Storage → Clear site data
3. Или просто нажмите Cmd+Shift+R (Mac) / Ctrl+Shift+R (Windows) для жесткой перезагрузки

### Решение 2: Проверить, что frontend собран

```bash
# Проверьте наличие файлов
ls -la /Users/alexey_pripadchev/Documents/Work/data_base/siyuan/app/stage/build/desktop/

# Если файлов нет - соберите frontend
cd /Users/alexey_pripadchev/Documents/Work/data_base/siyuan/app
pnpm run build:desktop
```

### Решение 3: Перезапустить kernel

```bash
# Остановить kernel
pkill -f SiYuan-Kernel

# Запустить заново
cd /Users/alexey_pripadchev/Documents/Work/data_base/siyuan/app/kernel
./SiYuan-Kernel --wd=.. --workspace=~/DIGroup-workspace --accessAuthCode=b226ba0f30a134fe9245792118bca202 --port=6806 --mode=dev &
```

### Решение 4: Проверить логи

```bash
# Логи kernel
tail -f /tmp/digroup-kernel.log

# Логи Nginx
tail -f /opt/homebrew/var/log/nginx/digroup-error.log
```

### Решение 5: Попробовать другой браузер

Иногда Safari может кэшировать старые данные. Попробуйте Chrome или Firefox.

### Решение 6: Проверить консоль браузера

1. Откройте DevTools (F12)
2. Вкладка Console - проверьте ошибки JavaScript
3. Вкладка Network - проверьте, какие запросы выполняются после ввода кода

### Решение 7: Проверить WebSocket соединение

1. Откройте DevTools (F12)
2. Вкладка Network → WS
3. Должно быть активное WebSocket соединение на `/ws`

Если WebSocket не подключается - проверьте конфигурацию Nginx для WebSocket.

