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
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/siyuan-note/logging"
)

type OllamaRequest struct {
	Model    string    `json:"model"`
	Messages []Message `json:"messages"`
	Stream   bool      `json:"stream"`
	Options  Options   `json:"options,omitempty"`
}

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type Options struct {
	Temperature float64 `json:"temperature,omitempty"`
	MaxTokens   int     `json:"num_predict,omitempty"`
}

type OllamaResponse struct {
	Message      Message `json:"message"`
	Done         bool    `json:"done"`
	Error        string  `json:"error,omitempty"`
	TotalTokens  int     `json:"eval_count,omitempty"`
	PromptTokens int     `json:"prompt_eval_count,omitempty"`
}

func OllamaChat(msg string, contextMsgs []string, apiModel string, maxTokens int, temperature float64, timeout int, apiProxy, apiBaseURL, apiKey string) (ret string, stop bool, err error) {
	var messages []Message

	// Добавляем контекстные сообщения
	// Контекстные сообщения приходят в формате: [user_msg1, assistant_response1, user_msg2, assistant_response2, ...]
	// Поэтому четные индексы - user, нечетные - assistant
	for i, ctxMsg := range contextMsgs {
		if "" == ctxMsg {
			continue
		}
		role := "user"
		if i%2 == 1 {
			role = "assistant"
		}
		messages = append(messages, Message{
			Role:    role,
			Content: ctxMsg,
		})
	}

	// Добавляем текущее сообщение
	if "" != msg {
		messages = append(messages, Message{
			Role:    "user",
			Content: msg,
		})
	}

	if 1 > len(messages) {
		stop = true
		return
	}

	// Формируем запрос
	reqBody := OllamaRequest{
		Model:    apiModel,
		Messages: messages,
		Stream:   false,
		Options: Options{
			Temperature: temperature,
		},
	}

	if maxTokens > 0 {
		reqBody.Options.MaxTokens = maxTokens
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		logging.LogErrorf("marshal Ollama request failed: %s", err)
		stop = true
		return
	}

	// Формируем URL
	if "" == apiBaseURL {
		apiBaseURL = "http://localhost:11434"
	}

	// Проверяем, используется ли Open Router (OpenAI-совместимый API)
	isOpenRouter := strings.Contains(apiBaseURL, "openrouter.ai")

	var apiURL string
	if isOpenRouter {
		// Open Router использует OpenAI-совместимый формат
		apiURL = fmt.Sprintf("%s/chat/completions", strings.TrimSuffix(apiBaseURL, "/"))
	} else {
		// Стандартный Ollama API
		apiURL = fmt.Sprintf("%s/api/chat", strings.TrimSuffix(apiBaseURL, "/"))
	}

	// Создаем HTTP клиент
	client := &http.Client{
		Timeout: time.Duration(timeout) * time.Second,
	}

	// Настраиваем прокси, если указан
	if "" != apiProxy {
		proxyURL, parseErr := url.Parse(apiProxy)
		if parseErr != nil {
			logging.LogErrorf("Ollama API proxy failed: %v", parseErr)
		} else {
			client.Transport = &http.Transport{
				Proxy: http.ProxyURL(proxyURL),
			}
		}
	}

	// #region agent log
	logFile, _ := os.OpenFile("/Users/alexey_pripadchev/Documents/Work/data_base/.cursor/debug.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if logFile != nil {
		logData, _ := json.Marshal(map[string]interface{}{
			"sessionId": "debug-session", "runId": "run1", "hypothesisId": "B",
			"location": "ollama.go:148", "message": "Creating Ollama request",
			"data":      map[string]interface{}{"apiURL": apiURL, "model": apiModel, "baseURL": apiBaseURL, "isOpenRouter": isOpenRouter},
			"timestamp": time.Now().UnixMilli(),
		})
		logFile.WriteString(string(logData) + "\n")
		logFile.Close()
	}
	// #endregion

	// Создаем запрос
	req, err := http.NewRequestWithContext(context.Background(), "POST", apiURL, bytes.NewBuffer(jsonData))
	if err != nil {
		// #region agent log
		logFile, _ = os.OpenFile("/Users/alexey_pripadchev/Documents/Work/data_base/.cursor/debug.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if logFile != nil {
			logData, _ := json.Marshal(map[string]interface{}{
				"sessionId": "debug-session", "runId": "run1", "hypothesisId": "B",
				"location": "ollama.go:150", "message": "Failed to create request",
				"data":      map[string]interface{}{"error": err.Error()},
				"timestamp": time.Now().UnixMilli(),
			})
			logFile.WriteString(string(logData) + "\n")
			logFile.Close()
		}
		// #endregion
		logging.LogErrorf("create Ollama request failed: %s", err)
		stop = true
		return
	}

	req.Header.Set("Content-Type", "application/json")

	// Open Router требует заголовки для бесплатных моделей
	if isOpenRouter {
		req.Header.Set("HTTP-Referer", "https://github.com/siyuan-note/siyuan")
		req.Header.Set("X-Title", "SiYuan")
		// Используем API ключ из параметра или переменной окружения
		authKey := apiKey
		if authKey == "" {
			authKey = os.Getenv("OPENROUTER_API_KEY")
		}
		// Для Open Router API ключ обязателен для большинства моделей
		if authKey != "" {
			req.Header.Set("Authorization", "Bearer "+authKey)
		} else {
			// Для бесплатных моделей можно попробовать без ключа, но лучше использовать ключ
			logging.LogWarnf("Open Router API key not provided, some models may require authentication")
		}
	}

	// #region agent log
	logFile, _ = os.OpenFile("/Users/alexey_pripadchev/Documents/Work/data_base/.cursor/debug.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if logFile != nil {
		logData, _ := json.Marshal(map[string]interface{}{
			"sessionId": "debug-session", "runId": "run1", "hypothesisId": "A",
			"location": "ollama.go:176", "message": "Ollama request start",
			"data":      map[string]interface{}{"url": apiURL, "model": apiModel, "baseURL": apiBaseURL},
			"timestamp": time.Now().UnixMilli(),
		})
		logFile.WriteString(string(logData) + "\n")
		logFile.Close()
	}
	// #endregion

	// Выполняем запрос
	resp, err := client.Do(req)
	if err != nil {
		// #region agent log
		logFile, _ = os.OpenFile("/Users/alexey_pripadchev/Documents/Work/data_base/.cursor/debug.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if logFile != nil {
			logData, _ := json.Marshal(map[string]interface{}{
				"sessionId": "debug-session", "runId": "run1", "hypothesisId": "A",
				"location": "ollama.go:179", "message": "Ollama request failed",
				"data":      map[string]interface{}{"error": err.Error(), "url": apiURL, "baseURL": apiBaseURL},
				"timestamp": time.Now().UnixMilli(),
			})
			logFile.WriteString(string(logData) + "\n")
			logFile.Close()
		}
		// #endregion

		// Более понятное сообщение об ошибке
		errorMsg := "Ollama сервер недоступен"
		if strings.Contains(err.Error(), "connection refused") {
			errorMsg = "Ollama сервер не запущен. Установите Ollama с https://ollama.ai и запустите сервер"
		} else if strings.Contains(err.Error(), "timeout") {
			errorMsg = "Таймаут подключения к Ollama серверу"
		}
		PushErrMsg(errorMsg+". Проверьте логи для деталей", 5000)
		logging.LogErrorf("Ollama API request failed: %s", err)
		stop = true
		return
	}
	defer resp.Body.Close()

	// Читаем ответ
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		logging.LogErrorf("read Ollama response failed: %s", err)
		stop = true
		return
	}

	// #region agent log
	logFile, _ = os.OpenFile("/Users/alexey_pripadchev/Documents/Work/data_base/.cursor/debug.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if logFile != nil {
		logData, _ := json.Marshal(map[string]interface{}{
			"sessionId": "debug-session", "runId": "run1", "hypothesisId": "C",
			"location": "ollama.go:193", "message": "Ollama response received",
			"data":      map[string]interface{}{"statusCode": resp.StatusCode, "contentLength": len(body)},
			"timestamp": time.Now().UnixMilli(),
		})
		logFile.WriteString(string(logData) + "\n")
		logFile.Close()
	}
	// #endregion

	if resp.StatusCode != http.StatusOK {
		var errorMsg string
		var apiError map[string]interface{}
		if err := json.Unmarshal(body, &apiError); err == nil {
			if errObj, ok := apiError["error"].(map[string]interface{}); ok {
				if msg, ok := errObj["message"].(string); ok {
					errorMsg = msg
				} else {
					errorMsg = fmt.Sprintf("%v", errObj)
				}
			} else if errStr, ok := apiError["error"].(string); ok {
				errorMsg = errStr
			} else {
				errorMsg = string(body)
			}
		}
		if errorMsg == "" {
			errorMsg = string(body)
		}

		// #region agent log
		logFile, _ = os.OpenFile("/Users/alexey_pripadchev/Documents/Work/data_base/.cursor/debug.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if logFile != nil {
			logData, _ := json.Marshal(map[string]interface{}{
				"sessionId": "debug-session", "runId": "run1", "hypothesisId": "C",
				"location": "ollama.go:213", "message": "Ollama API error",
				"data":      map[string]interface{}{"statusCode": resp.StatusCode, "error": errorMsg, "body": string(body)},
				"timestamp": time.Now().UnixMilli(),
			})
			logFile.WriteString(string(logData) + "\n")
			logFile.Close()
		}
		// #endregion

		// Обработка специфичных ошибок
		if resp.StatusCode == 401 {
			// Ошибка аутентификации - для локального Ollama это нормально, модель загрузится автоматически
			logging.LogWarnf("Ollama API auth error [401]: %s - это нормально для облачных моделей, модель загрузится автоматически", errorMsg)
			// Не показываем ошибку пользователю, так как это может быть временная проблема
			// Модель загрузится автоматически при первом использовании
		} else {
			logging.LogErrorf("Ollama API error [%d]: %s", resp.StatusCode, errorMsg)
			errorMsgShort := errorMsg
			if len(errorMsg) > 100 {
				errorMsgShort = errorMsg[:100] + "..."
			}
			PushErrMsg(fmt.Sprintf("Ollama API error [%d]: %s", resp.StatusCode, errorMsgShort), 5000)
		}
		stop = true
		return
	}

	// Парсим ответ
	if isOpenRouter {
		// Open Router использует OpenAI-совместимый формат
		var openAIResp map[string]interface{}
		if err = json.Unmarshal(body, &openAIResp); err != nil {
			logging.LogErrorf("unmarshal Open Router response failed: %s", err)
			stop = true
			return
		}

		// Проверяем на ошибки
		if errObj, ok := openAIResp["error"].(map[string]interface{}); ok {
			errorMsg := ""
			if msg, ok := errObj["message"].(string); ok {
				errorMsg = msg
			} else {
				errorMsg = fmt.Sprintf("%v", errObj)
			}
			logging.LogErrorf("Open Router API error: %s", errorMsg)
			PushErrMsg(fmt.Sprintf("Open Router API error: %s", errorMsg), 5000)
			stop = true
			return
		}

		// Извлекаем текст из choices[0].message.content
		if choices, ok := openAIResp["choices"].([]interface{}); ok && len(choices) > 0 {
			if choice, ok := choices[0].(map[string]interface{}); ok {
				if message, ok := choice["message"].(map[string]interface{}); ok {
					if content, ok := message["content"].(string); ok {
						ret = content
					}
				}
			}
		}
	} else {
		// Стандартный Ollama формат
		var ollamaResp OllamaResponse
		if err = json.Unmarshal(body, &ollamaResp); err != nil {
			logging.LogErrorf("unmarshal Ollama response failed: %s", err)
			stop = true
			return
		}

		if ollamaResp.Error != "" {
			logging.LogErrorf("Ollama API error: %s", ollamaResp.Error)
			PushErrMsg(fmt.Sprintf("Ollama API error: %s", ollamaResp.Error), 5000)
			stop = true
			return
		}

		// Извлекаем текст ответа
		ret = ollamaResp.Message.Content
	}

	ret = strings.TrimSpace(ret)
	return
}
