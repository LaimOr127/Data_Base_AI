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
	"context"
	"net/http"
	"time"

	"github.com/siyuan-note/logging"
)

// AutoSetupOllama автоматически настраивает Ollama при старте
func AutoSetupOllama() {
	// Проверяем доступность локального Ollama сервера
	if !CheckOllamaServer() {
		logging.LogWarnf("Ollama server not available at http://localhost:11434")
		logging.LogInfof("To use Ollama AI, please install Ollama from https://ollama.ai and start the server")
		return
	}

	logging.LogInfof("Ollama server is available, AI will use nemotron-3-nano:30b-cloud model")
}

// CheckOllamaServer проверяет доступность Ollama сервера
func CheckOllamaServer() bool {
	client := &http.Client{
		Timeout: 2 * time.Second,
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET", "http://localhost:11434/api/tags", nil)
	if err != nil {
		return false
	}

	resp, err := client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()

	return resp.StatusCode == http.StatusOK
}

// EnsureOllamaModel проверяет и загружает модель, если нужно
// Не блокирует загрузку - возвращает nil даже при ошибках
func EnsureOllamaModel(modelName string) error {
	client := &http.Client{
		Timeout: 2 * time.Second, // Короткий таймаут
	}

	// Проверяем, доступна ли модель
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET", "http://localhost:11434/api/tags", nil)
	if err != nil {
		logging.LogWarnf("Failed to create Ollama request: %s (this is OK)", err)
		return nil // Не блокируем загрузку
	}

	resp, err := client.Do(req)
	if err != nil {
		logging.LogWarnf("Ollama server not available: %s (this is OK if Ollama is not running)", err)
		return nil // Не блокируем загрузку
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		logging.LogWarnf("Ollama server returned status %d (this is OK)", resp.StatusCode)
		return nil // Не блокируем загрузку
	}

	// Модель будет автоматически загружена при первом использовании
	// если она не установлена локально
	logging.LogInfof("Ollama model %s will be used (cloud model, loads automatically)", modelName)
	return nil
}
