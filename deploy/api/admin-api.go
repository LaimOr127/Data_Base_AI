package api

import (
	"encoding/json"
	"net/http"
	"os"
	"time"
)

// AdminAPI - простой API для управления DIGroup
type AdminAPI struct {
	port string
}

// NewAdminAPI создает новый Admin API сервер
func NewAdminAPI(port string) *AdminAPI {
	return &AdminAPI{port: port}
}

// Start запускает API сервер
func (a *AdminAPI) Start() error {
	http.HandleFunc("/api/admin/status", a.handleStatus)
	http.HandleFunc("/api/admin/health", a.handleHealth)
	http.HandleFunc("/api/admin/restart", a.handleRestart)
	http.HandleFunc("/api/admin/backup", a.handleBackup)

	return http.ListenAndServe(":"+a.port, nil)
}

// StatusResponse - ответ со статусом
type StatusResponse struct {
	Status    string                 `json:"status"`
	Timestamp time.Time              `json:"timestamp"`
	Services  map[string]interface{} `json:"services"`
	Resources map[string]interface{} `json:"resources"`
}

func (a *AdminAPI) handleStatus(w http.ResponseWriter, r *http.Request) {
	// Проверка авторизации
	if !a.checkAuth(r) {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	response := StatusResponse{
		Status:    "ok",
		Timestamp: time.Now(),
		Services: map[string]interface{}{
			"kernel": a.checkKernel(),
			"nginx":  a.checkNginx(),
		},
		Resources: a.getResources(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (a *AdminAPI) handleHealth(w http.ResponseWriter, r *http.Request) {
	health := map[string]interface{}{
		"status":    "healthy",
		"timestamp": time.Now(),
		"kernel":    a.checkKernel(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(health)
}

func (a *AdminAPI) handleRestart(w http.ResponseWriter, r *http.Request) {
	if !a.checkAuth(r) {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Здесь можно добавить логику перезапуска
	response := map[string]interface{}{
		"status":  "restarting",
		"message": "Service restart initiated",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (a *AdminAPI) handleBackup(w http.ResponseWriter, r *http.Request) {
	if !a.checkAuth(r) {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Здесь можно добавить логику создания бэкапа
	response := map[string]interface{}{
		"status":  "backup_started",
		"message": "Backup process initiated",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (a *AdminAPI) checkAuth(r *http.Request) bool {
	// Простая проверка через заголовок или токен
	token := r.Header.Get("X-Admin-Token")
	expectedToken := os.Getenv("ADMIN_API_TOKEN")
	return token == expectedToken && expectedToken != ""
}

func (a *AdminAPI) checkKernel() bool {
	resp, err := http.Get("http://127.0.0.1:6806/api/system/version")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode == 200
}

func (a *AdminAPI) checkNginx() bool {
	// Проверка через systemd или другой способ
	return true
}

func (a *AdminAPI) getResources() map[string]interface{} {
	// Получение информации о ресурсах системы
	return map[string]interface{}{
		"cpu":    "N/A",
		"memory": "N/A",
		"disk":   "N/A",
	}
}
