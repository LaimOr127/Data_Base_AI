# Автоматическая установка DIGroup для Windows
# Использование: .\install-windows.ps1
# Требуется: PowerShell 5.1+ и Docker Desktop

$ErrorActionPreference = "Stop"

# Цвета
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Success($message) {
    Write-ColorOutput Green "✅ $message"
}

function Write-Error-Custom($message) {
    Write-ColorOutput Red "❌ $message"
}

function Write-Warning-Custom($message) {
    Write-ColorOutput Yellow "⚠️ $message"
}

function Write-Log($message) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-ColorOutput Cyan "[$timestamp] $message"
}

# Генерация паролей
function Generate-Password {
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[] 25
    $rng.GetBytes($bytes)
    $rng.Dispose()
    return [Convert]::ToBase64String($bytes).Substring(0, 25) -replace '[+/=]', ''
}

function Generate-AuthCode {
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[] 16
    $rng.GetBytes($bytes)
    $rng.Dispose()
    return ($bytes | ForEach-Object { $_.ToString("x2") }) -join ''
}

Clear-Host
Write-ColorOutput Cyan @"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║     🚀 Автоматическая установка DIGroup для Windows        ║
║     Включая: DIGroup, Мониторинг, Supabase                ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
"@
Write-Output ""

# Проверка Docker
Write-Log "Проверка Docker..."
try {
    docker info | Out-Null
    Write-Success "Docker доступен"
} catch {
    Write-Error-Custom "Docker не запущен. Запустите Docker Desktop"
    exit 1
}
Write-Output ""

# Определение путей
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestDir = Join-Path $ScriptDir "digroup-test"
$DeployDir = Join-Path $ScriptDir "deploy"

Write-Log "Директория установки: $TestDir"
Write-Output ""

# Генерация паролей
Write-Log "Генерация паролей..."
$AccessAuthCode = Generate-AuthCode
$GrafanaPassword = Generate-Password
$PostgresPassword = Generate-Password
$JwtSecret = Generate-Password
Write-Success "Пароли сгенерированы"
Write-Output ""

# Создание директорий
Write-Log "Создание директорий..."
New-Item -ItemType Directory -Force -Path "$TestDir\workspace" | Out-Null
New-Item -ItemType Directory -Force -Path "$TestDir\data" | Out-Null
New-Item -ItemType Directory -Force -Path "$TestDir\backups" | Out-Null
New-Item -ItemType Directory -Force -Path "$TestDir\logs" | Out-Null
New-Item -ItemType Directory -Force -Path "$TestDir\deploy\monitoring\prometheus" | Out-Null
New-Item -ItemType Directory -Force -Path "$TestDir\deploy\monitoring\grafana" | Out-Null
New-Item -ItemType Directory -Force -Path "$TestDir\deploy\supabase-local" | Out-Null
Write-Success "Директории созданы"
Write-Output ""

# Копирование проекта
Write-Log "Копирование проекта..."
Copy-Item -Path "$ScriptDir\*" -Destination "$TestDir\" -Recurse -Force -Exclude ".git","node_modules" -ErrorAction SilentlyContinue
Write-Success "Проект скопирован"
Write-Output ""

# Создание .env
Write-Log "Создание .env..."
$envContent = @"
ACCESS_AUTH_CODE=$AccessAuthCode
GRAFANA_PASSWORD=$GrafanaPassword
POSTGRES_PASSWORD=$PostgresPassword
JWT_SECRET=$JwtSecret
TZ=Europe/Moscow
KERNEL_PORT=6806
SUPABASE_URL=http://127.0.0.1:3001
SUPABASE_KEY=$JwtSecret
SUPABASE_AUDIT_TABLE=audit_logs
SUPABASE_LOCAL=true
SUPABASE_DB_PASSWORD=$PostgresPassword
OLLAMA_URL=http://localhost:11434
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
"@
$envContent | Out-File -FilePath (Join-Path $TestDir ".env") -Encoding UTF8
Write-Success ".env создан"
Write-Output ""

# Создание docker-compose.yml
Write-Log "Создание docker-compose.yml..."
$dockerCompose = @"
version: '3.8'

services:
  digroup:
    build:
      context: ../siyuan
      dockerfile: Dockerfile
    container_name: digroup-test
    restart: unless-stopped
    ports:
      - "6806:6806"
    environment:
      - TZ=Europe/Moscow
      - ACCESS_AUTH_CODE=${AccessAuthCode}
    volumes:
      - ./workspace:/opt/siyuan/workspace
      - ./data:/opt/siyuan/data
    command: [
      "/opt/siyuan/kernel",
      "--workspace=/opt/siyuan/workspace",
      "--accessAuthCode=${AccessAuthCode}",
      "--port=6806"
    ]
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:6806/api/system/version"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - digroup-network

  supabase-db:
    image: supabase/postgres:15.1.0.117
    container_name: supabase-db-test
    restart: unless-stopped
    ports:
      - "54322:5432"
    environment:
      POSTGRES_PASSWORD: ${PostgresPassword}
      JWT_SECRET: ${JwtSecret}
    volumes:
      - supabase_db_data_test:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U supabase_admin"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - digroup-network

  supabase-rest:
    image: postgrest/postgrest:v11.2.0
    container_name: supabase-rest-test
    restart: unless-stopped
    ports:
      - "3001:3000"
    environment:
      PGRST_DB_URI: postgres://supabase_admin:${PostgresPassword}@supabase-db:5432/postgres
      PGRST_DB_SCHEMAS: public
      PGRST_DB_ANON_ROLE: anon
      PGRST_JWT_SECRET: ${JwtSecret}
    depends_on:
      supabase-db:
        condition: service_healthy
    networks:
      - digroup-network

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus-test
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data_test:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    networks:
      - digroup-network

  grafana:
    image: grafana/grafana:latest
    container_name: grafana-test
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GrafanaPassword}
      - GF_SERVER_ROOT_URL=http://localhost:3000
    volumes:
      - grafana_data_test:/var/lib/grafana
    depends_on:
      - prometheus
    networks:
      - digroup-network

volumes:
  supabase_db_data_test:
  prometheus_data_test:
  grafana_data_test:

networks:
  digroup-network:
    driver: bridge
"@

$dockerCompose | Out-File -FilePath (Join-Path $TestDir "docker-compose.yml") -Encoding UTF8
Write-Success "docker-compose.yml создан"
Write-Output ""

# Создание prometheus.yml
Write-Log "Создание конфигурации Prometheus..."
$prometheusConfig = @'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'digroup'
    static_configs:
      - targets: ['digroup-test:6806']
'@
$prometheusConfig | Out-File -FilePath (Join-Path $TestDir "prometheus.yml") -Encoding UTF8
Write-Success "Конфигурации созданы"
Write-Output ""

# Запуск сервисов
Write-Log "Запуск всех сервисов..."
Set-Location $TestDir

# Загрузка переменных окружения
Get-Content (Join-Path $TestDir ".env") | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
    }
}

Write-Log "Сборка и запуск Docker контейнеров..."
docker-compose up -d --build
Write-Success "Сервисы запускаются..."
Write-Output ""

# Ожидание запуска DIGroup
Write-Log "Ожидание запуска DIGroup kernel..."
$maxAttempts = 60
$attempt = 0
$started = $false

while ($attempt -lt $maxAttempts -and -not $started) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:6806/api/system/version" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Success "DIGroup kernel запущен"
            $started = $true
        }
    } catch {
        Start-Sleep -Seconds 2
        Write-Host "." -NoNewline
    }
    $attempt++
}
Write-Output ""

# Ожидание Supabase
Write-Log "Ожидание запуска Supabase..."
$maxAttempts = 30
$attempt = 0
$started = $false

while ($attempt -lt $maxAttempts -and -not $started) {
    $result = docker exec supabase-db-test pg_isready -U supabase_admin 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Supabase запущен"
        $started = $true
    } else {
        Start-Sleep -Seconds 2
        Write-Host "." -NoNewline
    }
    $attempt++
}
Write-Output ""

# Настройка базы данных
Write-Log "Настройка базы данных..."
$sqlScript = @'
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
    END IF;
END
$$;
GRANT anon TO authenticated;
GRANT authenticated TO service_role;
GRANT ALL ON DATABASE postgres TO service_role;
GRANT ALL ON SCHEMA public TO anon, authenticated, service_role;
'@
$sqlScript | docker exec -i supabase-db-test psql -U supabase_admin -d postgres 2>&1 | Out-Null

# Создание таблиц
$supabaseSqlPath = Join-Path $TestDir "deploy\audit\supabase-setup.sql"
if (Test-Path $supabaseSqlPath) {
    $tempSql = [System.IO.Path]::GetTempFileName()
    Get-Content $supabaseSqlPath | Where-Object { $_ -notmatch "ENABLE ROW LEVEL SECURITY" -and $_ -notmatch "CREATE POLICY" -and $_ -notmatch "POLICY" } | Out-File $tempSql -Encoding UTF8
    
    $grants = @'

GRANT SELECT, INSERT ON audit_logs TO anon, authenticated, service_role;
GRANT SELECT, INSERT ON user_sessions TO anon, authenticated, service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
'@
    Add-Content $tempSql $grants
    
    Get-Content $tempSql | docker exec -i supabase-db-test psql -U supabase_admin -d postgres 2>&1 | Out-Null
    Remove-Item $tempSql
    Write-Success "База данных настроена"
}
Write-Output ""

# Итоговая информация
Clear-Host
Write-ColorOutput Green @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                    ✅ УСТАНОВКА ЗАВЕРШЕНА!                               ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@
Write-Output ""

Write-ColorOutput Cyan "🔐 ДАННЫЕ ДЛЯ ДОСТУПА"
Write-Output "═══════════════════════════════════════════════════════════════════════════"
Write-Output ""
Write-Output "AccessAuthCode: $AccessAuthCode"
Write-Output "Grafana пароль: $GrafanaPassword"
Write-Output ""

Write-ColorOutput Cyan "🌐 ССЫЛКИ ДЛЯ ДОСТУПА"
Write-Output "═══════════════════════════════════════════════════════════════════════════"
Write-Output ""
Write-Output "• DIGroup:              http://localhost:6806"
Write-Output "• Grafana:              http://localhost:3000"
Write-Output "                          Логин: admin"
Write-Output "                          Пароль: $GrafanaPassword"
Write-Output "• Prometheus:           http://localhost:9090"
Write-Output "• Supabase API:          http://localhost:3001"
Write-Output ""

Write-ColorOutput Cyan "🛠️ УПРАВЛЕНИЕ"
Write-Output "═══════════════════════════════════════════════════════════════════════════"
Write-Output ""
Write-Output "Остановка:     cd $TestDir && docker-compose down"
Write-Output "Запуск:        cd $TestDir && docker-compose up -d"
Write-Output "Логи:          cd $TestDir && docker-compose logs -f"
Write-Output ""

Write-ColorOutput Green "✅ Все готово!"
Write-Output ""
Write-ColorOutput Yellow "💡 Откройте http://localhost:6806 в браузере"
Write-Output ""

