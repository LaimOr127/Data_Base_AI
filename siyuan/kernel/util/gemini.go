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
	"strings"
	"time"

	"github.com/siyuan-note/logging"
)

type GeminiMessage struct {
	Role  string `json:"role"`
	Parts []Part `json:"parts"`
}

type Part struct {
	Text string `json:"text"`
}

type GeminiRequest struct {
	Contents         []GeminiMessage  `json:"contents"`
	GenerationConfig GenerationConfig `json:"generationConfig,omitempty"`
}

type GenerationConfig struct {
	Temperature     float64 `json:"temperature,omitempty"`
	MaxOutputTokens int     `json:"maxOutputTokens,omitempty"`
}

type GeminiResponse struct {
	Candidates []Candidate `json:"candidates"`
}

type Candidate struct {
	Content      Content `json:"content"`
	FinishReason string  `json:"finishReason"`
}

type Content struct {
	Parts []Part `json:"parts"`
	Role  string `json:"role"`
}

func GeminiChat(msg string, contextMsgs []string, apiKey, apiModel string, maxTokens int, temperature float64, timeout int, apiProxy string) (ret string, stop bool, err error) {
	var messages []GeminiMessage

	// Добавляем контекстные сообщения
	for _, ctxMsg := range contextMsgs {
		if "" == ctxMsg {
			continue
		}
		messages = append(messages, GeminiMessage{
			Role:  "user",
			Parts: []Part{{Text: ctxMsg}},
		})
	}

	// Добавляем текущее сообщение
	if "" != msg {
		messages = append(messages, GeminiMessage{
			Role:  "user",
			Parts: []Part{{Text: msg}},
		})
	}

	if 1 > len(messages) {
		stop = true
		return
	}

	// Формируем запрос
	reqBody := GeminiRequest{
		Contents: messages,
		GenerationConfig: GenerationConfig{
			Temperature:     temperature,
			MaxOutputTokens: maxTokens,
		},
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		logging.LogErrorf("marshal Gemini request failed: %s", err)
		stop = true
		return
	}

	// Формируем URL - правильный формат: /v1beta/models/{model}:generateContent?key={key}
	apiVersion := "v1beta"
	apiURL := fmt.Sprintf("https://generativelanguage.googleapis.com/%s/models/%s:generateContent?key=%s", apiVersion, apiModel, apiKey)

	// Создаем HTTP клиент
	client := &http.Client{
		Timeout: time.Duration(timeout) * time.Second,
	}

	// Настраиваем прокси, если указан
	if "" != apiProxy {
		proxyURL, parseErr := url.Parse(apiProxy)
		if parseErr != nil {
			logging.LogErrorf("Gemini API proxy failed: %v", parseErr)
		} else {
			client.Transport = &http.Transport{
				Proxy: http.ProxyURL(proxyURL),
			}
		}
	}

	// Создаем запрос
	req, err := http.NewRequestWithContext(context.Background(), "POST", apiURL, bytes.NewBuffer(jsonData))
	if err != nil {
		logging.LogErrorf("create Gemini request failed: %s", err)
		stop = true
		return
	}

	req.Header.Set("Content-Type", "application/json")

	// Выполняем запрос
	resp, err := client.Do(req)
	if err != nil {
		PushErrMsg("Requesting failed, please check kernel log for more details", 3000)
		logging.LogErrorf("Gemini API request failed: %s", err)
		stop = true
		return
	}
	defer resp.Body.Close()

	// Читаем ответ
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		logging.LogErrorf("read Gemini response failed: %s", err)
		stop = true
		return
	}

	if resp.StatusCode != http.StatusOK {
		var errorMsg string
		var apiError map[string]interface{}
		if err := json.Unmarshal(body, &apiError); err == nil {
			if errorObj, ok := apiError["error"].(map[string]interface{}); ok {
				if msg, ok := errorObj["message"].(string); ok {
					errorMsg = msg
				} else {
					errorMsg = fmt.Sprintf("%v", errorObj)
				}
			}
		}
		if errorMsg == "" {
			errorMsg = string(body)
		}
		logging.LogErrorf("Gemini API error [%d]: %s", resp.StatusCode, errorMsg)
		errorMsgShort := errorMsg
		if len(errorMsg) > 100 {
			errorMsgShort = errorMsg[:100] + "..."
		}
		PushErrMsg(fmt.Sprintf("Gemini API error [%d]: %s", resp.StatusCode, errorMsgShort), 5000)
		stop = true
		return
	}

	// Парсим ответ
	var geminiResp GeminiResponse
	if err = json.Unmarshal(body, &geminiResp); err != nil {
		logging.LogErrorf("unmarshal Gemini response failed: %s", err)
		stop = true
		return
	}

	if 1 > len(geminiResp.Candidates) {
		stop = true
		return
	}

	// Извлекаем текст ответа
	var buf strings.Builder
	candidate := geminiResp.Candidates[0]
	for _, part := range candidate.Content.Parts {
		buf.WriteString(part.Text)
	}

	ret = buf.String()
	ret = strings.TrimSpace(ret)

	// Определяем, нужно ли продолжать
	if candidate.FinishReason == "MAX_TOKENS" {
		stop = false
	} else {
		stop = true
	}

	return
}
