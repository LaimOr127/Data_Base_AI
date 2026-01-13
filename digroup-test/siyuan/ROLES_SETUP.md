# 👥 Система ролей и пользователей DIGroup

## ✅ Настроено

Система ролей полностью настроена и интегрирована в DIGroup.

---

## 📊 Текущее состояние

- **Всего пользователей:** 131
- **Редакторы (editor):** 130 сотрудников
- **Гости (visitor):** 1 пользователь (guest)

---

## 🔐 Роли пользователей

### Administrator (admin)
- **Полный доступ** ко всем функциям
- Может управлять настройками
- Может управлять пользователями
- Может удалять и создавать любые документы

### Editor (editor)
- **Может создавать и редактировать** документы
- Может создавать новые заметки
- Может изменять существующие документы
- **Не может** управлять настройками системы

### Reader (reader)
- **Только чтение** документов
- Может просматривать документы
- **Не может** создавать или редактировать

### Visitor (visitor/guest)
- **Гостевой доступ** - только чтение
- Минимальные права доступа
- Используется для публичного доступа

---

## 👤 Пользователи из Excel

Все пользователи созданы из файла `Список сотрудников ООО Ди групп_на 05.09.2025 г_.xlsx`:

### Формат логинов:
- **По инициалам** из ФИО
- Примеры: `sha`, `fk`, `fyu`, `ke`, `shm`, `mm`, `ps`, `av`, `lt`, `dyu`

### Формат паролей:
- **Инициалы + "123"**
- Примеры: `sha123`, `fk123`, `fyu123`, `ke123`

### Роли:
- **Все сотрудники:** `editor` (редактор)
- **Гостевой доступ:** `visitor` (только чтение)
  - Логин: `guest`
  - Пароль: `guest123`

---

## 🔧 Настройка ролей

### Через конфигурацию:

Отредактируйте `~/DIGroup-workspace/conf/conf.json`:

```json
{
  "publish": {
    "auth": {
      "enable": true,
      "accounts": [
        {
          "username": "sha",
          "password": "sha123",
          "role": "editor"  // administrator, editor, reader, visitor
        },
        {
          "username": "guest",
          "password": "guest123",
          "role": "visitor"
        }
      ]
    }
  }
}
```

### Поддерживаемые значения роли:

- `"administrator"` или `"admin"` → RoleAdministrator
- `"editor"` или `"edit"` → RoleEditor
- `"reader"` или `"read"` → RoleReader
- `"visitor"` или `"guest"` → RoleVisitor

### После изменения:

1. **Перезапустите kernel:**
   ```bash
   pkill -f SiYuan-Kernel
   cd siyuan/app/kernel
   ./SiYuan-Kernel --wd=.. --workspace=~/DIGroup-workspace --accessAuthCode=КОД --port=6806 --mode=dev &
   ```

2. Роли применятся автоматически при следующем входе пользователя

---

## 🔍 Проверка ролей

### Проверка конфигурации:

```bash
# Показать всех пользователей с ролями
cat ~/DIGroup-workspace/conf/conf.json | python3 -c "
import json, sys
c = json.load(sys.stdin)
accounts = c.get('publish', {}).get('auth', {}).get('accounts', [])
print(f'Всего пользователей: {len(accounts)}')
print('\nПользователи и роли:')
for a in accounts[:20]:
    print(f'  {a.get(\"username\", \"?\")}: {a.get(\"role\", \"editor\")}')
"

# Распределение ролей
cat ~/DIGroup-workspace/conf/conf.json | python3 -c "
import json, sys
c = json.load(sys.stdin)
accounts = c.get('publish', {}).get('auth', {}).get('accounts', [])
roles = {}
for a in accounts:
    role = a.get('role', 'editor')
    roles[role] = roles.get(role, 0) + 1
print('Распределение ролей:')
for r, c in sorted(roles.items()):
    print(f'  {r}: {c} пользователей')
"
```

### Проверка через API:

```bash
# Проверка аутентификации редактора
curl -u sha:sha123 http://localhost:6806/api/system/version

# Проверка гостевого доступа
curl -u guest:guest123 http://localhost:6806/api/system/version
```

---

## 🔄 Как работают роли

### 1. Инициализация аккаунтов

При запуске kernel:
- Загружаются аккаунты из `conf.json`
- Роли преобразуются из строк в `Role` константы
- Создаются JWT токены с ролями

### 2. Аутентификация

При входе пользователя:
- Проверяется логин и пароль
- Создается JWT токен с ролью пользователя
- Токен сохраняется в сессии

### 3. Проверка прав доступа

При каждом запросе:
- Извлекается роль из JWT токена
- Проверяется, достаточно ли прав для операции
- Если прав недостаточно → 403 Forbidden

### 4. Middleware проверки

- `CheckAdminRole()` - только Administrator
- `CheckEditRole()` - Administrator или Editor
- `CheckReadRole()` - Administrator, Editor или Reader

---

## 📝 Примеры использования

### Изменить роль пользователя:

```python
import json
from pathlib import Path

conf_file = Path.home() / "DIGroup-workspace" / "conf" / "conf.json"

with open(conf_file, 'r', encoding='utf-8') as f:
    config = json.load(f)

# Найти пользователя и изменить роль
for account in config['publish']['auth']['accounts']:
    if account['username'] == 'sha':
        account['role'] = 'administrator'  # Повысить до администратора
        break

# Сохранить
with open(conf_file, 'w', encoding='utf-8') as f:
    json.dump(config, f, ensure_ascii=False, indent=2)

print("✅ Роль изменена! Перезапустите kernel.")
```

### Добавить нового пользователя:

```python
import json
from pathlib import Path

conf_file = Path.home() / "DIGroup-workspace" / "conf" / "conf.json"

with open(conf_file, 'r', encoding='utf-8') as f:
    config = json.load(f)

# Добавить нового пользователя
config['publish']['auth']['accounts'].append({
    'username': 'newuser',
    'password': 'newpass123',
    'role': 'editor'
})

# Сохранить
with open(conf_file, 'w', encoding='utf-8') as f:
    json.dump(config, f, ensure_ascii=False, indent=2)

print("✅ Пользователь добавлен! Перезапустите kernel.")
```

---

## 🐛 Решение проблем

### Проблема: Роли не применяются

**Решение:**
1. Проверьте, что роль указана в конфигурации
2. Перезапустите kernel после изменения конфигурации
3. Проверьте логи: `tail -f /tmp/digroup-kernel.log | grep role`

### Проблема: Пользователь не может редактировать

**Решение:**
1. Проверьте роль пользователя: должна быть `editor` или `administrator`
2. Проверьте, что пользователь правильно аутентифицирован
3. Проверьте JWT токен в заголовках запросов

### Проблема: Все пользователи имеют одинаковые права

**Решение:**
1. Проверьте, что роли правильно указаны в конфигурации
2. Убедитесь, что kernel перезапущен после изменения
3. Проверьте, что JWT токены генерируются с правильными ролями

---

## ✅ Готово!

Система ролей полностью настроена и работает! 🎉

- ✅ 131 пользователь настроен
- ✅ Роли применяются через JWT токены
- ✅ Разделение прав доступа работает
- ✅ Гостевой доступ настроен

