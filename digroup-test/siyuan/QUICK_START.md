# ⚡ Быстрый запуск DIGroup

## 🚀 Запуск одной командой

```bash
cd /Users/alexey_pripadchev/Documents/Work/data_base/siyuan/scripts
./start_digroup.sh
```

Этот скрипт:
1. ✅ Остановит старые процессы
2. ✅ Запустит kernel
3. ✅ Дождется готовности kernel
4. ✅ Соберет frontend (если нужно)
5. ✅ Запустит Electron приложение

---

## 🛑 Остановка

```bash
cd /Users/alexey_pripadchev/Documents/Work/data_base/siyuan/scripts
./stop_digroup.sh
```

Или вручную:
```bash
pkill -f SiYuan-Kernel
pkill -f electron
```

---

## 👥 Система пользователей и ролей

### Роли пользователей:

- **Administrator (admin)** - Полный доступ, может все
- **Editor (editor)** - Может создавать и редактировать документы
- **Reader (reader)** - Только чтение
- **Visitor (visitor/guest)** - Гостевой доступ, только чтение

### Настройка пользователей:

Пользователи уже настроены из Excel файла:
- **131 пользователь** создан
- **Логины** - по инициалам (например: sha, fk, fyu)
- **Пароли** - инициалы + "123" (например: sha123, fk123)
- **Роли** - по умолчанию "editor" (редактор)
- **Гостевой доступ** - логин: `guest`, пароль: `guest123`

### Проверка пользователей:

```bash
# Список пользователей
cat siyuan/users_db/users_list.txt

# Проверка конфигурации
cat ~/DIGroup-workspace/conf/conf.json | python3 -c "import json, sys; c=json.load(sys.stdin); accounts = c.get('publish', {}).get('auth', {}).get('accounts', []); print(f'Пользователей: {len(accounts)}'); [print(f'  {a.get(\"username\")}: {a.get(\"role\", \"editor\")}') for a in accounts[:20]]"
```

---

## 🔐 Доступ

### Локальный доступ (Electron):
- Откроется автоматически после запуска
- AccessAuthCode: `b226ba0f30a134fe9245792118bca202`

### Веб-доступ:
- URL: `http://localhost:8081`
- AccessAuthCode: `b226ba0f30a134fe9245792118bca202`

### Доступ через Publish Service (с ролями):
- URL: `http://localhost:6808` (если включен)
- Используйте логин и пароль пользователя
- Роли применяются автоматически

---

## 📊 Проверка работы

### Быстрый тест (автоматический):
```bash
cd siyuan/scripts
./test_access.sh локальный    # Для локального теста
./test_access.sh удаленный     # Для теста с других устройств
```

### Ручная проверка:

#### Локальный доступ:
```bash
# Проверка версии
curl http://localhost:6806/api/system/version

# Проверка пользователя-редактора
curl -u sha:sha123 http://localhost:6806/api/system/version

# Проверка гостевого доступа
curl -u guest:guest123 http://localhost:6806/api/system/version
```

#### Доступ с других устройств:
```bash
# Получить IP адрес
ifconfig | grep "inet " | grep -v 127.0.0.1

# Проверка (замените YOUR_IP на ваш IP)
curl http://YOUR_IP:6806/api/system/version
curl -u sha:sha123 http://YOUR_IP:6806/api/system/version
```

### Ссылки для тестирования:

**Локальный доступ (на этом компьютере):**
- Веб-интерфейс: http://localhost:6806
- API: http://localhost:6806/api/system/version

**Доступ с других устройств (в той же сети):**
- Веб-интерфейс: http://YOUR_IP:6806
- API: http://YOUR_IP:6806/api/system/version

Где `YOUR_IP` - ваш IP адрес в локальной сети (показывается при запуске `start_digroup.sh`)

### Логи:
```bash
# Kernel
tail -f /tmp/digroup-kernel.log

# Electron
tail -f /tmp/digroup-electron.log
```

---

## 🔧 Настройка ролей

Роли настраиваются в конфигурации:
```json
{
  "publish": {
    "auth": {
      "accounts": [
        {
          "username": "sha",
          "password": "sha123",
          "role": "editor"  // administrator, editor, reader, visitor
        }
      ]
    }
  }
}
```

После изменения конфигурации:
1. Перезапустите kernel
2. Роли применятся автоматически

---

## ✅ Готово!

Теперь DIGroup запускается одной командой, и все пользователи имеют правильные роли! 🎉
