#!/usr/bin/env python3
"""
Скрипт для регенерации паролей пользователей из CSV.
Используется для обновления хэшей паролей в conf.json.
"""
import json
import csv
import sys
import os
import bcrypt

def regenerate_passwords(csv_path, conf_path):
    """Регенерирует хэши паролей из CSV и обновляет conf.json."""
    users = []
    try:
        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                login = row.get('Логин', '').strip()
                password = row.get('Пароль', '').strip()
                role_str = row.get('Роль', 'editor').strip().lower()
                fio = row.get('ФИО', '').strip()
                
                if not login or not password:
                    continue
                
                # Преобразуем роль
                role = 'editor'
                if role_str == 'visitor' or role_str == 'guest':
                    role = 'visitor'
                elif role_str == 'administrator' or role_str == 'admin':
                    role = 'administrator'
                elif role_str == 'reader' or role_str == 'read':
                    role = 'reader'
                
                # Генерируем новый хэш пароля
                password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
                
                user = {
                    'username': login,
                    'password': password_hash,
                    'role': role,
                    'memo': fio if fio else login
                }
                users.append(user)
    except Exception as e:
        print(f"❌ Ошибка при чтении CSV: {e}")
        sys.exit(1)
    
    try:
        # Читаем текущий conf.json
        with open(conf_path, 'r', encoding='utf-8') as f:
            conf = json.load(f)
        
        # Обновляем список пользователей
        if 'publish' not in conf:
            conf['publish'] = {'enable': False, 'port': 6808, 'auth': {'enable': True, 'accounts': []}}
        elif 'auth' not in conf['publish']:
            conf['publish']['auth'] = {'enable': True, 'accounts': []}
        
        conf['publish']['auth']['enable'] = True
        conf['publish']['auth']['accounts'] = users
        
        # Сохраняем обновленный conf.json
        with open(conf_path, 'w', encoding='utf-8') as f:
            json.dump(conf, f, ensure_ascii=False, indent=2)
        
        print(f"✅ Регенерированы пароли для {len(users)} пользователей")
        
    except Exception as e:
        print(f"❌ Ошибка при обновлении conf.json: {e}")
        sys.exit(1)

if __name__ == '__main__':
    csv_path = 'users_db/users.csv'
    conf_path = 'workspace/conf/conf.json'
    
    if not os.path.exists(csv_path):
        print(f"❌ Файл {csv_path} не найден")
        sys.exit(1)
    
    regenerate_passwords(csv_path, conf_path)
