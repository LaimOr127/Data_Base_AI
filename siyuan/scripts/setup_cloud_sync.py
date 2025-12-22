#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Скрипт для настройки облачной синхронизации DIGroup
Поддерживает: Local File System, S3, WebDAV
"""

import json
import os
from pathlib import Path

def load_digroup_config():
    """Загрузка конфигурации DIGroup"""
    workspace_dir = Path.home() / "DIGroup-workspace"
    conf_file = workspace_dir / "conf" / "conf.json"
    
    if not conf_file.exists():
        print(f"❌ Конфигурация не найдена: {conf_file}")
        return None, conf_file
    
    with open(conf_file, 'r', encoding='utf-8') as f:
        return json.load(f), conf_file

def setup_local_sync(config, sync_path):
    """Настройка локальной синхронизации"""
    if 'sync' not in config:
        config['sync'] = {}
    
    config['sync']['provider'] = 4  # ProviderLocal
    config['sync']['enabled'] = True
    config['sync']['mode'] = 1  # Автоматическая синхронизация
    config['sync']['interval'] = 30  # Каждые 30 секунд
    config['sync']['cloudName'] = "main"
    
    if 'local' not in config['sync']:
        config['sync']['local'] = {}
    
    config['sync']['local']['endpoint'] = sync_path
    config['sync']['local']['timeout'] = 60
    config['sync']['local']['concurrentReqs'] = 8
    
    return config

def setup_s3_sync(config, endpoint, access_key, secret_key, bucket, region):
    """Настройка S3 синхронизации"""
    if 'sync' not in config:
        config['sync'] = {}
    
    config['sync']['provider'] = 2  # ProviderS3
    config['sync']['enabled'] = True
    config['sync']['mode'] = 1
    config['sync']['interval'] = 30
    config['sync']['cloudName'] = "main"
    
    if 's3' not in config['sync']:
        config['sync']['s3'] = {}
    
    config['sync']['s3']['endpoint'] = endpoint
    config['sync']['s3']['accessKey'] = access_key
    config['sync']['s3']['secretKey'] = secret_key
    config['sync']['s3']['bucket'] = bucket
    config['sync']['s3']['region'] = region
    config['sync']['s3']['pathStyle'] = True
    config['sync']['s3']['skipTlsVerify'] = False
    config['sync']['s3']['timeout'] = 60
    config['sync']['s3']['concurrentReqs'] = 8
    
    return config

def setup_webdav_sync(config, endpoint, username, password):
    """Настройка WebDAV синхронизации"""
    if 'sync' not in config:
        config['sync'] = {}
    
    config['sync']['provider'] = 3  # ProviderWebDAV
    config['sync']['enabled'] = True
    config['sync']['mode'] = 1
    config['sync']['interval'] = 30
    config['sync']['cloudName'] = "main"
    
    if 'webdav' not in config['sync']:
        config['sync']['webdav'] = {}
    
    config['sync']['webdav']['endpoint'] = endpoint
    config['sync']['webdav']['username'] = username
    config['sync']['webdav']['password'] = password
    config['sync']['webdav']['skipTlsVerify'] = False
    config['sync']['webdav']['timeout'] = 60
    config['sync']['webdav']['concurrentReqs'] = 8
    
    return config

def main():
    import sys
    
    print("☁️  Настройка облачной синхронизации DIGroup")
    print("=" * 60)
    
    # Загружаем конфигурацию
    config, conf_file = load_digroup_config()
    if not config:
        return
    
    print(f"\n✅ Конфигурация загружена: {conf_file}")
    
    # Выбор провайдера
    print("\n📋 Выберите провайдер синхронизации:")
    print("1. Local File System (локальная папка + облачный диск)")
    print("2. S3 (S3-совместимое хранилище)")
    print("3. WebDAV (WebDAV сервер)")
    print("4. Отмена")
    
    choice = input("\nВаш выбор (1-4): ").strip()
    
    if choice == "1":
        # Local File System
        print("\n📁 Настройка Local File System")
        print("\nВарианты:")
        print("1. Локальная папка: ~/DIGroup-sync")
        print("2. iCloud Drive: ~/Library/Mobile Documents/com~apple~CloudDocs/DIGroup-sync")
        print("3. Dropbox: ~/Dropbox/DIGroup-sync")
        print("4. Другой путь (введите вручную)")
        
        path_choice = input("\nВаш выбор (1-4): ").strip()
        
        if path_choice == "1":
            sync_path = str(Path.home() / "DIGroup-sync")
        elif path_choice == "2":
            sync_path = str(Path.home() / "Library" / "Mobile Documents" / "com~apple~CloudDocs" / "DIGroup-sync")
        elif path_choice == "3":
            sync_path = str(Path.home() / "Dropbox" / "DIGroup-sync")
        else:
            sync_path = input("Введите путь к папке синхронизации: ").strip()
        
        # Создаем папку
        Path(sync_path).mkdir(parents=True, exist_ok=True)
        print(f"✅ Папка создана/проверена: {sync_path}")
        
        config = setup_local_sync(config, sync_path)
        print(f"✅ Локальная синхронизация настроена")
        
    elif choice == "2":
        # S3
        print("\n☁️  Настройка S3")
        endpoint = input("Endpoint (например, s3.amazonaws.com): ").strip()
        access_key = input("Access Key: ").strip()
        secret_key = input("Secret Key: ").strip()
        bucket = input("Bucket: ").strip()
        region = input("Region (например, us-east-1): ").strip()
        
        config = setup_s3_sync(config, endpoint, access_key, secret_key, bucket, region)
        print("✅ S3 синхронизация настроена")
        
    elif choice == "3":
        # WebDAV
        print("\n🌐 Настройка WebDAV")
        endpoint = input("Endpoint (например, https://dav.example.com): ").strip()
        username = input("Username: ").strip()
        password = input("Password: ").strip()
        
        config = setup_webdav_sync(config, endpoint, username, password)
        print("✅ WebDAV синхронизация настроена")
        
    else:
        print("❌ Отменено")
        return
    
    # Сохраняем конфигурацию
    print("\n💾 Сохранение конфигурации...")
    
    # Резервная копия
    backup_file = conf_file.with_suffix('.json.backup')
    if conf_file.exists():
        import shutil
        shutil.copy2(conf_file, backup_file)
        print(f"   💾 Резервная копия: {backup_file}")
    
    # Сохраняем
    with open(conf_file, 'w', encoding='utf-8') as f:
        json.dump(config, f, ensure_ascii=False, indent=2)
    
    print(f"   ✅ Конфигурация сохранена: {conf_file}")
    
    print("\n✅ Настройка завершена!")
    print("\n📝 Следующие шаги:")
    print("   1. Перезапустите kernel DIGroup")
    print("   2. Откройте Настройки → Синхронизация в интерфейсе")
    print("   3. Нажмите 'Включить облачную синхронизацию'")
    print("   4. Создайте или выберите директорию синхронизации (main)")

if __name__ == "__main__":
    main()

