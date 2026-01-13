# ⚡ Быстрая настройка облачной синхронизации

## ✅ Уже настроено!

Облачная синхронизация настроена через **iCloud Drive**.

### 📁 Папка синхронизации:
```
~/Library/Mobile Documents/com~apple~CloudDocs/DIGroup-sync
```

Эта папка автоматически синхронизируется через iCloud между всеми вашими устройствами Apple.

---

## 🚀 Активация синхронизации

### Шаг 1: Перезапустите kernel

```bash
pkill -f SiYuan-Kernel
cd /Users/alexey_pripadchev/Documents/Work/data_base/siyuan/app/kernel
./SiYuan-Kernel --wd=.. --workspace=~/DIGroup-workspace --accessAuthCode=b226ba0f30a134fe9245792118bca202 --port=6806 --mode=dev &
```

### Шаг 2: Включите синхронизацию в интерфейсе

1. Откройте DIGroup
2. Перейдите в **Настройки** → **Синхронизация**
3. Нажмите **"Включить облачную синхронизацию"**
4. Выберите или создайте директорию `main`
5. Нажмите **"Создать"** или **"Выбрать"**

### Шаг 3: Проверьте статус

В настройках синхронизации должно отображаться:
- ✅ **"Синхронизировано"** - когда синхронизация завершена
- ⏰ **Время последней синхронизации**
- 📊 **Статистика** - количество файлов

---

## 🔄 Настройка на втором устройстве

### На другом Mac:

1. Установите DIGroup
2. Настройте синхронизацию с той же папкой:
   ```
   ~/Library/Mobile Documents/com~apple~CloudDocs/DIGroup-sync
   ```
3. Включите синхронизацию
4. Выберите ту же директорию `main`
5. Данные начнут синхронизироваться автоматически!

### На сервере или другом устройстве:

Если у вас нет iCloud на сервере, используйте один из вариантов:

1. **S3-хранилище** (Yandex Object Storage, AWS S3 и др.)
2. **WebDAV сервер** (Nextcloud, OwnCloud и др.)
3. **Сетевая папка** (SMB/NFS)

См. подробную инструкцию: `CLOUD_SYNC_SETUP.md`

---

## 📊 Проверка работы

### Через интерфейс:
- **Настройки** → **Синхронизация** → проверьте статус

### Через API:
```bash
# Статус синхронизации
curl -u sha:sha123 http://localhost:8081/api/sync/getSyncInfo

# Запустить синхронизацию
curl -X POST -u sha:sha123 http://localhost:8081/api/sync/performSync
```

### Проверка файлов:
```bash
# Проверьте папку синхронизации
ls -la ~/Library/Mobile\ Documents/com~apple~CloudDocs/DIGroup-sync/main/

# Должны быть папки:
# - refs/ (ссылки)
# - objects/ (объекты данных)
# - snapshot/ (снимки)
```

---

## ⚙️ Настройки синхронизации

Текущие настройки:
- **Провайдер:** Local File System (iCloud Drive)
- **Режим:** Автоматическая (каждые 30 секунд)
- **Директория:** main
- **Включена:** Да

Изменить можно в:
- Интерфейсе: **Настройки** → **Синхронизация**
- Конфигурации: `~/DIGroup-workspace/conf/conf.json`

---

## 🔧 Изменить папку синхронизации

Если хотите использовать другую папку:

### Вариант 1: Dropbox
```bash
mkdir -p ~/Dropbox/DIGroup-sync
# Затем измените endpoint в конфигурации на:
# ~/Dropbox/DIGroup-sync
```

### Вариант 2: Обычная папка
```bash
mkdir -p ~/DIGroup-sync
# Затем измените endpoint в конфигурации на:
# ~/DIGroup-sync
```

### Вариант 3: Через скрипт
```bash
python3 siyuan/scripts/setup_cloud_sync.py
```

---

## 🐛 Если не работает

1. **Проверьте папку:**
   ```bash
   ls -la ~/Library/Mobile\ Documents/com~apple~CloudDocs/DIGroup-sync/
   ```

2. **Проверьте конфигурацию:**
   ```bash
   cat ~/DIGroup-workspace/conf/conf.json | grep -A 10 '"sync"'
   ```

3. **Проверьте логи:**
   ```bash
   tail -f /tmp/digroup-kernel.log | grep sync
   ```

4. **Перезапустите kernel** после изменения конфигурации

---

## ✅ Готово!

Теперь ваши данные автоматически синхронизируются через iCloud между всеми вашими устройствами Apple! 🎉

