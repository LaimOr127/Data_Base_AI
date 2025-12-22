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

//go:build !mobile

package main

import (
	"github.com/siyuan-note/logging"
	"github.com/siyuan-note/siyuan/kernel/cache"
	"github.com/siyuan-note/siyuan/kernel/job"
	"github.com/siyuan-note/siyuan/kernel/model"
	"github.com/siyuan-note/siyuan/kernel/server"
	"github.com/siyuan-note/siyuan/kernel/sql"
	"github.com/siyuan-note/siyuan/kernel/util"
)

func main() {
	// Глобальная обработка паник для предотвращения падения сервиса
	defer func() {
		if r := recover(); r != nil {
			util.RecoverPanic()
			// Не завершаем процесс, даем возможность восстановиться
		}
	}()

	util.Boot()
	logging.LogInfof("[BOOT] Boot() completed")

	// Инициализация конфигурации (синхронно, так как нужна для дальнейшей работы)
	model.InitConf()
	logging.LogInfof("[BOOT] InitConf() completed")

	// Запускаем сервер в отдельной goroutine
	go server.Serve(false)
	logging.LogInfof("[BOOT] Server started in goroutine")

	// Остальная инициализация (синхронно)
	logging.LogInfof("[BOOT] Starting InitAppearance()...")
	model.InitAppearance()
	logging.LogInfof("[BOOT] InitAppearance() completed")

	logging.LogInfof("[BOOT] Starting InitDatabase()...")
	sql.InitDatabase(false)
	logging.LogInfof("[BOOT] InitDatabase() completed")

	logging.LogInfof("[BOOT] Starting InitHistoryDatabase()...")
	sql.InitHistoryDatabase(false)
	logging.LogInfof("[BOOT] InitHistoryDatabase() completed")

	logging.LogInfof("[BOOT] Starting InitAssetContentDatabase()...")
	sql.InitAssetContentDatabase(false)
	logging.LogInfof("[BOOT] InitAssetContentDatabase() completed")

	sql.SetCaseSensitive(model.Conf.Search.CaseSensitive)
	sql.SetIndexAssetPath(model.Conf.Search.IndexAssetPath)
	logging.LogInfof("[BOOT] SQL settings configured")

	logging.LogInfof("[BOOT] Starting BootSyncData()...")
	model.BootSyncData()
	logging.LogInfof("[BOOT] BootSyncData() completed")

	logging.LogInfof("[BOOT] Starting InitBoxes()...")
	model.InitBoxes()
	logging.LogInfof("[BOOT] InitBoxes() completed")

	logging.LogInfof("[BOOT] Starting LoadFlashcards()...")
	model.LoadFlashcards()
	logging.LogInfof("[BOOT] LoadFlashcards() completed")

	logging.LogInfof("[BOOT] Starting LoadAssetsTexts()...")
	util.LoadAssetsTexts()
	logging.LogInfof("[BOOT] LoadAssetsTexts() completed")

	logging.LogInfof("[BOOT] Setting booted flag...")
	util.SetBooted()
	logging.LogInfof("[BOOT] Booted flag set")
	util.PushClearAllMsg()
	logging.LogInfof("[BOOT] All initialization completed successfully!")

	job.StartCron()

	// Фоновые задачи с обработкой паник
	util.SafeGo(func() {
		util.LoadSysFonts()
	})
	util.SafeGo(func() {
		model.AutoGenerateFileHistory()
	})
	util.SafeGo(func() {
		cache.LoadAssets()
	})
	util.SafeGo(func() {
		util.CheckFileSysStatus()
	})
	util.SafeGo(func() {
		model.WatchAssets()
	})
	util.SafeGo(func() {
		model.WatchEmojis()
	})

	// Обработка сигналов для graceful shutdown (не блокируем main thread)
	go model.HandleSignal()

	// Основной цикл - просто ждем, чтобы процесс не завершился
	select {}
}
