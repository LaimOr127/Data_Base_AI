# ☁️ Настройка облачной синхронизации DIGroup

## 🎯 Цель: Синхронизация между несколькими устройствами

Облачная синхронизация позволяет работать с DIGroup на нескольких устройствах, автоматически синхронизируя все изменения.

---

## 📋 Варианты синхронизации

### Вариант 1: Local File System + Облачный диск (Рекомендуется для начала)

**Преимущества:**
- ✅ Простая настройка
- ✅ Бесплатно (использует ваш облачный диск)
- ✅ Работает с iCloud, Dropbox, OneDrive, Google Drive
- ✅ Не требует дополнительных серверов

**Как работает:**
1. DIGroup синхронизирует данные в локальную папку
2. Облачный диск автоматически синхронизирует эту папку между устройствами
3. На других устройствах DIGroup использует ту же папку

**Настройка:**

#### Для macOS с iCloud:
```bash
# Создайте папку в iCloud
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/DIGroup-sync

# Настройте в DIGroup
# Путь: ~/Library/Mobile Documents/com~apple~CloudDocs/DIGroup-sync
```

#### Для Dropbox:
```bash
# Создайте папку в Dropbox
mkdir -p ~/Dropbox/DIGroup-sync

# Настройте в DIGroup
# Путь: ~/Dropbox/DIGroup-sync
```

#### Для OneDrive (через Finder):
```bash
# Создайте папку в OneDrive
mkdir -p ~/OneDrive/DIGroup-sync

# Настройте в DIGroup
# Путь: ~/OneDrive/DIGroup-sync
```

---

### Вариант 2: S3-совместимое хранилище

**Преимущества:**
- ✅ Надежное хранилище
- ✅ Масштабируемость
- ✅ Поддержка многих провайдеров (AWS S3, MinIO, Yandex Object Storage и др.)

**Поддерживаемые провайдеры:**
- AWS S3
- Yandex Object Storage
- MinIO
- DigitalOcean Spaces
- Backblaze B2
- Другие S3-совместимые хранилища

**Настройка:**

1. Создайте bucket в вашем S3-хранилище
2. Получите Access Key и Secret Key
3. Настройте в DIGroup:
   - **Endpoint:** адрес вашего S3-сервера
   - **Access Key:** ваш ключ доступа
   - **Secret Key:** ваш секретный ключ
   - **Bucket:** имя bucket
   - **Region:** регион (например, us-east-1)

**Пример для Yandex Object Storage:**
```
Endpoint: storage.yandexcloud.net
Region: ru-central1
Bucket: digroup-sync
```

---

### Вариант 3: WebDAV сервер

**Преимущества:**
- ✅ Работает с любым WebDAV сервером
- ✅ Поддержка стандартного протокола

**Поддерживаемые сервисы:**
- Nextcloud
- OwnCloud
- Seafile
- Yandex Disk (WebDAV)
- Другие WebDAV серверы

**Настройка:**

1. Настройте WebDAV на вашем сервере
2. Получите URL, username и password
3. Настройте в DIGroup:
   - **Endpoint:** URL WebDAV сервера (например, https://cloud.example.com/remote.php/dav/files/username/)
   - **Username:** имя пользователя
   - **Password:** пароль

**Пример для Nextcloud:**
```
Endpoint: https://nextcloud.example.com/remote.php/dav/files/username/
Username: username
Password: password
```

---

## 🚀 Быстрая настройка через скрипт

### Автоматическая настройка:

```bash
cd /Users/alexey_pripadchev/Documents/Work/data_base/siyuan/scripts
python3 setup_cloud_sync.py
```

Скрипт поможет выбрать провайдер и настроить синхронизацию.

---

## 📋 Ручная настройка через интерфейс

### Шаг 1: Откройте настройки синхронизации

1. Откройте DIGroup
2. Перейдите в **Настройки** → **Синхронизация**

### Шаг 2: Выберите провайдер

1. В разделе **Провайдер синхронизации** выберите нужный:
   - **Local File System** - для локальной папки + облачный диск
   - **S3** - для S3-хранилища
   - **WebDAV** - для WebDAV сервера

2. Нажмите **"Настроить"**

### Шаг 3: Введите параметры

**Для Local File System:**
- Укажите путь к папке синхронизации
- Папка должна существовать
- Папка не должна быть внутри workspace

**Для S3:**
- Endpoint
- Access Key
- Secret Key
- Bucket
- Region

**Для WebDAV:**
- Endpoint (URL)
- Username
- Password

### Шаг 4: Включите синхронизацию

1. Нажмите **"Включить облачную синхронизацию"**
2. Выберите или создайте директорию синхронизации (например, `main`)
3. Нажмите **"Создать"** или **"Выбрать"**

---

## 📋 Ручная настройка через конфигурацию

Отредактируйте `~/DIGroup-workspace/conf/conf.json`:

### Local File System:

```json
{
  "sync": {
    "enabled": true,
    "provider": 4,
    "cloudName": "main",
    "mode": 1,
    "interval": 30,
    "local": {
      "endpoint": "/Users/alexey_pripadchev/DIGroup-sync",
      "timeout": 60,
      "concurrentReqs": 8
    }
  }
}
```

### S3:

```json
{
  "sync": {
    "enabled": true,
    "provider": 2,
    "cloudName": "main",
    "mode": 1,
    "interval": 30,
    "s3": {
      "endpoint": "storage.yandexcloud.net",
      "accessKey": "ваш-access-key",
      "secretKey": "ваш-secret-key",
      "bucket": "digroup-sync",
      "region": "ru-central1",
      "pathStyle": true,
      "skipTlsVerify": false,
      "timeout": 60,
      "concurrentReqs": 8
    }
  }
}
```

### WebDAV:

```json
{
  "sync": {
    "enabled": true,
    "provider": 3,
    "cloudName": "main",
    "mode": 1,
    "interval": 30,
    "webdav": {
      "endpoint": "https://cloud.example.com/remote.php/dav/files/username/",
      "username": "username",
      "password": "password",
      "skipTlsVerify": false,
      "timeout": 60,
      "concurrentReqs": 8
    }
  }
}
```

После изменения конфигурации перезапустите kernel.

---

## 🔄 Настройка на втором устройстве

### Шаг 1: Установите DIGroup

Установите DIGroup на второе устройство (компьютер, сервер и т.д.)

### Шаг 2: Настройте ту же синхронизацию

1. Откройте **Настройки** → **Синхронизация**
2. Выберите тот же провайдер
3. Укажите те же параметры:
   - **Local File System:** та же папка (через облачный диск)
   - **S3:** те же credentials и bucket
   - **WebDAV:** те же credentials

### Шаг 3: Включите синхронизацию

1. Нажмите **"Включить облачную синхронизацию"**
2. Выберите ту же директорию синхронизации (`main`)
3. Данные начнут синхронизироваться автоматически

---

## ✅ Проверка работы синхронизации

### В интерфейсе:

1. Откройте **Настройки** → **Синхронизация**
2. Проверьте статус:
   - **"Синхронизировано"** - последняя синхронизация прошла успешно
   - **Время последней синхронизации** - когда была последняя синхронизация
   - **Статистика** - количество синхронизированных файлов

### Через API:

```bash
# Получить информацию о синхронизации
curl -u sha:sha123 http://localhost:8081/api/sync/getSyncInfo

# Запустить синхронизацию вручную
curl -X POST -u sha:sha123 http://localhost:8081/api/sync/performSync
```

### Проверка файлов:

**Для Local File System:**
```bash
ls -la ~/DIGroup-sync/main/
# Должны быть папки: refs/, objects/, snapshot/
```

**Для S3:**
- Проверьте bucket в вашем S3-хранилище
- Должны быть объекты в bucket

**Для WebDAV:**
- Проверьте файлы на WebDAV сервере
- Должны быть папки и файлы синхронизации

---

## 🔧 Режимы синхронизации

### Режим 1: Автоматическая (рекомендуется)

- Синхронизация происходит автоматически каждые N секунд
- Настраивается через `interval` (по умолчанию 30 секунд)
- Изменения синхронизируются автоматически

### Режим 2: Ручная

- Синхронизация только по запросу
- Нажмите кнопку "Синхронизировать" в интерфейсе
- Или используйте API: `POST /api/sync/performSync`

### Режим 3: Полностью ручная

- Полный контроль над синхронизацией
- Синхронизация только когда вы явно запросите

---

## 🐛 Решение проблем

### Проблема 1: "endpoint is in workspace"

**Решение:** Папка синхронизации не должна быть внутри workspace или родительской для workspace.

Используйте отдельную папку:
```bash
mkdir -p ~/DIGroup-sync
```

### Проблема 2: "endpoint not exist"

**Решение:** Создайте папку перед настройкой:
```bash
mkdir -p ~/DIGroup-sync
```

### Проблема 3: Синхронизация не работает

**Решение:**
1. Проверьте, что `enabled: true` в конфигурации
2. Проверьте логи: `tail -f /tmp/digroup-kernel.log | grep sync`
3. Проверьте доступность хранилища:
   - **Local:** `ls -la ~/DIGroup-sync/`
   - **S3:** проверьте доступ к bucket
   - **WebDAV:** проверьте доступ к серверу

### Проблема 4: Конфликты синхронизации

**Решение:**
1. Включите генерацию конфликтных документов: `generateConflictDoc: true`
2. Конфликты будут сохранены как отдельные документы
3. Разрешите конфликты вручную

### Проблема 5: Медленная синхронизация

**Решение:**
1. Увеличьте `concurrentReqs` (количество одновременных запросов)
2. Увеличьте `timeout` (таймаут запросов)
3. Проверьте скорость интернета/сети

---

## 💡 Рекомендации

### Для команды из 50 человек:

1. **Используйте S3 или WebDAV** - более надежно для большого количества пользователей
2. **Настройте отдельные директории** для разных проектов/команд
3. **Используйте автоматическую синхронизацию** - изменения будут видны всем быстро
4. **Регулярно делайте бэкапы** - на всякий случай

### Для личного использования:

1. **Local File System + облачный диск** - самый простой вариант
2. **iCloud/Dropbox/OneDrive** - бесплатно и удобно
3. **Автоматическая синхронизация** - не нужно думать о синхронизации

### Для продакшена:

1. **S3 или WebDAV** - более надежно
2. **Регулярные бэкапы** - обязательно
3. **Мониторинг синхронизации** - следите за ошибками
4. **HTTPS для WebDAV** - безопасность

---

## 📝 Примеры конфигураций

### Пример 1: iCloud Drive (macOS)

```json
{
  "sync": {
    "enabled": true,
    "provider": 4,
    "cloudName": "main",
    "mode": 1,
    "interval": 30,
    "local": {
      "endpoint": "/Users/alexey_pripadchev/Library/Mobile Documents/com~apple~CloudDocs/DIGroup-sync"
    }
  }
}
```

### Пример 2: Dropbox

```json
{
  "sync": {
    "enabled": true,
    "provider": 4,
    "cloudName": "main",
    "mode": 1,
    "interval": 30,
    "local": {
      "endpoint": "/Users/alexey_pripadchev/Dropbox/DIGroup-sync"
    }
  }
}
```

### Пример 3: Yandex Object Storage

```json
{
  "sync": {
    "enabled": true,
    "provider": 2,
    "cloudName": "main",
    "mode": 1,
    "interval": 30,
    "s3": {
      "endpoint": "storage.yandexcloud.net",
      "accessKey": "ваш-key",
      "secretKey": "ваш-secret",
      "bucket": "digroup-sync",
      "region": "ru-central1"
    }
  }
}
```

### Пример 4: Nextcloud WebDAV

```json
{
  "sync": {
    "enabled": true,
    "provider": 3,
    "cloudName": "main",
    "mode": 1,
    "interval": 30,
    "webdav": {
      "endpoint": "https://nextcloud.example.com/remote.php/dav/files/username/",
      "username": "username",
      "password": "password"
    }
  }
}
```

---

## 🔄 После настройки

1. **Перезапустите kernel:**
   ```bash
   pkill -f SiYuan-Kernel
   cd /Users/alexey_pripadchev/Documents/Work/data_base/siyuan/app/kernel
   ./SiYuan-Kernel --wd=.. --workspace=~/DIGroup-workspace --accessAuthCode=КОД --port=6806 --mode=dev &
   ```

2. **Проверьте статус синхронизации** в интерфейсе

3. **Создайте тестовую заметку** и проверьте синхронизацию

4. **На втором устройстве** настройте ту же синхронизацию

---

## 📞 Полезные команды

```bash
# Проверить статус синхронизации
curl -u sha:sha123 http://localhost:8081/api/sync/getSyncInfo

# Запустить синхронизацию вручную
curl -X POST -u sha:sha123 http://localhost:8081/api/sync/performSync

# Проверить логи синхронизации
tail -f /tmp/digroup-kernel.log | grep sync

# Проверить файлы синхронизации (Local)
ls -la ~/DIGroup-sync/main/
```

---

## ✅ Чеклист настройки

- [ ] Выбран провайдер синхронизации
- [ ] Настроены параметры (путь/credentials)
- [ ] Конфигурация сохранена
- [ ] Kernel перезапущен
- [ ] Синхронизация включена в интерфейсе
- [ ] Директория синхронизации создана/выбрана
- [ ] Проверена работа синхронизации
- [ ] Настроено на втором устройстве (если нужно)

**Готово! Теперь ваши данные синхронизируются между устройствами! 🎉**

