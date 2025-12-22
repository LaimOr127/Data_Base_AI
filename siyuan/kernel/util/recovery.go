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
	"fmt"
	"runtime"
	"runtime/debug"
	"time"

	"github.com/siyuan-note/logging"
)

var (
	panicCount    int64
	lastPanicTime time.Time
)

// SafeGo запускает функцию в goroutine с обработкой паник
func SafeGo(fn func()) {
	go func() {
		defer RecoverPanic()
		fn()
	}()
}

// RecoverPanic обрабатывает паники и логирует их
func RecoverPanic() {
	if r := recover(); r != nil {
		panicCount++
		lastPanicTime = time.Now()

		stack := debug.Stack()
		errMsg := fmt.Sprintf("PANIC RECOVERED: %v\n\tStack trace:\n%s", r, string(stack))
		logging.LogErrorf(errMsg)

		// Отправляем уведомление, но не завершаем процесс
		PushErrMsg("Произошла внутренняя ошибка, но сервис продолжает работать", 5000)
	}
}

// GetPanicCount возвращает количество паник
func GetPanicCount() int64 {
	return panicCount
}

// GetLastPanicTime возвращает время последней паники
func GetLastPanicTime() time.Time {
	return lastPanicTime
}

// RecoverWithRestart обрабатывает панику и перезапускает функцию
func RecoverWithRestart(fn func(), maxRetries int, delay time.Duration) {
	retries := 0
	for {
		func() {
			defer func() {
				if r := recover(); r != nil {
					retries++
					stack := debug.Stack()
					errMsg := fmt.Sprintf("PANIC RECOVERED (attempt %d/%d): %v\n\tStack trace:\n%s",
						retries, maxRetries, r, string(stack))
					logging.LogErrorf(errMsg)

					if retries >= maxRetries {
						logging.LogFatalf(logging.ExitCodeFatal,
							"Function failed after %d retries, giving up", maxRetries)
						return
					}

					logging.LogWarnf("Restarting function after panic, waiting %v...", delay)
					time.Sleep(delay)
				}
			}()
			fn()
		}()

		if retries < maxRetries {
			break
		}
	}
}

// GetGoroutineCount возвращает количество активных goroutines
func GetGoroutineCount() int {
	return runtime.NumGoroutine()
}

// GetMemStats возвращает статистику памяти
func GetMemStats() runtime.MemStats {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	return m
}
