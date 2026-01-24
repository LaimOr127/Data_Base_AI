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
	"encoding/json"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/siyuan-note/logging"
)

// AutoSetupOllama автоматически настраивает Ollama при старте
func AutoSetupOllama() {
	// Получаем URL из переменной окружения или используем по умолчанию
	ollamaBaseURL := "http://localhost:11434"
	if baseURL := os.Getenv("OLLAMA_API_BASE"); "" != baseURL {
		ollamaBaseURL = baseURL
	}

	// Проверяем доступность Ollama сервера
	if !CheckOllamaServer(ollamaBaseURL) {
		logging.LogWarnf("Ollama server not available at %s", ollamaBaseURL)
		logging.LogInfof("To use Ollama AI, please install Ollama from https://ollama.ai and start the server")
		return
	}

	// Пытаемся найти доступную модель
	availableModel := FindAvailableModel(ollamaBaseURL)
	if availableModel != "" {
		logging.LogInfof("Ollama server is available at %s, found model: %s", ollamaBaseURL, availableModel)
	} else {
		logging.LogInfof("Ollama server is available at %s, will use configured model", ollamaBaseURL)
	}
}

// CheckOllamaServer проверяет доступность Ollama сервера
func CheckOllamaServer(baseURL string) bool {
	if baseURL == "" {
		baseURL = "http://localhost:11434"
	}

	client := &http.Client{
		Timeout: 3 * time.Second,
	}

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	url := baseURL + "/api/tags"
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
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

// FindAvailableModel ищет первую доступную модель в Ollama
func FindAvailableModel(baseURL string) string {
	if baseURL == "" {
		baseURL = "http://localhost:11434"
	}

	client := &http.Client{
		Timeout: 3 * time.Second,
	}

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	url := baseURL + "/api/tags"
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return ""
	}

	resp, err := client.Do(req)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return ""
	}

	var result struct {
		Models []struct {
			Name string `json:"name"`
		} `json:"models"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return ""
	}

	// Ищем первую доступную модель (приоритет чат-моделям, исключаем embedding)
	var chatModels []string
	var cloudChatModels []string
	
	for _, model := range result.Models {
		if model.Name != "" {
			modelLower := strings.ToLower(model.Name)
			// Пропускаем embedding модели
			if strings.Contains(modelLower, "embedding") || strings.Contains(modelLower, "embed") {
				continue
			}
			
			// Собираем облачные чат-модели отдельно
			if strings.Contains(modelLower, "cloud") {
				cloudChatModels = append(cloudChatModels, model.Name)
			} else {
				chatModels = append(chatModels, model.Name)
			}
		}
	}
	
	// Сначала возвращаем облачную чат-модель (приоритет)
	if len(cloudChatModels) > 0 {
		// Предпочитаем deepseek, qwen, ministral, gpt-oss
		for _, model := range cloudChatModels {
			modelLower := strings.ToLower(model)
			if strings.Contains(modelLower, "deepseek") || strings.Contains(modelLower, "qwen") || 
			   strings.Contains(modelLower, "ministral") || strings.Contains(modelLower, "gpt-oss") {
				return model
			}
		}
		// Если нет предпочитаемых, берем первую облачную
		return cloudChatModels[0]
	}
	
	// Если облачных нет, берем первую чат-модель
	if len(chatModels) > 0 {
		return chatModels[0]
	}
	
	// Если чат-моделей нет, возвращаем первую доступную (на случай, если все embedding)
	if len(result.Models) > 0 && result.Models[0].Name != "" {
		return result.Models[0].Name
	}

	return ""
}

// EnsureOllamaModel проверяет и загружает модель, если нужно
// Не блокирует загрузку - возвращает nil даже при ошибках
func EnsureOllamaModel(modelName string) error {
	// Получаем URL из переменной окружения или используем по умолчанию
	baseURL := "http://localhost:11434"
	if envURL := os.Getenv("OLLAMA_API_BASE"); "" != envURL {
		baseURL = envURL
	}

	client := &http.Client{
		Timeout: 3 * time.Second,
	}

	// Проверяем, доступна ли модель
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	url := baseURL + "/api/tags"
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		logging.LogWarnf("Failed to create Ollama request: %s (this is OK)", err)
		return nil // Не блокируем загрузку
	}

	resp, err := client.Do(req)
	if err != nil {
		logging.LogWarnf("Ollama server not available at %s: %s (this is OK if Ollama is not running)", baseURL, err)
		return nil // Не блокируем загрузку
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		logging.LogWarnf("Ollama server returned status %d (this is OK)", resp.StatusCode)
		return nil // Не блокируем загрузку
	}

	// Проверяем, есть ли уже установленная модель
	var result struct {
		Models []struct {
			Name string `json:"name"`
		} `json:"models"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err == nil {
		for _, model := range result.Models {
			if model.Name == modelName {
				logging.LogInfof("Ollama model %s is already available", modelName)
				return nil
			}
		}
	}

	// Модель будет автоматически загружена при первом использовании
	// если она не установлена локально
	logging.LogInfof("Ollama model %s will be used (will load automatically on first use)", modelName)
	return nil
}
