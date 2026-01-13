#!/usr/bin/env python3
import json
import sys
import os

# Читаем список пользователей
users_file = 'users_db/users_list.txt'
if not os.path.exists(users_file):
    users_file = 'digroup-test/users_db/users_list.txt'

with open(users_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Парсим пользователей
users = []
blocks = content.split('--------------------------------------------------------------------------------')

for block in blocks:
    if 'Логин:' in block and 'Пароль:' in block:
        lines = block.strip().split('\n')
        user = {}
        for line in lines:
            if line.startswith('ФИО:'):
                user['memo'] = line.replace('ФИО:', '').strip()
            elif line.startswith('Логин:'):
                user['username'] = line.replace('Логин:', '').strip()
            elif line.startswith('Пароль:'):
                user['password'] = line.replace('Пароль:', '').strip()
            elif line.startswith('Роль:'):
                role = line.replace('Роль:', '').strip()
                if role == 'visitor':
                    user['role'] = 'visitor'
                else:
                    user['role'] = 'editor'
        
        if 'username' in user and 'password' in user:
            users.append(user)

# Читаем текущий conf.json
conf_path = 'workspace/conf/conf.json'
try:
    with open(conf_path, 'r', encoding='utf-8') as f:
        conf = json.load(f)
except FileNotFoundError:
    print(f"Файл {conf_path} не найден, создаем новый")
    conf = {}

# Инициализируем publish структуру
if 'publish' not in conf:
    conf['publish'] = {
        'enable': True,
        'port': 6808,
        'auth': {
            'enable': True,
            'accounts': []
        }
    }
elif 'auth' not in conf['publish']:
    conf['publish']['auth'] = {
        'enable': True,
        'accounts': []
    }

# Добавляем пользователей
conf['publish']['auth']['accounts'] = users
conf['publish']['auth']['enable'] = True

# Сохраняем
with open(conf_path, 'w', encoding='utf-8') as f:
    json.dump(conf, f, ensure_ascii=False, indent=2)

print(f"✓ Добавлено {len(users)} пользователей в {conf_path}")
print(f"  - Администраторов: {sum(1 for u in users if u.get('role') == 'administrator')}")
print(f"  - Редакторов: {sum(1 for u in users if u.get('role') == 'editor')}")
print(f"  - Посетителей: {sum(1 for u in users if u.get('role') == 'visitor')}")
