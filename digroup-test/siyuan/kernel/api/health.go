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

package api

import (
	"net/http"
	"runtime"

	"github.com/88250/gulu"
	"github.com/gin-gonic/gin"
	"github.com/siyuan-note/siyuan/kernel/model"
	"github.com/siyuan-note/siyuan/kernel/util"
)

// healthCheck проверяет состояние сервиса
func healthCheck(c *gin.Context) {
	ret := gulu.Ret.NewResult()
	defer c.JSON(http.StatusOK, ret)

	// Получаем метрики
	metrics := util.GetMetrics()

	// Проверяем базовые компоненты
	health := map[string]interface{}{
		"status":      "healthy",
		"uptime":      metrics["uptime_seconds"],
		"goroutines":  runtime.NumGoroutine(),
		"panic_count": util.GetPanicCount(),
	}

	// Проверяем, что kernel загружен
	if !util.IsBooted() {
		health["status"] = "booting"
		ret.Code = 503 // Service Unavailable
		ret.Data = health
		return
	}

	// Проверяем, что сервер работает
	if !util.HttpServing {
		health["status"] = "not_serving"
		ret.Code = 503
		ret.Data = health
		return
	}

	// Проверяем критичные компоненты
	if model.Conf == nil {
		health["status"] = "config_error"
		ret.Code = 503
		ret.Data = health
		return
	}

	ret.Data = health
}

// metrics возвращает метрики в формате Prometheus
func metrics(c *gin.Context) {
	c.Header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
	c.String(http.StatusOK, util.FormatPrometheusMetrics())
}

// metricsJSON возвращает метрики в формате JSON
func metricsJSON(c *gin.Context) {
	ret := gulu.Ret.NewResult()
	defer c.JSON(http.StatusOK, ret)

	ret.Data = util.GetMetrics()
}
