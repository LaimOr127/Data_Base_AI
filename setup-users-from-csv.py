#!/usr/bin/env python3
"""
Скрипт для загрузки пользователей из CSV и генерации хэшей паролей с помощью bcrypt.
"""
import json
import csv
import sys
import os
import bcrypt

def load_users_from_csv(csv_path):
    """Загружает пользователей из CSV файла."""
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
                    print(f"⚠️  Пропущен пользователь: отсутствует логин или пароль")
                    continue
                
                # Преобразуем роль
                role = 'editor'
                if role_str == 'visitor' or role_str == 'guest':
                    role = 'visitor'
                elif role_str == 'administrator' or role_str == 'admin':
                    role = 'administrator'
                elif role_str == 'reader' or role_str == 'read':
                    role = 'reader'
                
                # Генерируем хэш пароля с помощью bcrypt
                password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
                
                user = {
                    'username': login,
                    'password': password_hash,  # Сохраняем хэш
                    'role': role,
                    'memo': fio if fio else login
                }
                users.append(user)
                print(f"✓ Добавлен пользователь: {login} (роль: {role})")
    except Exception as e:
        print(f"❌ Ошибка при чтении CSV: {e}")
        sys.exit(1)
    
    return users

def update_conf_json(conf_path, users):
    """Обновляет conf.json с пользователями."""
    try:
        # Читаем текущий conf.json
        if os.path.exists(conf_path):
            with open(conf_path, 'r', encoding='utf-8') as f:
                conf = json.load(f)
        else:
            print(f"⚠️  Файл {conf_path} не найден, создаем новый")
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
        
        # Убеждаемся, что auth.enable = true
        conf['publish']['auth']['enable'] = True
        
        # Обновляем список пользователей
        conf['publish']['auth']['accounts'] = users
        
        # Сохраняем обновленный conf.json
        with open(conf_path, 'w', encoding='utf-8') as f:
            json.dump(conf, f, ensure_ascii=False, indent=2)
        
        # Также сохраняем в отдельный файл для резервного копирования
        users_db_path = 'users_db/users_database.json'
        with open(users_db_path, 'w', encoding='utf-8') as f:
            json.dump({'accounts': users}, f, ensure_ascii=False, indent=2)
        
        print(f"\n✓ Обновлен {conf_path}")
        print(f"✓ Сохранено в резервный файл {users_db_path}")
        print(f"✓ Загружено пользователей: {len(users)}")
        
    except Exception as e:
        print(f"❌ Ошибка при обновлении conf.json: {e}")
        sys.exit(1)

def main():
    csv_path = 'users_db/users.csv'
    conf_path = 'workspace/conf/conf.json'
    
    if not os.path.exists(csv_path):
        print(f"❌ Файл {csv_path} не найден")
        sys.exit(1)
    
    print(f"📖 Загрузка пользователей из {csv_path}...")
    users = load_users_from_csv(csv_path)
    
    if not users:
        print("❌ Не найдено пользователей для загрузки")
        sys.exit(1)
    
    print(f"\n📝 Обновление {conf_path}...")
    update_conf_json(conf_path, users)
    
    print("\n✅ Готово! Пользователи загружены и пароли захешированы.")
    print("\n⚠️  ВАЖНО: Сохраните список паролей для администратора!")
    print("   Пароли хранятся в открытом виде в CSV файле.")

if __name__ == '__main__':
    main()
