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
	"sync"
	"sync/atomic"
	"time"
)

var (
	// HTTP метрики
	httpRequestsTotal   int64
	httpRequestsErrors  int64
	httpRequestDuration int64 // в миллисекундах
	httpRequestsActive  int64

	// WebSocket метрики
	wsConnectionsTotal  int64
	wsConnectionsActive int64
	wsMessagesTotal     int64

	// Database метрики
	dbQueriesTotal  int64
	dbQueriesErrors int64
	dbQueryDuration int64 // в миллисекундах

	// AI метрики
	aiRequestsTotal   int64
	aiRequestsErrors  int64
	aiRequestDuration int64 // в миллисекундах

	// Системные метрики
	uptimeStart = time.Now()

	metricsLock sync.RWMutex
)

// IncHTTPRequests увеличивает счетчик HTTP запросов
func IncHTTPRequests() {
	atomic.AddInt64(&httpRequestsTotal, 1)
	atomic.AddInt64(&httpRequestsActive, 1)
}

// DecHTTPRequests уменьшает счетчик активных HTTP запросов
func DecHTTPRequests() {
	atomic.AddInt64(&httpRequestsActive, -1)
}

// IncHTTPErrors увеличивает счетчик ошибок HTTP
func IncHTTPErrors() {
	atomic.AddInt64(&httpRequestsErrors, 1)
}

// AddHTTPDuration добавляет время выполнения HTTP запроса
func AddHTTPDuration(duration time.Duration) {
	atomic.AddInt64(&httpRequestDuration, int64(duration.Milliseconds()))
}

// IncWSConnections увеличивает счетчик WebSocket подключений
func IncWSConnections() {
	atomic.AddInt64(&wsConnectionsTotal, 1)
	atomic.AddInt64(&wsConnectionsActive, 1)
}

// DecWSConnections уменьшает счетчик активных WebSocket подключений
func DecWSConnections() {
	atomic.AddInt64(&wsConnectionsActive, -1)
}

// IncWSMessages увеличивает счетчик WebSocket сообщений
func IncWSMessages() {
	atomic.AddInt64(&wsMessagesTotal, 1)
}

// IncDBQueries увеличивает счетчик запросов к БД
func IncDBQueries() {
	atomic.AddInt64(&dbQueriesTotal, 1)
}

// IncDBErrors увеличивает счетчик ошибок БД
func IncDBErrors() {
	atomic.AddInt64(&dbQueriesErrors, 1)
}

// AddDBDuration добавляет время выполнения запроса к БД
func AddDBDuration(duration time.Duration) {
	atomic.AddInt64(&dbQueryDuration, int64(duration.Milliseconds()))
}

// IncAIRequests увеличивает счетчик AI запросов
func IncAIRequests() {
	atomic.AddInt64(&aiRequestsTotal, 1)
}

// IncAIErrors увеличивает счетчик ошибок AI
func IncAIErrors() {
	atomic.AddInt64(&aiRequestsErrors, 1)
}

// AddAIDuration добавляет время выполнения AI запроса
func AddAIDuration(duration time.Duration) {
	atomic.AddInt64(&aiRequestDuration, int64(duration.Milliseconds()))
}

// GetMetrics возвращает все метрики в формате Prometheus
func GetMetrics() map[string]interface{} {
	metricsLock.RLock()
	defer metricsLock.RUnlock()

	uptime := time.Since(uptimeStart).Seconds()

	httpTotal := atomic.LoadInt64(&httpRequestsTotal)
	httpErrors := atomic.LoadInt64(&httpRequestsErrors)
	httpActive := atomic.LoadInt64(&httpRequestsActive)
	httpDuration := atomic.LoadInt64(&httpRequestDuration)

	var avgHTTPDuration float64
	if httpTotal > 0 {
		avgHTTPDuration = float64(httpDuration) / float64(httpTotal)
	}

	wsTotal := atomic.LoadInt64(&wsConnectionsTotal)
	wsActive := atomic.LoadInt64(&wsConnectionsActive)
	wsMessages := atomic.LoadInt64(&wsMessagesTotal)

	dbTotal := atomic.LoadInt64(&dbQueriesTotal)
	dbErrors := atomic.LoadInt64(&dbQueriesErrors)
	dbDuration := atomic.LoadInt64(&dbQueryDuration)

	var avgDBDuration float64
	if dbTotal > 0 {
		avgDBDuration = float64(dbDuration) / float64(dbTotal)
	}

	aiTotal := atomic.LoadInt64(&aiRequestsTotal)
	aiErrors := atomic.LoadInt64(&aiRequestsErrors)
	aiDuration := atomic.LoadInt64(&aiRequestDuration)

	var avgAIDuration float64
	if aiTotal > 0 {
		avgAIDuration = float64(aiDuration) / float64(aiTotal)
	}

	memStats := GetMemStats()

	return map[string]interface{}{
		"uptime_seconds":               uptime,
		"http_requests_total":          httpTotal,
		"http_requests_errors":         httpErrors,
		"http_requests_active":         httpActive,
		"http_request_duration_ms_avg": avgHTTPDuration,
		"ws_connections_total":         wsTotal,
		"ws_connections_active":        wsActive,
		"ws_messages_total":            wsMessages,
		"db_queries_total":             dbTotal,
		"db_queries_errors":            dbErrors,
		"db_query_duration_ms_avg":     avgDBDuration,
		"ai_requests_total":            aiTotal,
		"ai_requests_errors":           aiErrors,
		"ai_request_duration_ms_avg":   avgAIDuration,
		"goroutines":                   GetGoroutineCount(),
		"panic_count":                  GetPanicCount(),
		"memory_alloc_bytes":           memStats.Alloc,
		"memory_sys_bytes":             memStats.Sys,
		"memory_heap_alloc_bytes":      memStats.HeapAlloc,
		"memory_heap_sys_bytes":        memStats.HeapSys,
		"memory_num_gc":                memStats.NumGC,
	}
}

// FormatPrometheusMetrics форматирует метрики в формате Prometheus
func FormatPrometheusMetrics() string {
	metrics := GetMetrics()

	var result string
	result += "# HELP siyuan_uptime_seconds Uptime in seconds\n"
	result += "# TYPE siyuan_uptime_seconds gauge\n"
	result += fmt.Sprintf("siyuan_uptime_seconds %.2f\n\n", metrics["uptime_seconds"])

	result += "# HELP siyuan_http_requests_total Total HTTP requests\n"
	result += "# TYPE siyuan_http_requests_total counter\n"
	result += fmt.Sprintf("siyuan_http_requests_total %d\n\n", metrics["http_requests_total"])

	result += "# HELP siyuan_http_requests_errors Total HTTP errors\n"
	result += "# TYPE siyuan_http_requests_errors counter\n"
	result += fmt.Sprintf("siyuan_http_requests_errors %d\n\n", metrics["http_requests_errors"])

	result += "# HELP siyuan_http_requests_active Active HTTP requests\n"
	result += "# TYPE siyuan_http_requests_active gauge\n"
	result += fmt.Sprintf("siyuan_http_requests_active %d\n\n", metrics["http_requests_active"])

	result += "# HELP siyuan_http_request_duration_ms_avg Average HTTP request duration in milliseconds\n"
	result += "# TYPE siyuan_http_request_duration_ms_avg gauge\n"
	result += fmt.Sprintf("siyuan_http_request_duration_ms_avg %.2f\n\n", metrics["http_request_duration_ms_avg"])

	result += "# HELP siyuan_ws_connections_total Total WebSocket connections\n"
	result += "# TYPE siyuan_ws_connections_total counter\n"
	result += fmt.Sprintf("siyuan_ws_connections_total %d\n\n", metrics["ws_connections_total"])

	result += "# HELP siyuan_ws_connections_active Active WebSocket connections\n"
	result += "# TYPE siyuan_ws_connections_active gauge\n"
	result += fmt.Sprintf("siyuan_ws_connections_active %d\n\n", metrics["ws_connections_active"])

	result += "# HELP siyuan_ws_messages_total Total WebSocket messages\n"
	result += "# TYPE siyuan_ws_messages_total counter\n"
	result += fmt.Sprintf("siyuan_ws_messages_total %d\n\n", metrics["ws_messages_total"])

	result += "# HELP siyuan_db_queries_total Total database queries\n"
	result += "# TYPE siyuan_db_queries_total counter\n"
	result += fmt.Sprintf("siyuan_db_queries_total %d\n\n", metrics["db_queries_total"])

	result += "# HELP siyuan_db_queries_errors Total database errors\n"
	result += "# TYPE siyuan_db_queries_errors counter\n"
	result += fmt.Sprintf("siyuan_db_queries_errors %d\n\n", metrics["db_queries_errors"])

	result += "# HELP siyuan_db_query_duration_ms_avg Average database query duration in milliseconds\n"
	result += "# TYPE siyuan_db_query_duration_ms_avg gauge\n"
	result += fmt.Sprintf("siyuan_db_query_duration_ms_avg %.2f\n\n", metrics["db_query_duration_ms_avg"])

	result += "# HELP siyuan_ai_requests_total Total AI requests\n"
	result += "# TYPE siyuan_ai_requests_total counter\n"
	result += fmt.Sprintf("siyuan_ai_requests_total %d\n\n", metrics["ai_requests_total"])

	result += "# HELP siyuan_ai_requests_errors Total AI errors\n"
	result += "# TYPE siyuan_ai_requests_errors counter\n"
	result += fmt.Sprintf("siyuan_ai_requests_errors %d\n\n", metrics["ai_requests_errors"])

	result += "# HELP siyuan_ai_request_duration_ms_avg Average AI request duration in milliseconds\n"
	result += "# TYPE siyuan_ai_request_duration_ms_avg gauge\n"
	result += fmt.Sprintf("siyuan_ai_request_duration_ms_avg %.2f\n\n", metrics["ai_request_duration_ms_avg"])

	result += "# HELP siyuan_goroutines Number of goroutines\n"
	result += "# TYPE siyuan_goroutines gauge\n"
	result += fmt.Sprintf("siyuan_goroutines %d\n\n", metrics["goroutines"])

	result += "# HELP siyuan_panic_count Total panic count\n"
	result += "# TYPE siyuan_panic_count counter\n"
	result += fmt.Sprintf("siyuan_panic_count %d\n\n", metrics["panic_count"])

	result += "# HELP siyuan_memory_alloc_bytes Memory allocated in bytes\n"
	result += "# TYPE siyuan_memory_alloc_bytes gauge\n"
	result += fmt.Sprintf("siyuan_memory_alloc_bytes %d\n\n", metrics["memory_alloc_bytes"])

	result += "# HELP siyuan_memory_sys_bytes Memory system in bytes\n"
	result += "# TYPE siyuan_memory_sys_bytes gauge\n"
	result += fmt.Sprintf("siyuan_memory_sys_bytes %d\n\n", metrics["memory_sys_bytes"])

	result += "# HELP siyuan_memory_heap_alloc_bytes Heap memory allocated in bytes\n"
	result += "# TYPE siyuan_memory_heap_alloc_bytes gauge\n"
	result += fmt.Sprintf("siyuan_memory_heap_alloc_bytes %d\n\n", metrics["memory_heap_alloc_bytes"])

	result += "# HELP siyuan_memory_num_gc Number of GC runs\n"
	result += "# TYPE siyuan_memory_num_gc counter\n"
	result += fmt.Sprintf("siyuan_memory_num_gc %d\n", metrics["memory_num_gc"])

	return result
}
