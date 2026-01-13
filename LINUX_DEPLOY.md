# Развертывание DIGroup на Linux сервере

## Требования

- Ubuntu 20.04+, Debian 11+, CentOS 8+ или аналог
- 2 GB RAM (рекомендуется 4 GB)
- 10 GB свободного места
- 2 CPU ядра

## Быстрая установка

```bash
# Скопируйте проект на сервер
scp -r . user@server:/opt/digroup

# На сервере
cd /opt/digroup
chmod +x *.sh

# Установите Docker и зависимости
./install.sh

# Запустите приложение
./start.sh
```

Откройте: `http://ваш-сервер-ip:6806`

## Ручная установка

### 1. Установка Docker

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker
```

### 2. Установка Docker Compose

```bash
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 3. Подготовка

```bash
cd /opt/digroup
mkdir -p workspace data backups logs
```

### 4. Создание конфигурации

```bash
cat > .env << 'EOF'
ACCESS_AUTH_CODE=ваш_секретный_код
TZ=Europe/Moscow
HOST_IP=0.0.0.0
PORT=6806
PUID=1000
PGID=1000
EOF
```

Измените `ACCESS_AUTH_CODE` на свой уникальный код!

### 5. Запуск

```bash
docker-compose up -d
```

### 6. Проверка

```bash
docker-compose ps
docker-compose logs -f
curl http://localhost:6806/api/system/version
```

## Настройка автозапуска

```bash
sudo ./setup-systemd.sh
```

Управление через systemd:

```bash
sudo systemctl start digroup
sudo systemctl stop digroup
sudo systemctl restart digroup
sudo systemctl status digroup
```

## Настройка файрволла

### Ubuntu/Debian (UFW)

```bash
sudo ufw allow 6806/tcp
sudo ufw reload
```

### CentOS/RHEL (firewalld)

```bash
sudo firewall-cmd --permanent --add-port=6806/tcp
sudo firewall-cmd --reload
```

## Настройка Nginx (опционально)

Создайте `/etc/nginx/sites-available/digroup`:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:6806;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

Активируйте:

```bash
sudo ln -s /etc/nginx/sites-available/digroup /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### SSL (Let's Encrypt)

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

## Резервное копирование

```bash
# Создание backup
docker-compose down
tar -czf backup-$(date +%Y%m%d).tar.gz workspace data .env
docker-compose up -d

# Восстановление
docker-compose down
tar -xzf backup-YYYYMMDD.tar.gz
docker-compose up -d
```

## Обновление

```bash
docker-compose down
docker-compose pull
docker-compose up -d --build
```

## Решение проблем

### Контейнер не запускается

```bash
docker-compose logs
sudo systemctl status docker
sudo systemctl restart docker
```

### Порт занят

```bash
sudo netstat -tulpn | grep 6806
# Или измените порт в .env
```

### Нет доступа извне

```bash
# Проверьте файрволл
sudo ufw status

# Проверьте docker-compose.yml - должно быть:
# ports: - "0.0.0.0:6806:6806"
```

## Мониторинг

```bash
# Использование ресурсов
docker stats digroup

# Логи в реальном времени
docker-compose logs -f --tail=100

# Проверка API
curl http://localhost:6806/api/system/version
```

## Безопасность

1. Измените `ACCESS_AUTH_CODE` на уникальный
2. Используйте Nginx как reverse proxy
3. Настройте SSL/TLS
4. Ограничьте доступ через файрволл
5. Регулярно делайте backup

## Дополнительно

- Конфигурация: `.env`
- Данные: `./workspace`
- Логи: `./logs` и `docker-compose logs`
- Документация: https://b3log.org/siyuan/
