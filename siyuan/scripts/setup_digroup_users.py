#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Скрипт для настройки пользователей в конфигурации DIGroup
Добавляет пользователей в Publish Service для базовой аутентификации
"""

import json
import os
from pathlib import Path

def load_users_db():
    """Загрузка БД пользователей"""
    script_dir = Path(__file__).parent
    # БД находится в корне проекта, не в siyuan/
    db_file = script_dir.parent.parent / "users_db" / "users_database.json"
    
    if not db_file.exists():
        print(f"❌ Файл БД не найден: {db_file}")
        print("Сначала запустите: python3 create_users_db.py")
        return None
    
    with open(db_file, 'r', encoding='utf-8') as f:
        return json.load(f)

def load_digroup_config():
    """Загрузка конфигурации DIGroup"""
    workspace_dir = Path.home() / "DIGroup-workspace"
    conf_file = workspace_dir / "conf" / "conf.json"
    
    if not conf_file.exists():
        print(f"❌ Конфигурация не найдена: {conf_file}")
        print("Убедитесь, что DIGroup запущен хотя бы один раз")
        return None, conf_file
    
    with open(conf_file, 'r', encoding='utf-8') as f:
        return json.load(f), conf_file

def setup_publish_auth(config, users):
    """Настройка аутентификации в Publish Service"""
    if 'publish' not in config:
        config['publish'] = {}
    
    if 'auth' not in config['publish']:
        config['publish']['auth'] = {}
    
    # Включаем аутентификацию
    config['publish']['auth']['enable'] = True
    
    # Добавляем аккаунты
    accounts = []
    for user in users:
        # Используем роль из БД, если указана, иначе определяем по умолчанию
        role = user.get('role', 'editor')
        if user['login'] == 'guest':
            role = 'visitor'
        elif role not in ['administrator', 'admin', 'editor', 'edit', 'reader', 'read', 'visitor', 'guest']:
            # Если роль не распознана, используем роль из БД или по умолчанию editor
            role = user.get('role', 'editor')
            if role not in ['administrator', 'admin', 'editor', 'edit', 'reader', 'read', 'visitor', 'guest']:
                role = 'editor'  # По умолчанию editor
        
        accounts.append({
            'username': user['login'],
            'password': user['password'],
            'role': role
        })
    
    config['publish']['auth']['accounts'] = accounts
    
    return config

def main():
    print("🔧 Настройка пользователей в DIGroup")
    print("=" * 60)
    
    # Загружаем БД пользователей
    print("\n1️⃣  Загрузка БД пользователей...")
    users = load_users_db()
    if not users:
        return
    
    print(f"   ✅ Загружено пользователей: {len(users)}")
    
    # Загружаем конфигурацию DIGroup
    print("\n2️⃣  Загрузка конфигурации DIGroup...")
    config, conf_file = load_digroup_config()
    if not config:
        return
    
    print(f"   ✅ Конфигурация загружена: {conf_file}")
    
    # Настраиваем аутентификацию
    print("\n3️⃣  Настройка аутентификации...")
    config = setup_publish_auth(config, users)
    print(f"   ✅ Добавлено аккаунтов: {len(users)}")
    
    # Сохраняем конфигурацию
    print("\n4️⃣  Сохранение конфигурации...")
    
    # Создаем резервную копию
    backup_file = conf_file.with_suffix('.json.backup')
    if conf_file.exists():
        import shutil
        shutil.copy2(conf_file, backup_file)
        print(f"   💾 Резервная копия: {backup_file}")
    
    # Сохраняем новую конфигурацию
    with open(conf_file, 'w', encoding='utf-8') as f:
        json.dump(config, f, ensure_ascii=False, indent=2)
    
    print(f"   ✅ Конфигурация сохранена: {conf_file}")
    
    # Выводим статистику
    print("\n📊 Статистика:")
    print(f"   - Всего пользователей: {len(users)}")
    print(f"   - Сотрудников: {len([u for u in users if u['login'] != 'guest'])}")
    print(f"   - Гостевой доступ: {len([u for u in users if u['login'] == 'guest'])}")
    
    print("\n✅ Настройка завершена!")
    print("\n📝 Следующие шаги:")
    print("   1. Перезапустите kernel DIGroup")
    print("   2. Проверьте доступ: curl -u логин:пароль http://localhost:8081/api/system/version")
    print("   3. Список пользователей: cat users_db/users_list.txt")

if __name__ == "__main__":
    main()

