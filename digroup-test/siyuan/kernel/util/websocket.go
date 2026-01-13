// SiYuan - Refactor your thinking
// Copyright (c) 2020-present, b3log.org
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

package util

import (
	"sync"
	"time"

	"github.com/88250/gulu"
	"github.com/olahol/melody"
	"github.com/siyuan-note/eventbus"
)

var (
	// WebSocketServer - основной WebSocket сервер для обмена сообщениями между клиентами и сервером
	WebSocketServer = melody.New()

	// sessions - хранилище активных WebSocket сессий
	// Структура: map[string]map[string]*melody.Session{}
	// Первый ключ - appId (идентификатор приложения), второй - sessionId (идентификатор сессии)
	// Используется для управления подключениями клиентов и рассылки сообщений
	sessions = sync.Map{} // {appId, {sessionId, session}}
)

// BroadcastByTypeAndExcludeApp - рассылает сообщение всем сессиям указанного типа,
// исключая сессии из указанного приложения
// excludeApp - идентификатор приложения, которое нужно исключить из рассылки
// typ - тип сессии (например, "main", "filetree", "protyle")
// cmd - команда для выполнения на клиенте
// code - код результата (0 - успех, отрицательное - ошибка)
// msg - текстовое сообщение
// data - дополнительные данные для передачи
func BroadcastByTypeAndExcludeApp(excludeApp, typ, cmd string, code int, msg string, data interface{}) {
	sessions.Range(func(key, value interface{}) bool {
		appSessions := value.(*sync.Map)
		if key == excludeApp {
			return true
		}

		appSessions.Range(func(key, value interface{}) bool {
			session := value.(*melody.Session)
			if t, ok := session.Get("type"); ok && typ == t {
				event := NewResult()
				event.Cmd = cmd
				event.Code = code
				event.Msg = msg
				event.Data = data
				session.Write(event.Bytes())
			}
			return true
		})
		return true
	})
}

// BroadcastByTypeAndApp - рассылает сообщение всем сессиям указанного типа
// только для конкретного приложения
// typ - тип сессии (например, "main", "filetree", "protyle")
// app - идентификатор приложения, которому нужно отправить сообщение
// cmd - команда для выполнения на клиенте
// code - код результата
// msg - текстовое сообщение
// data - дополнительные данные
func BroadcastByTypeAndApp(typ, app, cmd string, code int, msg string, data interface{}) {
	appSessions, ok := sessions.Load(app)
	if !ok {
		return
	}

	appSessions.(*sync.Map).Range(func(key, value interface{}) bool {
		session := value.(*melody.Session)
		if t, ok := session.Get("type"); ok && typ == t {
			event := NewResult()
			event.Cmd = cmd
			event.Code = code
			event.Msg = msg
			event.Data = data
			session.Write(event.Bytes())
		}
		return true
	})
}

// BroadcastByType - рассылает сообщение всем сессиям указанного типа на всех экземплярах приложения
// typ - тип сессии (например, "main", "filetree", "protyle")
// cmd - команда для выполнения на клиенте
// code - код результата
// msg - текстовое сообщение
// data - дополнительные данные
func BroadcastByType(typ, cmd string, code int, msg string, data interface{}) {
	typeSessions := SessionsByType(typ)
	for _, sess := range typeSessions {
		event := NewResult()
		event.Cmd = cmd
		event.Code = code
		event.Msg = msg
		event.Data = data
		sess.Write(event.Bytes())
	}
}

// SessionsByType - возвращает все активные сессии указанного типа
// typ - тип сессии для поиска
// Возвращает список всех сессий, соответствующих указанному типу
func SessionsByType(typ string) (ret []*melody.Session) {
	ret = []*melody.Session{}

	sessions.Range(func(key, value interface{}) bool {
		appSessions := value.(*sync.Map)
		appSessions.Range(func(key, value interface{}) bool {
			session := value.(*melody.Session)
			if t, ok := session.Get("type"); ok && typ == t {
				ret = append(ret, session)
			}
			return true
		})
		return true
	})
	return
}

// AddPushChan - добавляет новую WebSocket сессию в хранилище для рассылки сообщений
// Извлекает из URL параметры: app (идентификатор приложения), id (идентификатор сессии), type (тип сессии)
// Сохраняет сессию в структуре sessions для последующей рассылки сообщений
func AddPushChan(session *melody.Session) {
	appID := session.Request.URL.Query().Get("app")
	session.Set("app", appID)
	id := session.Request.URL.Query().Get("id")
	session.Set("id", id)
	typ := session.Request.URL.Query().Get("type")
	session.Set("type", typ)

	if appSessions, ok := sessions.Load(appID); !ok {
		appSess := &sync.Map{}
		appSess.Store(id, session)
		sessions.Store(appID, appSess)
	} else {
		(appSessions.(*sync.Map)).Store(id, session)
	}
}

// RemovePushChan - удаляет WebSocket сессию из хранилища
// Используется при отключении клиента для очистки ресурсов
// Если после удаления у приложения не остается активных сессий, удаляет запись приложения
func RemovePushChan(session *melody.Session) {
	app, _ := session.Get("app")
	id, _ := session.Get("id")

	if nil == app || nil == id {
		return
	}

	appSess, _ := sessions.Load(app)
	if nil != appSess {
		appSessions := appSess.(*sync.Map)
		appSessions.Delete(id)
		if 1 > lenOfSyncMap(appSessions) {
			sessions.Delete(app)
		}
	}
}

// lenOfSyncMap - подсчитывает количество элементов в sync.Map
// Используется для проверки, остались ли активные сессии у приложения
func lenOfSyncMap(m *sync.Map) (ret int) {
	m.Range(func(key, value interface{}) bool {
		ret++
		return true
	})
	return
}

// ClosePushChan - закрывает WebSocket сессию по идентификатору
// Находит сессию с указанным id и принудительно закрывает соединение
// Используется для принудительного отключения клиента
func ClosePushChan(id string) {
	sessions.Range(func(key, value interface{}) bool {
		appSessions := value.(*sync.Map)
		appSessions.Range(func(key, value interface{}) bool {
			session := value.(*melody.Session)
			if sid, _ := session.Get("id"); sid == id {
				session.CloseWithMsg([]byte("  close websocket"))
				RemovePushChan(session)
			}
			return true
		})
		return true
	})
}

// ReloadUIResetScroll - отправляет команду на перезагрузку UI с сбросом позиции прокрутки
// Используется когда нужно обновить интерфейс и вернуть прокрутку в начало
func ReloadUIResetScroll() {
	BroadcastByType("main", "reloadui", 0, "", map[string]interface{}{"resetScroll": true})
}

// ReloadUI - отправляет команду на перезагрузку UI без сброса прокрутки
// Используется для обновления интерфейса при сохранении текущей позиции
func ReloadUI() {
	BroadcastByType("main", "reloadui", 0, "", nil)
}

// PushTxErr - отправляет сообщение об ошибке транзакции всем клиентам
// msg - текст ошибки
// code - код ошибки
// data - дополнительные данные об ошибке
func PushTxErr(msg string, code int, data interface{}) {
	BroadcastByType("main", "txerr", code, msg, data)
}

// PushUpdateMsg - обновляет существующее сообщение по его идентификатору
// msgId - идентификатор сообщения для обновления
// msg - новый текст сообщения
// timeout - время отображения в миллисекундах
func PushUpdateMsg(msgId string, msg string, timeout int) {
	BroadcastByType("main", "msg", 0, msg, map[string]interface{}{"id": msgId, "closeTimeout": timeout})
	return
}

// PushMsg - отправляет новое сообщение всем клиентам
// msg - текст сообщения
// timeout - время отображения в миллисекундах
// Возвращает уникальный идентификатор сообщения для последующего обновления или удаления
func PushMsg(msg string, timeout int) (msgId string) {
	msgId = gulu.Rand.String(7)
	BroadcastByType("main", "msg", 0, msg, map[string]interface{}{"id": msgId, "closeTimeout": timeout})
	return
}

// PushMsgWithApp - отправляет сообщение конкретному приложению или всем, если app пустой
// app - идентификатор приложения (если пустой - рассылка всем)
// msg - текст сообщения
// timeout - время отображения в миллисекундах
// Возвращает идентификатор сообщения
func PushMsgWithApp(app, msg string, timeout int) (msgId string) {
	msgId = gulu.Rand.String(7)
	if "" == app {
		BroadcastByType("main", "msg", 0, msg, map[string]interface{}{"id": msgId, "closeTimeout": timeout})
		return
	}
	BroadcastByTypeAndApp("main", app, "msg", 0, msg, map[string]interface{}{"id": msgId, "closeTimeout": timeout})
	return
}

// PushErrMsg - отправляет сообщение об ошибке всем клиентам
// msg - текст ошибки
// timeout - время отображения в миллисекундах
// Возвращает идентификатор сообщения
func PushErrMsg(msg string, timeout int) (msgId string) {
	msgId = gulu.Rand.String(7)
	BroadcastByType("main", "msg", -1, msg, map[string]interface{}{"id": msgId, "closeTimeout": timeout})
	return
}

// PushStatusBar - отправляет сообщение в строку состояния с текущей датой и временем
// msg - текст сообщения (к нему автоматически добавляется дата и время)
func PushStatusBar(msg string) {
	msg += " (" + time.Now().Format("2006-01-02 15:04:05") + ")"
	BroadcastByType("main", "statusbar", 0, msg, nil)
}

// PushBackgroundTask - отправляет информацию о фоновой задаче
// data - данные о задаче (статус, прогресс и т.д.)
func PushBackgroundTask(data map[string]interface{}) {
	BroadcastByType("main", "backgroundtask", 0, "", data)
}

// PushReloadFiletree - отправляет команду на перезагрузку дерева файлов
// Используется когда нужно обновить список документов в боковой панели
func PushReloadFiletree() {
	BroadcastByType("filetree", "reloadFiletree", 0, "", nil)
}

// PushReloadTag - отправляет команду на перезагрузку тегов
// Используется когда нужно обновить список тегов в интерфейсе
func PushReloadTag() {
	BroadcastByType("main", "reloadTag", 0, "", nil)
}

// BlockStatResult - структура для хранения статистики по блоку
// Используется для передачи информации о количестве элементов в блоке
type BlockStatResult struct {
	RuneCount  int `json:"runeCount"`  // Количество символов (рун)
	WordCount  int `json:"wordCount"`  // Количество слов
	LinkCount  int `json:"linkCount"`  // Количество ссылок
	ImageCount int `json:"imageCount"` // Количество изображений
	RefCount   int `json:"refCount"`   // Количество ссылок на блок
	BlockCount int `json:"blockCount"` // Количество подблоков
}

// ContextPushMsg - отправляет сообщение в зависимости от контекста
// Проверяет настройки контекста и отправляет сообщение в соответствующий канал:
// - CtxPushMsgToNone - не отправлять
// - CtxPushMsgToProgress - отправить в прогресс-бар
// - CtxPushMsgToStatusBar - отправить в строку состояния
// - CtxPushMsgToStatusBarAndProgress - отправить в оба места
func ContextPushMsg(context map[string]interface{}, msg string) {
	switch context[eventbus.CtxPushMsg].(int) {
	case eventbus.CtxPushMsgToNone:
		break
	case eventbus.CtxPushMsgToProgress:
		PushEndlessProgress(msg)
	case eventbus.CtxPushMsgToStatusBar:
		PushStatusBar(msg)
	case eventbus.CtxPushMsgToStatusBarAndProgress:
		PushStatusBar(msg)
		PushEndlessProgress(msg)
	}
}

const (
	PushProgressCodeProgressed = 0 // Код прогресса с конкретным значением (есть прогресс)
	PushProgressCodeEndless    = 1 // Код бесконечного прогресса (без конкретного значения)
	PushProgressCodeEnd        = 2 // Код завершения прогресса (закрыть прогресс-бар)
)

// PushClearAllMsg - очищает все сообщения и закрывает прогресс-бар
// Используется для полной очистки UI от уведомлений
func PushClearAllMsg() {
	ClearPushProgress(100)
	PushClearMsg("")
}

// ClearPushProgress - закрывает прогресс-бар
// total - общее количество для отображения (обычно 100)
func ClearPushProgress(total int) {
	PushProgress(PushProgressCodeEnd, total, total, "")
}

// PushEndlessProgress - показывает бесконечный прогресс-бар с сообщением
// Используется когда неизвестно время выполнения операции
// msg - текст сообщения для отображения
func PushEndlessProgress(msg string) {
	PushProgress(PushProgressCodeEndless, 1, 1, msg)
}

// PushProgress - отправляет информацию о прогрессе выполнения операции
// code - код типа прогресса (Progressed, Endless, End)
// current - текущее значение прогресса
// total - максимальное значение прогресса
// msg - текстовое сообщение о текущей операции
func PushProgress(code, current, total int, msg string) {
	BroadcastByType("main", "progress", code, msg, map[string]interface{}{
		"current": current,
		"total":   total,
	})
}

// PushClearMsg - очищает указанное сообщение по его идентификатору
// msgId - идентификатор сообщения для удаления (пустая строка - удалить все)
func PushClearMsg(msgId string) {
	BroadcastByType("main", "cmsg", 0, "", map[string]interface{}{"id": msgId})
}

// PushClearProgress - закрывает прогресс-бар (убирает маску прогресса)
func PushClearProgress() {
	BroadcastByType("main", "cprogress", 0, "", nil)
}

// PushUpdateIDs - отправляет обновление идентификаторов блоков
// Используется когда ID блоков изменились и нужно обновить ссылки
// ids - карта старых ID -> новых ID
func PushUpdateIDs(ids map[string]string) {
	BroadcastByType("main", "updateids", 0, "", ids)
}

// PushReloadDoc - отправляет команду на перезагрузку документа
// rootID - идентификатор корневого блока документа для перезагрузки
func PushReloadDoc(rootID string) {
	BroadcastByType("main", "reloaddoc", 0, "", rootID)
}

// PushSaveDoc - отправляет уведомление о сохранении документа
// rootID - идентификатор корневого блока документа
// typ - тип сохранения
// sources - источники данных для сохранения
func PushSaveDoc(rootID, typ string, sources interface{}) {
	evt := NewCmdResult("savedoc", 0, PushModeBroadcast)
	evt.Data = map[string]interface{}{
		"rootID":  rootID,
		"type":    typ,
		"sources": sources,
	}
	PushEvent(evt)
}

// PushReloadDocInfo - отправляет обновление информации о документе в дереве файлов
// docInfo - информация о документе (название, путь, размер и т.д.)
func PushReloadDocInfo(docInfo map[string]any) {
	BroadcastByType("filetree", "reloadDocInfo", 0, "", docInfo)
}

// PushReloadProtyle - отправляет команду на перезагрузку редактора Protyle
// rootID - идентификатор корневого блока для перезагрузки
func PushReloadProtyle(rootID string) {
	BroadcastByType("protyle", "reload", 0, "", rootID)
}

// PushSetRefDynamicText - обновляет динамический текст ссылки на блок
// rootID - идентификатор корневого блока документа
// blockID - идентификатор блока со ссылкой
// defBlockID - идентификатор блока, на который ссылаются
// refText - новый текст ссылки
func PushSetRefDynamicText(rootID, blockID, defBlockID, refText string) {
	BroadcastByType("main", "setRefDynamicText", 0, "", map[string]interface{}{"rootID": rootID, "blockID": blockID, "defBlockID": defBlockID, "refText": refText})
}

// PushSetDefRefCount - обновляет счетчик ссылок на определение блока
// rootID - идентификатор корневого блока
// blockID - идентификатор блока-определения
// defIDs - список идентификаторов блоков, которые ссылаются на определение
// refCount - количество ссылок на блок
// rootRefCount - количество ссылок на корневой блок
func PushSetDefRefCount(rootID, blockID string, defIDs []string, refCount, rootRefCount int) {
	BroadcastByType("main", "setDefRefCount", 0, "", map[string]interface{}{"rootID": rootID, "blockID": blockID, "refCount": refCount, "rootRefCount": rootRefCount, "defIDs": defIDs})
}

// PushLocalShorthandCount - отправляет количество локальных сокращений
// count - количество найденных сокращений
func PushLocalShorthandCount(count int) {
	BroadcastByType("main", "setLocalShorthandCount", 0, "", map[string]interface{}{"count": count})
}

// PushProtyleLoading - показывает индикатор загрузки в редакторе Protyle
// rootID - идентификатор корневого блока
// msg - сообщение о процессе загрузки
func PushProtyleLoading(rootID, msg string) {
	BroadcastByType("protyle", "addLoading", 0, msg, rootID)
}

// PushReloadEmojiConf - отправляет команду на перезагрузку конфигурации эмодзи
// Используется когда изменились настройки эмодзи
func PushReloadEmojiConf() {
	BroadcastByType("main", "reloadEmojiConf", 0, "", nil)
}

// PushDownloadProgress - отправляет информацию о прогрессе загрузки файла
// id - идентификатор загрузки
// percent - процент завершения (0.0 - 1.0)
func PushDownloadProgress(id string, percent float32) {
	evt := NewCmdResult("downloadProgress", 0, PushModeBroadcast)
	evt.Data = map[string]interface{}{
		"id":      id,
		"percent": percent,
	}
	PushEvent(evt)
}

// PushEvent - отправляет событие в зависимости от режима рассылки
// Поддерживает различные режимы:
// - PushModeBroadcast - всем клиентам
// - PushModeSingleSelf - только отправителю
// - PushModeBroadcastExcludeSelf - всем кроме отправителя
// - PushModeBroadcastExcludeSelfApp - всем приложениям кроме текущего
// - PushModeBroadcastApp - только указанному приложению
// - PushModeBroadcastMainExcludeSelfApp - главным окнам всех приложений кроме текущего
func PushEvent(event *Result) {
	msg := event.Bytes()
	mode := event.PushMode
	switch mode {
	case PushModeBroadcast:
		Broadcast(msg)
	case PushModeSingleSelf:
		single(msg, event.AppId, event.SessionId)
	case PushModeBroadcastExcludeSelf:
		broadcastOthers(msg, event.SessionId)
	case PushModeBroadcastExcludeSelfApp:
		broadcastOtherApps(msg, event.AppId)
	case PushModeBroadcastApp:
		broadcastApp(msg, event.AppId)
	case PushModeBroadcastMainExcludeSelfApp:
		broadcastOtherAppMains(msg, event.AppId)
	}
}

// single - отправляет сообщение только одной конкретной сессии
// msg - данные для отправки
// appId - идентификатор приложения
// sid - идентификатор сессии
func single(msg []byte, appId, sid string) {
	sessions.Range(func(key, value interface{}) bool {
		appSessions := value.(*sync.Map)
		if key != appId {
			return true
		}

		appSessions.Range(func(key, value interface{}) bool {
			session := value.(*melody.Session)
			if id, _ := session.Get("id"); id == sid {
				session.Write(msg)
			}
			return true
		})
		return true
	})
}

// Broadcast - рассылает сообщение всем активным WebSocket сессиям
// msg - данные для отправки всем подключенным клиентам
func Broadcast(msg []byte) {
	sessions.Range(func(key, value interface{}) bool {
		appSessions := value.(*sync.Map)
		appSessions.Range(func(key, value interface{}) bool {
			session := value.(*melody.Session)
			session.Write(msg)
			return true
		})
		return true
	})
}

// broadcastOtherApps - рассылает сообщение всем приложениям, кроме указанного
// msg - данные для отправки
// excludeApp - идентификатор приложения, которое нужно исключить из рассылки
func broadcastOtherApps(msg []byte, excludeApp string) {
	sessions.Range(func(key, value interface{}) bool {
		appSessions := value.(*sync.Map)
		appSessions.Range(func(key, value interface{}) bool {
			session := value.(*melody.Session)
			if app, _ := session.Get("app"); app == excludeApp {
				return true
			}
			session.Write(msg)
			return true
		})
		return true
	})
}

// broadcastOtherAppMains - рассылает сообщение главным окнам всех приложений, кроме указанного
// msg - данные для отправки
// excludeApp - идентификатор приложения, которое нужно исключить
// Отправляет только сессиям типа "main" (главные окна)
func broadcastOtherAppMains(msg []byte, excludeApp string) {
	sessions.Range(func(key, value interface{}) bool {
		appSessions := value.(*sync.Map)
		appSessions.Range(func(key, value interface{}) bool {
			session := value.(*melody.Session)
			if app, _ := session.Get("app"); app == excludeApp {
				return true
			}

			if t, ok := session.Get("type"); ok && "main" != t {
				return true
			}

			session.Write(msg)
			return true
		})
		return true
	})
}

// broadcastApp - рассылает сообщение всем сессиям указанного приложения
// msg - данные для отправки
// app - идентификатор приложения, которому нужно отправить сообщение
func broadcastApp(msg []byte, app string) {
	sessions.Range(func(key, value interface{}) bool {
		appSessions := value.(*sync.Map)
		appSessions.Range(func(key, value interface{}) bool {
			session := value.(*melody.Session)
			if sessionApp, _ := session.Get("app"); sessionApp != app {
				return true
			}
			session.Write(msg)
			return true
		})
		return true
	})
}

// broadcastOthers - рассылает сообщение всем сессиям, кроме указанной
// msg - данные для отправки
// excludeSID - идентификатор сессии, которую нужно исключить из рассылки
// Используется когда нужно отправить сообщение всем, кроме отправителя
func broadcastOthers(msg []byte, excludeSID string) {
	sessions.Range(func(key, value interface{}) bool {
		appSessions := value.(*sync.Map)
		appSessions.Range(func(key, value interface{}) bool {
			session := value.(*melody.Session)
			if id, _ := session.Get("id"); id == excludeSID {
				return true
			}
			session.Write(msg)
			return true
		})
		return true
	})
}

// CountSessions - подсчитывает количество активных приложений (не сессий)
// Возвращает количество уникальных appId в хранилище сессий
// Для подсчета всех сессий нужно использовать другую функцию
func CountSessions() (ret int) {
	sessions.Range(func(key, value interface{}) bool {
		ret++
		return true
	})
	return
}
