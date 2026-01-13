# Финальные изменения: Название DIGroup везде

## ✅ Все места с названием исправлены

### Electron (Главное меню и заголовок окна)

1. **`app/electron/main.js`**:
   - Добавлен `app.setName("DIGroup")` - устанавливает название для macOS
   - `productName = "DIGroup"` - для меню macOS
   - User-Agent изменен на "DIGroup"
   - Сообщения об ошибках обновлены

2. **`app/electron/error.html`**:
   - Заголовок: "Error - DIGroup"
   - В иконке: "DIGroup v..."

3. **Конфигурационные файлы electron-builder**:
   - `electron-builder.yml` - productName: "DIGroup"
   - `electron-builder-darwin.yml` - productName: "DIGroup"
   - `electron-builder-darwin-arm64.yml` - productName: "DIGroup"
   - `electron-builder-arm64.yml` - productName: "DIGroup"
   - `electron-builder-linux.yml` - productName: "DIGroup", Name: "DIGroup"
   - `electron-builder-linux-arm64.yml` - productName: "DIGroup", Name: "DIGroup"

### Frontend (Локализация)

- `app/appearance/langs/ru_RU.json` - все упоминания "SiYuan" заменены на "DIGroup"
- `app/src/dialog/processSystem.ts` - использует `window.siyuan.languages.siyuanNote` (уже "DIGroup")

---

## 🔄 Что нужно сделать

### 1. Пересобрать frontend (ОБЯЗАТЕЛЬНО!)

```bash
cd /Users/alexey_pripadchev/Documents/Work/data_base/siyuan/app
pnpm run dev
```

### 2. Перезапустить приложение

После пересборки frontend и перезапуска Electron приложения:
- Название в заголовке окна macOS будет "DIGroup"
- Название в главном меню будет "DIGroup"
- Все элементы интерфейса будут на русском языке

---

## ⚠️ Важно

В режиме разработки название окна устанавливается через `app.setName("DIGroup")` в `main.js`. 

Если название все еще не меняется:
1. Полностью закройте приложение
2. Пересоберите frontend: `pnpm run dev`
3. Перезапустите приложение

Название должно отображаться как "DIGroup" в заголовке окна macOS.

