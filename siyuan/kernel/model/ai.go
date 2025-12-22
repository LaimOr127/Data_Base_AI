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

package model

import (
	"bytes"
	"encoding/json"
	"os"
	"strings"
	"time"

	"github.com/88250/lute/ast"
	"github.com/88250/lute/parse"
	"github.com/sashabaranov/go-openai"
	"github.com/siyuan-note/siyuan/kernel/treenode"
	"github.com/siyuan-note/siyuan/kernel/util"
)

func ChatGPT(msg string) (ret string) {
	if !isOpenAIAPIEnabled() {
		return
	}

	return chatGPT(msg, false)
}

func ChatGPTWithAction(ids []string, action string) (ret string) {
	if !isOpenAIAPIEnabled() {
		return
	}

	if "Clear context" == action {
		// AI clear context action https://github.com/siyuan-note/siyuan/issues/10255
		cachedContextMsg = nil
		return
	}

	msg := getBlocksContent(ids)
	ret = chatGPTWithAction(msg, action, false)
	return
}

var cachedContextMsg []string

func chatGPT(msg string, cloud bool) (ret string) {
	if "Clear context" == strings.TrimSpace(msg) {
		// AI clear context action https://github.com/siyuan-note/siyuan/issues/10255
		cachedContextMsg = nil
		return
	}

	ret, retCtxMsgs, err := chatGPTContinueWrite(msg, cachedContextMsg, cloud)
	if err != nil {
		return
	}
	cachedContextMsg = append(cachedContextMsg, retCtxMsgs...)
	return
}

func chatGPTWithAction(msg string, action string, cloud bool) (ret string) {
	action = strings.TrimSpace(action)
	if "" != action {
		msg = action + ":\n\n" + msg
	}
	ret, _, err := chatGPTContinueWrite(msg, nil, cloud)
	if err != nil {
		return
	}
	return
}

func chatGPTContinueWrite(msg string, contextMsgs []string, cloud bool) (ret string, retContextMsgs []string, err error) {
	start := time.Now()
	util.IncAIRequests()
	defer func() {
		duration := time.Since(start)
		util.AddAIDuration(duration)
		if err != nil {
			util.IncAIErrors()
		}
	}()

	util.PushEndlessProgress("Requesting...")
	defer util.ClearPushProgress(100)

	var maxContexts int
	if Conf.AI.Ollama != nil && Conf.AI.Ollama.APIBaseURL != "" {
		maxContexts = Conf.AI.Ollama.APIMaxContexts
	} else if Conf.AI.Gemini != nil && Conf.AI.Gemini.APIKey != "" {
		maxContexts = Conf.AI.Gemini.APIMaxContexts
	} else {
		maxContexts = Conf.AI.OpenAI.APIMaxContexts
	}
	if maxContexts < len(contextMsgs) {
		contextMsgs = contextMsgs[len(contextMsgs)-maxContexts:]
	}

	var gpt GPT
	if cloud {
		gpt = &CloudGPT{}
	} else {
		// Проверяем провайдер AI - приоритет Ollama (бесплатный и быстрый)
		if Conf.AI.Ollama != nil && Conf.AI.Ollama.APIBaseURL != "" {
			// Используем Ollama, если настроен
			gpt = &OllamaGPT{
				apiBaseURL:  Conf.AI.Ollama.APIBaseURL,
				apiModel:    Conf.AI.Ollama.APIModel,
				apiTimeout:  Conf.AI.Ollama.APITimeout,
				apiProxy:    Conf.AI.Ollama.APIProxy,
				maxTokens:   Conf.AI.Ollama.APIMaxTokens,
				temperature: Conf.AI.Ollama.APITemperature,
				apiKey:      Conf.AI.Ollama.APIKey,
			}
		} else if Conf.AI.Gemini != nil && Conf.AI.Gemini.APIKey != "" {
			// Используем Gemini, если API ключ установлен
			gpt = &GeminiGPT{
				apiKey:      Conf.AI.Gemini.APIKey,
				apiModel:    Conf.AI.Gemini.APIModel,
				apiTimeout:  Conf.AI.Gemini.APITimeout,
				apiProxy:    Conf.AI.Gemini.APIProxy,
				maxTokens:   Conf.AI.Gemini.APIMaxTokens,
				temperature: Conf.AI.Gemini.APITemperature,
			}
		} else {
			// Используем OpenAI по умолчанию
			gpt = &OpenAIGPT{c: util.NewOpenAIClient(Conf.AI.OpenAI.APIKey, Conf.AI.OpenAI.APIProxy, Conf.AI.OpenAI.APIBaseURL, Conf.AI.OpenAI.APIUserAgent, Conf.AI.OpenAI.APIVersion, Conf.AI.OpenAI.APIProvider)}
		}
	}

	buf := &bytes.Buffer{}
	for i := 0; i < maxContexts; i++ {
		part, stop, chatErr := gpt.chat(msg, contextMsgs)
		buf.WriteString(part)

		if stop || nil != chatErr {
			break
		}

		util.PushEndlessProgress("Continue requesting...")
	}

	ret = buf.String()
	ret = strings.TrimSpace(ret)
	if "" != ret {
		retContextMsgs = append(retContextMsgs, msg, ret)
	}
	return
}

func isOpenAIAPIEnabled() bool {
	// Проверяем Ollama, Gemini или OpenAI
	if Conf.AI.Ollama != nil && Conf.AI.Ollama.APIBaseURL != "" {
		return true
	}
	if Conf.AI.Gemini != nil && Conf.AI.Gemini.APIKey != "" {
		return true
	}
	if "" == Conf.AI.OpenAI.APIKey {
		util.PushMsg(Conf.Language(193), 5000)
		return false
	}
	return true
}

func getBlocksContent(ids []string) string {
	var nodes []*ast.Node
	trees := map[string]*parse.Tree{}
	for _, id := range ids {
		bt := treenode.GetBlockTree(id)
		if nil == bt {
			continue
		}

		var tree *parse.Tree
		if tree = trees[bt.RootID]; nil == tree {
			tree, _ = LoadTreeByBlockID(bt.RootID)
			if nil == tree {
				continue
			}

			trees[bt.RootID] = tree
		}

		if node := treenode.GetNodeInTree(tree, id); nil != node {
			if ast.NodeDocument == node.Type {
				for child := node.FirstChild; nil != child; child = child.Next {
					nodes = append(nodes, child)
				}
			} else {
				nodes = append(nodes, node)
			}
		}
	}

	luteEngine := util.NewLute()
	buf := bytes.Buffer{}
	for _, node := range nodes {
		md := treenode.ExportNodeStdMd(node, luteEngine)
		buf.WriteString(md)
		buf.WriteString("\n\n")
	}
	return buf.String()
}

type GPT interface {
	chat(msg string, contextMsgs []string) (partRet string, stop bool, err error)
}

type OpenAIGPT struct {
	c *openai.Client
}

func (gpt *OpenAIGPT) chat(msg string, contextMsgs []string) (partRet string, stop bool, err error) {
	return util.ChatGPT(msg, contextMsgs, gpt.c, Conf.AI.OpenAI.APIModel, Conf.AI.OpenAI.APIMaxTokens, Conf.AI.OpenAI.APITemperature, Conf.AI.OpenAI.APITimeout)
}

type CloudGPT struct {
}

func (gpt *CloudGPT) chat(msg string, contextMsgs []string) (partRet string, stop bool, err error) {
	return CloudChatGPT(msg, contextMsgs)
}

type GeminiGPT struct {
	apiKey      string
	apiModel    string
	apiTimeout  int
	apiProxy    string
	maxTokens   int
	temperature float64
}

func (gpt *GeminiGPT) chat(msg string, contextMsgs []string) (partRet string, stop bool, err error) {
	return util.GeminiChat(msg, contextMsgs, gpt.apiKey, gpt.apiModel, gpt.maxTokens, gpt.temperature, gpt.apiTimeout, gpt.apiProxy)
}

type OllamaGPT struct {
	apiBaseURL  string
	apiModel    string
	apiTimeout  int
	apiProxy    string
	maxTokens   int
	temperature float64
	apiKey      string
}

func (gpt *OllamaGPT) chat(msg string, contextMsgs []string) (partRet string, stop bool, err error) {
	// #region agent log
	logFile, _ := os.OpenFile("/Users/alexey_pripadchev/Documents/Work/data_base/.cursor/debug.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if logFile != nil {
		logData, _ := json.Marshal(map[string]interface{}{
			"sessionId": "debug-session", "runId": "run1", "hypothesisId": "D",
			"location": "ai.go:259", "message": "OllamaGPT.chat called",
			"data": map[string]interface{}{
				"apiBaseURL": gpt.apiBaseURL, "apiModel": gpt.apiModel,
				"apiTimeout": gpt.apiTimeout, "maxTokens": gpt.maxTokens,
				"temperature": gpt.temperature, "hasApiKey": gpt.apiKey != "",
			},
			"timestamp": time.Now().UnixMilli(),
		})
		logFile.WriteString(string(logData) + "\n")
		logFile.Close()
	}
	// #endregion
	return util.OllamaChat(msg, contextMsgs, gpt.apiModel, gpt.maxTokens, gpt.temperature, gpt.apiTimeout, gpt.apiProxy, gpt.apiBaseURL, gpt.apiKey)
}
