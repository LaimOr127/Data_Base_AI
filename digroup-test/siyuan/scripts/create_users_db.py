#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Скрипт для создания базы данных пользователей из Excel файла
Генерирует логины и пароли на основе инициалов сотрудников
"""

import pandas as pd
import json
import hashlib
import re
import os
from pathlib import Path

def transliterate(text):
    """Транслитерация русских букв в латиницу"""
    translit_map = {
        'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo',
        'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
        'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
        'ф': 'f', 'х': 'h', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sch',
        'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
        'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E', 'Ё': 'Yo',
        'Ж': 'Zh', 'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K', 'Л': 'L', 'М': 'M',
        'Н': 'N', 'О': 'O', 'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T', 'У': 'U',
        'Ф': 'F', 'Х': 'H', 'Ц': 'Ts', 'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Sch',
        'Ъ': '', 'Ы': 'Y', 'Ь': '', 'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya'
    }
    result = ''
    for char in text:
        result += translit_map.get(char, char)
    return result

def get_initials(full_name):
    """Извлечение инициалов из полного имени"""
    if pd.isna(full_name) or not full_name:
        return None
    
    # Удаляем лишние пробелы и разбиваем на части
    parts = str(full_name).strip().split()
    
    if len(parts) >= 2:
        # Берем первую букву имени и первую букву фамилии
        first_initial = parts[1][0].upper() if len(parts) > 1 else ''
        last_initial = parts[0][0].upper() if len(parts) > 0 else ''
        
        # Транслитерация
        first_initial = transliterate(first_initial)
        last_initial = transliterate(last_initial)
        
        return f"{last_initial}{first_initial}"
    elif len(parts) == 1:
        return transliterate(parts[0][0].upper())
    
    return None

def generate_login(full_name, index=None):
    """Генерация логина на основе имени"""
    initials = get_initials(full_name)
    if not initials:
        return f"user{index}" if index else "user"
    
    # Очищаем от спецсимволов
    login = re.sub(r'[^a-zA-Z0-9]', '', initials).lower()
    
    # Если логин слишком короткий, добавляем индекс
    if len(login) < 2:
        login = f"{login}{index}" if index else f"{login}1"
    
    return login

def generate_password(full_name):
    """Генерация пароля на основе инициалов"""
    initials = get_initials(full_name)
    if not initials:
        return "Password123"
    
    # Пароль: инициалы + "123" для простоты
    password = f"{initials.lower()}123"
    return password

def read_excel_file(file_path):
    """Чтение Excel файла и извлечение данных сотрудников"""
    try:
        # Пробуем разные возможные листы
        df = pd.read_excel(file_path, sheet_name=0)
        
        # Ищем колонку с ФИО
        # В данном файле ФИО находится в колонке с индексом 2 (Unnamed: 2)
        name_col = None
        
        # Сначала пробуем колонку с индексом 2 (обычно это ФИО)
        if len(df.columns) > 2:
            test_col = df.columns[2]
            # Проверяем что в колонке есть полные имена
            sample = df[test_col].dropna().head(5)
            if len(sample) > 0:
                # Проверяем что хотя бы одно значение похоже на ФИО (3+ слова)
                has_full_names = any(isinstance(v, str) and len(v.split()) >= 2 for v in sample)
                if has_full_names:
                    name_col = test_col
        
        # Если не подошло, ищем по содержимому
        if not name_col:
            best_score = 0
            for col in df.columns:
                col_str = str(col).strip()
                # Пропускаем служебные колонки
                if any(skip in col_str.lower() for skip in ['№', 'номер', 'п.п', 'пп', 'id', 'подразделение', 'должность', 'день', 'график', 'телефон', 'почта', 'место']):
                    continue
                
                # Проверяем содержимое
                sample_values = df[col].dropna().head(10)
                if len(sample_values) == 0:
                    continue
                
                # Считаем полные имена (2+ слова)
                full_names_count = sum(1 for v in sample_values 
                                      if isinstance(v, str) and len(v.strip().split()) >= 2)
                score = full_names_count / len(sample_values) if len(sample_values) > 0 else 0
                
                if score > best_score and score > 0.3:
                    best_score = score
                    name_col = col
        
        # Если все еще не нашли, берем колонку 2 по умолчанию
        if not name_col:
            if len(df.columns) > 2:
                name_col = df.columns[2]
            elif len(df.columns) > 1:
                name_col = df.columns[1]
            else:
                name_col = df.columns[0]
        
        print(f"Используется колонка: {name_col}")
        
        # Извлекаем ФИО
        employees = []
        for idx, row in df.iterrows():
            full_name = row[name_col]
            if pd.notna(full_name) and str(full_name).strip():
                employees.append({
                    'full_name': str(full_name).strip(),
                    'row_index': idx + 2  # +2 потому что Excel нумерует с 1 и есть заголовок
                })
        
        return employees
    except Exception as e:
        print(f"Ошибка при чтении файла: {e}")
        return []

def create_users_database(employees):
    """Создание базы данных пользователей"""
    users = []
    login_counter = {}
    
    for emp in employees:
        full_name = emp['full_name']
        login = generate_login(full_name)
        
        # Проверяем уникальность логина
        original_login = login
        counter = 1
        while login in login_counter:
            login = f"{original_login}{counter}"
            counter += 1
        login_counter[login] = True
        
        password = generate_password(full_name)
        
        # Хешируем пароль (SHA256 для простоты)
        password_hash = hashlib.sha256(password.encode('utf-8')).hexdigest()
        
        users.append({
            'id': len(users) + 1,
            'full_name': full_name,
            'login': login,
            'password': password,  # Храним в открытом виде для вывода
            'password_hash': password_hash,
            'role': 'editor',  # По умолчанию редактор
            'active': True
        })
    
    # Добавляем гостевого пользователя
    users.append({
        'id': len(users) + 1,
        'full_name': 'Гостевой пользователь',
        'login': 'guest',
        'password': 'guest123',
        'password_hash': hashlib.sha256('guest123'.encode('utf-8')).hexdigest(),
        'role': 'visitor',  # Только чтение
        'active': True
    })
    
    return users

def main():
    # Путь к Excel файлу
    script_dir = Path(__file__).parent.parent
    excel_file = script_dir.parent / "Список сотрудников ООО Ди групп_на 05.09.2025 г_.xlsx"
    
    if not excel_file.exists():
        print(f"Файл не найден: {excel_file}")
        print("Ищу файл в текущей директории...")
        # Пробуем найти в текущей директории
        for f in script_dir.parent.iterdir():
            if 'список' in f.name.lower() and f.suffix in ['.xlsx', '.xls']:
                excel_file = f
                break
    
    if not excel_file.exists():
        print("Excel файл не найден!")
        return
    
    print(f"Читаю файл: {excel_file}")
    
    # Читаем сотрудников
    employees = read_excel_file(excel_file)
    print(f"Найдено сотрудников: {len(employees)}")
    
    if not employees:
        print("Не удалось извлечь данные сотрудников")
        return
    
    # Создаем базу пользователей
    users = create_users_database(employees)
    
    # Сохраняем в JSON
    output_dir = script_dir.parent / "users_db"
    output_dir.mkdir(exist_ok=True)
    
    # Полная БД (с хешами)
    db_file = output_dir / "users_database.json"
    with open(db_file, 'w', encoding='utf-8') as f:
        json.dump(users, f, ensure_ascii=False, indent=2)
    
    # Файл для вывода (без хешей, для удобства)
    output_file = output_dir / "users_list.txt"
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("=" * 80 + "\n")
        f.write("БАЗА ДАННЫХ ПОЛЬЗОВАТЕЛЕЙ DIGROUP\n")
        f.write("=" * 80 + "\n\n")
        
        for user in users:
            f.write(f"ID: {user['id']}\n")
            f.write(f"ФИО: {user['full_name']}\n")
            f.write(f"Логин: {user['login']}\n")
            f.write(f"Пароль: {user['password']}\n")
            f.write(f"Роль: {user['role']}\n")
            f.write("-" * 80 + "\n\n")
    
    # CSV файл для импорта
    csv_file = output_dir / "users.csv"
    df = pd.DataFrame([
        {
            'ID': u['id'],
            'ФИО': u['full_name'],
            'Логин': u['login'],
            'Пароль': u['password'],
            'Роль': u['role']
        }
        for u in users
    ])
    df.to_csv(csv_file, index=False, encoding='utf-8-sig')
    
    print(f"\n✅ База данных создана!")
    print(f"📁 JSON БД: {db_file}")
    print(f"📄 Список пользователей: {output_file}")
    print(f"📊 CSV файл: {csv_file}")
    print(f"\nВсего пользователей: {len(users)}")
    print(f"  - Сотрудников: {len(employees)}")
    print(f"  - Гостевой доступ: 1")
    
    # Выводим первые 5 пользователей для примера
    print("\nПримеры пользователей:")
    print("-" * 80)
    for user in users[:5]:
        print(f"  {user['login']:15} | {user['password']:15} | {user['full_name']}")

if __name__ == "__main__":
    main()

