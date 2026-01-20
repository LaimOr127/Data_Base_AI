# Решение проблем SiYuan

## Проблема: "Forbidden" в правом верхнем углу

### Описание
При работе с SiYuan постоянно появляется сообщение "Forbidden" в правом верхнем углу.

### Причина
Это происходит из-за того, что браузер пытается установить WebSocket соединение без AccessAuthCode. Это нормальное поведение при многопользовательской настройке, где пользователи входят через сессии, а не через прямой AccessAuthCode.

### Решение
**Это сообщение можно игнорировать**. Оно не влияет на функциональность системы, так как:
- HTTP API запросы проходят через сессионную аутентификацию (`Auth via session`)
- Пользователь уже авторизован через логин/пароль
- Основная функциональность работает корректно

Если сообщение сильно раздражает, можно:
1. Очистить кэш браузера и перезайти
2. Использовать режим инкогнито
3. Проверить, что в браузере нет старых сессий

---

## Проблема: Бесконечная загрузка в меню "Облако"

### Описание
При открытии настроек → Облако страница зависает и показывает бесконечную загрузку.

### Причина
Облачная синхронизация не настроена (`"enabled": false` в конфигурации), но интерфейс пытается загрузить данные.

### Решение

#### Вариант 1: Настроить облачное хранилище

Если нужна синхронизация, настройте один из провайдеров:

1. **S3-совместимое хранилище** (MinIO, Backblaze B2, AWS S3):
   ```json
   "sync": {
     "enabled": true,
     "provider": 2,
     "s3": {
       "endpoint": "https://s3.example.com",
       "accessKey": "your-access-key",
       "secretKey": "your-secret-key",
       "bucket": "siyuan-sync",
       "region": "us-east-1"
     }
   }
   ```

2. **WebDAV** (Nextcloud, Яндекс.Диск):
   ```json
   "sync": {
     "enabled": true,
     "provider": 1,
     "webdav": {
       "endpoint": "https://webdav.yandex.ru",
       "username": "your-username",
       "password": "your-password"
     }
   }
   ```

#### Вариант 2: Отключить меню облака (если не нужна синхронизация)

Просто не открывайте это меню, так как синхронизация отключена (`"enabled": false`).

---

## Проблема: Не работает AI / Ollama

### Описание
В логах появляется ошибка: `Ollama API request failed: dial tcp connection refused`

### Причина
SiYuan работает в Docker контейнере и не может подключиться к Ollama.

### Решение

#### Если Ollama запущен на хосте (рекомендуется для macOS)

1. Проверьте, что Ollama запущен:
   ```bash
   curl http://localhost:11434/api/version
   ```

2. В конфигурации SiYuan измените URL на:
   ```json
   "ollama": {
     "apiBaseURL": "http://host.docker.internal:11434"
   }
   ```

3. Перезапустите контейнер:
   ```bash
   docker-compose restart digroup
   ```

#### Если используете Docker контейнер Ollama

1. Убедитесь, что контейнер запущен:
   ```bash
   docker-compose up -d ollama
   ```

2. В конфигурации используйте:
   ```json
   "ollama": {
     "apiBaseURL": "http://ollama:11434"
   }
   ```

3. Перезапустите SiYuan:
   ```bash
   docker-compose restart digroup
   ```

### Проверка работы AI

После исправления проверьте в логах:
```bash
docker logs digroup --tail 20
```

Не должно быть ошибок `connection refused` при запросах к Ollama.

---

## Проблема: Resource deadlock avoided при запуске

### Описание
В логах при запуске появляется:
```
E open /opt/siyuan/workspace/conf/appearance/icons/index.html: resource deadlock avoided
```

### Причина
Проблема с файловой системой при копировании ресурсов темы оформления.

### Решение
Это предупреждение можно игнорировать - оно не критично и не влияет на работу системы. SiYuan продолжает нормально работать после этой ошибки.

Если проблема повторяется и мешает работе:
1. Проверьте права доступа к директории `workspace`:
   ```bash
   ls -la workspace/conf/appearance/
   ```

2. При необходимости исправьте владельца:
   ```bash
   sudo chown -R 1000:1000 workspace/
   ```

---

## Дополнительная информация

### Логи
Для просмотра логов используйте:
```bash
# Все логи
docker logs digroup

# Последние 100 строк
docker logs digroup --tail 100

# Следить за логами в реальном времени
docker logs -f digroup
```

### Перезапуск сервисов
```bash
# Перезапуск всех сервисов
docker-compose restart

# Перезапуск только SiYuan
docker-compose restart digroup

# Полная пересборка
docker-compose down
docker-compose up -d --build
```

### Проверка конфигурации
Конфигурация находится в: `workspace/conf/conf.json`

Основные параметры:
- `accessAuthCode` - код доступа к API
- `sync` - настройки синхронизации
- `ai.ollama` - настройки Ollama AI
- `readonly` - режим только для чтения
