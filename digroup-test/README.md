# Data_Base_AI

Система управления базой знаний DIGroup для командной работы.

## 🚀 Быстрый старт

### Полностью автоматическая установка (рекомендуется)

#### Для Linux (Ubuntu/Debian):
```bash
# Клонируйте репозиторий
git clone git@github.com:LaimOr127/Data_Base_AI.git /opt/digroup
cd /opt/digroup

# Запустите скрипт установки
sudo ./install.sh

# Или с доменом и SSL:
sudo ./install.sh --domain=digroup.yourdomain.com --email=admin@yourdomain.com
```

#### Для macOS:
```bash
# Клонируйте репозиторий
git clone git@github.com:LaimOr127/Data_Base_AI.git
cd Data_Base_AI

# Запустите скрипт установки (требуется Docker Desktop)
./install-macos.sh
```

#### Для Windows:
```powershell
# Клонируйте репозиторий
git clone git@github.com:LaimOr127/Data_Base_AI.git
cd Data_Base_AI

# Запустите скрипт установки (требуется Docker Desktop и PowerShell)
.\install-windows.ps1
```

**Скрипт автоматически установит:**
- ✅ DIGroup (основное приложение)
- ✅ Ollama (локальный ИИ)
- ✅ Локальный Supabase (база данных для аудита)
- ✅ Prometheus + Grafana (мониторинг)
- ✅ Nginx (reverse proxy)
- ✅ Все зависимости и библиотеки
- ✅ SSL сертификат (если указан домен)
- ✅ Автоматические бэкапы

**После установки вы получите:**
- Все пароли и токены
- Ссылки для доступа
- Инструкции по управлению

## 📋 Требования

- **Минимум:** 4 CPU, 8GB RAM, SSD 50GB
- **Рекомендуется:** 8+ CPU, 16GB RAM, SSD 100GB
- **ОС:** Ubuntu 20.04+ / Debian 11+ / CentOS 8+

## 🔧 Компоненты

- **Kernel** - Go backend сервер
- **App** - Electron/Web frontend
- **Nginx** - Reverse proxy для удаленного доступа
- **Docker** - Контейнеризация для простого развертывания
- **Prometheus + Grafana** - Система мониторинга
- **Supabase** - Локальная или облачная БД для аудита действий пользователей

## 📚 Документация

- [Полное руководство по развертыванию](DEPLOYMENT_FULL.md) - включает мониторинг и аудит
- [Быстрое развертывание](DEPLOYMENT.md)
- [Дополнительные улучшения](deploy/IMPROVEMENTS.md) - Telegram, облачные бэкапы, автообновление
- [Настройка мониторинга](deploy/monitoring/README.md)
- [Локальный Supabase](deploy/supabase-local/README.md) - локальная БД для аудита
- [Система аудита через Supabase](deploy/audit/README.md)
- [Настройка для команды](siyuan/TEAM_DEPLOYMENT.md)
- [Настройка Nginx](siyuan/nginx/)

## 🚀 Дополнительные функции

- ✅ **Telegram уведомления** - алерты и статус системы
- ✅ **Облачное резервное копирование** - Yandex Object Storage / S3
- ✅ **Автоматическое обновление** - обновления из Git
- ✅ **Проверка здоровья** - автоматическая диагностика
- ✅ **Rate limiting** - защита от DDoS
- ✅ **Admin API** - REST API для управления

## 🔐 Безопасность

- Используйте сложный AccessAuthCode (минимум 16 символов)
- Настройте HTTPS через Let's Encrypt
- Регулярно делайте бэкапы
- Мониторьте логи на подозрительную активность
