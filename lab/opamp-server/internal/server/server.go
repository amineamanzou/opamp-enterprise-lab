package server

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"html/template"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	opampserver "github.com/open-telemetry/opamp-go/server"
	opamptypes "github.com/open-telemetry/opamp-go/server/types"

	"github.com/open-telemetry/opamp-go/protobufs"
)

type Agent struct {
	ID                 string    `json:"id"`
	InstanceUID        string    `json:"instance_uid,omitempty"`
	Ring               string    `json:"ring"`
	Version            string    `json:"version"`
	Hostname           string    `json:"hostname"`
	Health             string    `json:"health"`
	Capabilities       uint64    `json:"capabilities,omitempty"`
	DesiredConfigHash  string    `json:"desired_config_hash,omitempty"`
	EffectiveConfig    string    `json:"effective_config,omitempty"`
	RemoteConfigStatus string    `json:"remote_config_status,omitempty"`
	RestartPending     bool      `json:"restart_command_pending,omitempty"`
	Connected          bool      `json:"connected"`
	UpdatedAt          time.Time `json:"updated_at"`
	LimitedMetadata    bool      `json:"limited_metadata,omitempty"`
}

type Stats struct {
	Agents          int       `json:"agents"`
	ConnectedAgents int       `json:"connected_agents"`
	Connections     int       `json:"connections"`
	LimitedMetadata int       `json:"limited_metadata_agents"`
	HeapAllocBytes  uint64    `json:"heap_alloc_bytes"`
	HeapSysBytes    uint64    `json:"heap_sys_bytes"`
	RuntimeSysBytes uint64    `json:"runtime_sys_bytes"`
	NumGoroutine    int       `json:"num_goroutine"`
	CollectedAt     time.Time `json:"collected_at"`
}

type Event struct {
	Sequence           uint64    `json:"sequence"`
	Timestamp          time.Time `json:"timestamp"`
	Action             string    `json:"action"`
	AgentID            string    `json:"agent_id,omitempty"`
	InstanceUID        string    `json:"instance_uid,omitempty"`
	Ring               string    `json:"ring,omitempty"`
	Hostname           string    `json:"hostname,omitempty"`
	PreviousVersion    string    `json:"previous_version,omitempty"`
	CurrentVersion     string    `json:"current_version,omitempty"`
	Direction          string    `json:"direction,omitempty"`
	PreviousHealth     string    `json:"previous_health,omitempty"`
	CurrentHealth      string    `json:"current_health,omitempty"`
	PreviousStatus     string    `json:"previous_status,omitempty"`
	CurrentStatus      string    `json:"current_status,omitempty"`
	PreviousConfigHash string    `json:"previous_config_hash,omitempty"`
	CurrentConfigHash  string    `json:"current_config_hash,omitempty"`
	Reason             string    `json:"reason,omitempty"`
}

type ConfigAssignment struct {
	Ring   string `json:"ring"`
	Config string `json:"config"`
}

type Server struct {
	mu               sync.RWMutex
	agents           map[string]Agent
	agentsByInstance map[string]string
	configs          map[string]ConfigAssignment
	connections      map[opamptypes.Connection]string
	restartPending   map[string]bool
	events           []Event
	nextEventSeq     uint64
	opampHandler     opampserver.HTTPHandlerFunc
	opampConnContext opampserver.ConnContext
	now              func() time.Time
	statePath        string
	persistCh        chan struct{}
}

type persistedState struct {
	Agents           map[string]Agent            `json:"agents"`
	AgentsByInstance map[string]string           `json:"agents_by_instance"`
	Configs          map[string]ConfigAssignment `json:"configs"`
	Events           []Event                     `json:"events,omitempty"`
	NextEventSeq     uint64                      `json:"next_event_sequence,omitempty"`
}

func New() *Server {
	srv := &Server{
		agents:           map[string]Agent{},
		agentsByInstance: map[string]string{},
		configs:          map[string]ConfigAssignment{},
		connections:      map[opamptypes.Connection]string{},
		restartPending:   map[string]bool{},
		nextEventSeq:     1,
		now:              time.Now,
		persistCh:        make(chan struct{}, 1),
	}
	if dataDir := os.Getenv("OPAMP_DATA_DIR"); dataDir != "" {
		srv.statePath = filepath.Join(dataDir, "state.json")
		if err := srv.loadState(); err != nil {
			fmt.Fprintf(os.Stderr, "load opamp state: %v\n", err)
		}
		go srv.persistLoop()
	}
	opampSrv := opampserver.New(logAdapter{})
	handler, connContext, err := opampSrv.Attach(opampserver.Settings{
		Callbacks: opamptypes.Callbacks{
			OnConnecting: srv.onOpAMPConnecting,
		},
	})
	if err != nil {
		panic(fmt.Sprintf("attach opamp server: %v", err))
	}
	srv.opampHandler = handler
	srv.opampConnContext = connContext
	return srv
}

func (s *Server) Router() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", s.uiRoot)
	mux.HandleFunc("GET /agent", s.uiAgent)
	mux.HandleFunc("POST /agent/{id}/config", s.uiAssignConfig)
	mux.HandleFunc("POST /agent/{id}/restart", s.uiRestartAgent)
	mux.HandleFunc("GET /healthz", s.health)
	mux.HandleFunc("GET /v1/inventory", s.inventory)
	mux.HandleFunc("GET /v1/stats", s.stats)
	mux.HandleFunc("GET /v1/events", s.eventsHandler)
	mux.HandleFunc("GET /v1/opamp/connections", s.opampConnections)
	mux.HandleFunc("/v1/opamp", s.opampHandler)
	mux.HandleFunc("POST /v1/agents", s.upsertAgent)
	mux.HandleFunc("GET /v1/agents/{id}", s.getAgent)
	mux.HandleFunc("POST /v1/agents/{id}/restart", s.restartAgent)
	mux.HandleFunc("PUT /v1/agents/{id}/config", s.assignConfig)
	mux.HandleFunc("POST /v1/agents/{id}/effective-config", s.reportEffectiveConfig)
	mux.HandleFunc("PUT /v1/rings/{ring}/config", s.assignRingConfig)
	return mux
}

func (s *Server) ConnContext(ctx context.Context, c net.Conn) context.Context {
	if s.opampConnContext == nil {
		return ctx
	}
	return s.opampConnContext(ctx, c)
}

func (s *Server) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) loadState() error {
	if s.statePath == "" {
		return nil
	}
	body, err := os.ReadFile(s.statePath)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil
		}
		return err
	}
	var state persistedState
	if err := json.Unmarshal(body, &state); err != nil {
		return err
	}
	if state.Agents != nil {
		for id, agent := range state.Agents {
			agent.Connected = false
			agent.RestartPending = false
			state.Agents[id] = agent
		}
		s.agents = state.Agents
	}
	if state.AgentsByInstance != nil {
		s.agentsByInstance = state.AgentsByInstance
	}
	if state.Configs != nil {
		s.configs = state.Configs
	}
	if state.Events != nil {
		s.events = state.Events
	}
	if state.NextEventSeq > 0 {
		s.nextEventSeq = state.NextEventSeq
	} else {
		for _, event := range s.events {
			if event.Sequence >= s.nextEventSeq {
				s.nextEventSeq = event.Sequence + 1
			}
		}
	}
	return nil
}

func (s *Server) persistLoop() {
	var timer *time.Timer
	for range s.persistCh {
		if timer != nil {
			timer.Stop()
		}
		timer = time.NewTimer(500 * time.Millisecond)
		<-timer.C
		if err := s.persistState(); err != nil {
			fmt.Fprintf(os.Stderr, "persist opamp state: %v\n", err)
		}
	}
}

func (s *Server) schedulePersistLocked() {
	if s.statePath == "" {
		return
	}
	select {
	case s.persistCh <- struct{}{}:
	default:
	}
}

func (s *Server) persistState() error {
	if s.statePath == "" {
		return nil
	}
	s.mu.RLock()
	state := persistedState{
		Agents:           make(map[string]Agent, len(s.agents)),
		AgentsByInstance: make(map[string]string, len(s.agentsByInstance)),
		Configs:          make(map[string]ConfigAssignment, len(s.configs)),
		Events:           append([]Event(nil), s.events...),
		NextEventSeq:     s.nextEventSeq,
	}
	for id, agent := range s.agents {
		agent.Connected = false
		agent.RestartPending = false
		state.Agents[id] = agent
	}
	for instanceUID, agentID := range s.agentsByInstance {
		state.AgentsByInstance[instanceUID] = agentID
	}
	for ring, assignment := range s.configs {
		state.Configs[ring] = assignment
	}
	s.mu.RUnlock()

	if err := os.MkdirAll(filepath.Dir(s.statePath), 0750); err != nil {
		return err
	}
	body, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}
	tmp := s.statePath + ".tmp"
	if err := os.WriteFile(tmp, body, 0600); err != nil {
		return err
	}
	return os.Rename(tmp, s.statePath)
}

func (s *Server) uiRoot(w http.ResponseWriter, _ *http.Request) {
	s.mu.RLock()
	agents := make([]Agent, 0, len(s.agents))
	for _, agent := range s.agents {
		agents = append(agents, publicAgent(agent))
	}
	s.mu.RUnlock()

	sort.Slice(agents, func(i, j int) bool {
		return agents[i].ID < agents[j].ID
	})

	writeHTML(w, http.StatusOK, uiRootTemplate, struct {
		Agents []Agent
	}{Agents: agents})
}

func (s *Server) uiAgent(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimSpace(r.URL.Query().Get("id"))
	if id == "" {
		writeHTML(w, http.StatusBadRequest, uiErrorTemplate, map[string]string{"Error": "missing_agent_id"})
		return
	}

	s.mu.RLock()
	agent, ok := s.findAgentLocked(id)
	s.mu.RUnlock()
	if !ok {
		writeHTML(w, http.StatusNotFound, uiErrorTemplate, map[string]string{"Error": "agent_not_found"})
		return
	}

	writeHTML(w, http.StatusOK, uiAgentTemplate, struct {
		Agent Agent
	}{Agent: publicAgent(agent)})
}

func (s *Server) uiAssignConfig(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if err := r.ParseForm(); err != nil {
		writeHTML(w, http.StatusBadRequest, uiErrorTemplate, map[string]string{"Error": "invalid_form"})
		return
	}

	assignment := ConfigAssignment{
		Ring:   r.Form.Get("ring"),
		Config: r.Form.Get("config"),
	}
	if _, err := s.setAgentConfig(id, assignment); err != nil {
		status := http.StatusBadRequest
		if errors.Is(err, errAgentNotFound) {
			status = http.StatusNotFound
		}
		if errors.Is(err, errRingMismatch) {
			status = http.StatusConflict
		}
		writeHTML(w, status, uiErrorTemplate, map[string]string{"Error": err.Error()})
		return
	}

	http.Redirect(w, r, "/agent?id="+id, http.StatusSeeOther)
}

func (s *Server) uiRestartAgent(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if err := s.setAgentRestart(id); err != nil {
		status := http.StatusBadRequest
		if errors.Is(err, errAgentNotFound) {
			status = http.StatusNotFound
		}
		if errors.Is(err, errAgentNotConnected) {
			status = http.StatusConflict
		}
		if errors.Is(err, errUnsupportedCapability) {
			status = http.StatusUnprocessableEntity
		}
		writeHTML(w, status, uiErrorTemplate, map[string]string{"Error": err.Error()})
		return
	}
	http.Redirect(w, r, "/agent?id="+id, http.StatusSeeOther)
}

func (s *Server) inventory(w http.ResponseWriter, _ *http.Request) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	agents := make([]Agent, 0, len(s.agents))
	for _, agent := range s.agents {
		agents = append(agents, publicAgent(agent))
	}
	sort.Slice(agents, func(i, j int) bool {
		return agents[i].ID < agents[j].ID
	})

	writeJSON(w, http.StatusOK, map[string]any{"agents": agents})
}

func (s *Server) opampConnections(w http.ResponseWriter, _ *http.Request) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	connections := make([]map[string]string, 0, len(s.connections))
	for conn, instanceUID := range s.connections {
		remoteAddr := ""
		if conn.Connection() != nil && conn.Connection().RemoteAddr() != nil {
			remoteAddr = conn.Connection().RemoteAddr().String()
		}
		connections = append(connections, map[string]string{
			"instance_uid": instanceUID,
			"remote_addr":  remoteAddr,
		})
	}
	sort.Slice(connections, func(i, j int) bool {
		return connections[i]["instance_uid"] < connections[j]["instance_uid"]
	})

	writeJSON(w, http.StatusOK, map[string]any{"connections": connections})
}

func (s *Server) eventsHandler(w http.ResponseWriter, r *http.Request) {
	afterSeq, _ := strconv.ParseUint(r.URL.Query().Get("after_seq"), 10, 64)
	limit := 500
	if rawLimit := r.URL.Query().Get("limit"); rawLimit != "" {
		parsed, err := strconv.Atoi(rawLimit)
		if err == nil && parsed > 0 {
			limit = parsed
		}
	}
	if limit > 5000 {
		limit = 5000
	}

	s.mu.RLock()
	events := make([]Event, 0, len(s.events))
	for _, event := range s.events {
		if event.Sequence > afterSeq {
			events = append(events, event)
		}
	}
	if len(events) > limit {
		events = events[len(events)-limit:]
	}
	s.mu.RUnlock()

	writeJSON(w, http.StatusOK, map[string]any{"events": events})
}

func (s *Server) upsertAgent(w http.ResponseWriter, r *http.Request) {
	var agent Agent
	if err := json.NewDecoder(r.Body).Decode(&agent); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	if strings.TrimSpace(agent.ID) == "" {
		writeError(w, http.StatusBadRequest, "missing_agent_id")
		return
	}
	if agent.Ring == "" {
		agent.Ring = "dev"
	}
	if agent.Health == "" {
		agent.Health = "unknown"
	}
	agent.UpdatedAt = s.now().UTC()

	s.mu.Lock()
	if assignment, ok := s.configs[agent.Ring]; ok {
		agent.DesiredConfigHash = configHash(assignment.Config)
	}
	if previous, ok := s.agents[agent.ID]; ok {
		s.emitAgentDiffEventsLocked(previous, agent)
	} else {
		s.appendEventLocked(Event{Action: "agent.registered", AgentID: agent.ID, InstanceUID: agent.InstanceUID, Ring: agent.Ring, Hostname: agent.Hostname})
	}
	s.agents[agent.ID] = agent
	s.schedulePersistLocked()
	s.mu.Unlock()

	writeJSON(w, http.StatusCreated, agent)
}

func (s *Server) getAgent(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")

	s.mu.RLock()
	agent, ok := s.findAgentLocked(id)
	s.mu.RUnlock()
	if !ok {
		writeError(w, http.StatusNotFound, "agent_not_found")
		return
	}
	writeJSON(w, http.StatusOK, publicAgent(agent))
}

func (s *Server) findAgentLocked(id string) (Agent, bool) {
	_, agent, ok := s.findAgentWithKeyLocked(id)
	return agent, ok
}

func (s *Server) findAgentWithKeyLocked(id string) (string, Agent, bool) {
	if agent, ok := s.agents[id]; ok {
		return id, agent, true
	}
	for internalID, agent := range s.agents {
		if publicAgent(agent).ID == id {
			return internalID, agent, true
		}
	}
	return "", Agent{}, false
}

func publicAgent(agent Agent) Agent {
	if agent.Hostname != "" && looksLikeRawInstanceUID(agent.ID) {
		agent.ID = agent.Hostname
	}
	if agent.Health == "" {
		agent.Health = "unknown"
	}
	agent.LimitedMetadata = agent.Version == "" || agent.Hostname == "" || looksLikeRawInstanceUID(agent.ID)
	return agent
}

func (s *Server) stats(w http.ResponseWriter, _ *http.Request) {
	var mem runtime.MemStats
	runtime.ReadMemStats(&mem)

	s.mu.RLock()
	stats := Stats{
		Agents:          len(s.agents),
		Connections:     len(s.connections),
		HeapAllocBytes:  mem.HeapAlloc,
		HeapSysBytes:    mem.HeapSys,
		RuntimeSysBytes: mem.Sys,
		NumGoroutine:    runtime.NumGoroutine(),
		CollectedAt:     s.now().UTC(),
	}
	for _, agent := range s.agents {
		if agent.Connected {
			stats.ConnectedAgents++
		}
		if publicAgent(agent).LimitedMetadata {
			stats.LimitedMetadata++
		}
	}
	s.mu.RUnlock()

	writeJSON(w, http.StatusOK, stats)
}

func (s *Server) restartAgent(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")

	if err := s.setAgentRestart(id); err != nil {
		switch {
		case errors.Is(err, errAgentNotFound):
			writeError(w, http.StatusNotFound, err.Error())
		case errors.Is(err, errAgentNotConnected):
			writeError(w, http.StatusConflict, err.Error())
		case errors.Is(err, errUnsupportedCapability):
			writeError(w, http.StatusUnprocessableEntity, err.Error())
		default:
			writeError(w, http.StatusBadRequest, err.Error())
		}
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "pending", "command": "restart"})
}

func (s *Server) setAgentRestart(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	internalID, agent, ok := s.findAgentWithKeyLocked(id)
	if !ok {
		return errAgentNotFound
	}
	if !agent.Connected {
		return errAgentNotConnected
	}
	if !agentAcceptsRestart(agent) {
		return errUnsupportedCapability
	}
	agent.RestartPending = true
	agent.UpdatedAt = s.now().UTC()
	s.agents[internalID] = agent
	s.restartPending[internalID] = true
	s.appendEventLocked(Event{
		Action:      "agent.restart_requested",
		AgentID:     agent.ID,
		InstanceUID: agent.InstanceUID,
		Ring:        agent.Ring,
		Hostname:    agent.Hostname,
	})
	s.schedulePersistLocked()
	return nil
}

func (s *Server) assignConfig(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	var assignment ConfigAssignment
	if err := json.NewDecoder(r.Body).Decode(&assignment); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	if err := validateConfigAssignment(assignment); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	hash, err := s.setAgentConfig(id, assignment)
	if err != nil {
		switch {
		case errors.Is(err, errAgentNotFound):
			writeError(w, http.StatusNotFound, err.Error())
		case errors.Is(err, errRingMismatch):
			writeError(w, http.StatusConflict, err.Error())
		default:
			writeError(w, http.StatusBadRequest, err.Error())
		}
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"config_hash": hash, "status": "pending"})
}

func (s *Server) setAgentConfig(id string, assignment ConfigAssignment) (string, error) {
	if err := validateConfigAssignment(assignment); err != nil {
		return "", err
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	internalID, agent, ok := s.findAgentWithKeyLocked(id)
	if !ok {
		return "", errAgentNotFound
	}
	if agent.Ring != assignment.Ring {
		return "", errRingMismatch
	}
	hash := configHash(assignment.Config)
	previousHash := agent.DesiredConfigHash
	previousStatus := agent.RemoteConfigStatus
	agent.DesiredConfigHash = hash
	agent.RemoteConfigStatus = "pending"
	agent.UpdatedAt = s.now().UTC()
	s.agents[internalID] = agent
	s.configs[assignment.Ring] = assignment
	s.appendEventLocked(Event{
		Action:             "agent.config_assigned",
		AgentID:            agent.ID,
		InstanceUID:        agent.InstanceUID,
		Ring:               agent.Ring,
		Hostname:           agent.Hostname,
		PreviousConfigHash: previousHash,
		CurrentConfigHash:  hash,
		PreviousStatus:     previousStatus,
		CurrentStatus:      "pending",
	})
	s.schedulePersistLocked()

	return hash, nil
}

var (
	errAgentNotFound         = errors.New("agent_not_found")
	errAgentNotConnected     = errors.New("agent_not_connected")
	errRingMismatch          = errors.New("ring_mismatch")
	errUnsupportedCapability = errors.New("unsupported_capability")
)

func (s *Server) assignRingConfig(w http.ResponseWriter, r *http.Request) {
	ring := r.PathValue("ring")
	var assignment ConfigAssignment
	if err := json.NewDecoder(r.Body).Decode(&assignment); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	if assignment.Ring == "" {
		assignment.Ring = ring
	}
	if assignment.Ring != ring {
		writeError(w, http.StatusConflict, "ring_mismatch")
		return
	}
	if err := validateConfigAssignment(assignment); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	hash := configHash(assignment.Config)
	s.mu.Lock()
	s.configs[assignment.Ring] = assignment
	for id, agent := range s.agents {
		if agent.Ring == assignment.Ring {
			previousHash := agent.DesiredConfigHash
			previousStatus := agent.RemoteConfigStatus
			agent.DesiredConfigHash = hash
			agent.RemoteConfigStatus = "pending"
			agent.UpdatedAt = s.now().UTC()
			s.agents[id] = agent
			s.appendEventLocked(Event{
				Action:             "agent.config_assigned",
				AgentID:            agent.ID,
				InstanceUID:        agent.InstanceUID,
				Ring:               agent.Ring,
				Hostname:           agent.Hostname,
				PreviousConfigHash: previousHash,
				CurrentConfigHash:  hash,
				PreviousStatus:     previousStatus,
				CurrentStatus:      "pending",
				Reason:             "ring_assignment",
			})
		}
	}
	s.schedulePersistLocked()
	s.mu.Unlock()

	writeJSON(w, http.StatusOK, map[string]string{"config_hash": hash, "ring": assignment.Ring, "status": "pending"})
}

func (s *Server) reportEffectiveConfig(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	var body struct {
		Config string `json:"config"`
		Status string `json:"status"`
		Error  string `json:"error,omitempty"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	if body.Status == "" {
		body.Status = "applied"
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	agent, ok := s.agents[id]
	if !ok {
		writeError(w, http.StatusNotFound, "agent_not_found")
		return
	}
	previous := agent
	agent.EffectiveConfig = body.Config
	agent.RemoteConfigStatus = body.Status
	if body.Error != "" {
		agent.RemoteConfigStatus = "error: " + body.Error
	}
	agent.UpdatedAt = s.now().UTC()
	s.agents[id] = agent
	s.appendEventLocked(Event{
		Action:         "agent.effective_config_changed",
		AgentID:        agent.ID,
		InstanceUID:    agent.InstanceUID,
		Ring:           agent.Ring,
		Hostname:       agent.Hostname,
		PreviousStatus: previous.RemoteConfigStatus,
		CurrentStatus:  agent.RemoteConfigStatus,
	})
	s.schedulePersistLocked()

	writeJSON(w, http.StatusOK, agent)
}

func validateConfigAssignment(assignment ConfigAssignment) error {
	if assignment.Ring == "" {
		return errors.New("missing_ring")
	}
	if strings.TrimSpace(assignment.Config) == "" {
		return errors.New("missing_config")
	}
	if strings.Contains(assignment.Config, "INVALID") {
		return errors.New("invalid_config")
	}
	return nil
}

func configHash(config string) string {
	sum := sha256.Sum256([]byte(config))
	return hex.EncodeToString(sum[:])
}

func configHashBytes(config string) []byte {
	sum := sha256.Sum256([]byte(config))
	return sum[:]
}

func (s *Server) onOpAMPConnecting(_ *http.Request) opamptypes.ConnectionResponse {
	callbacks := opamptypes.ConnectionCallbacks{
		OnConnected: func(ctx context.Context, conn opamptypes.Connection) {
			s.mu.Lock()
			s.connections[conn] = ""
			s.mu.Unlock()
		},
		OnConnectionClose: func(conn opamptypes.Connection) {
			s.mu.Lock()
			instanceUID := s.connections[conn]
			delete(s.connections, conn)
			if agentID := s.agentsByInstance[instanceUID]; agentID != "" {
				agent := s.agents[agentID]
				agent.Connected = false
				agent.UpdatedAt = s.now().UTC()
				s.agents[agentID] = agent
				s.appendEventLocked(Event{
					Action:      "agent.disconnected",
					AgentID:     agent.ID,
					InstanceUID: agent.InstanceUID,
					Ring:        agent.Ring,
					Hostname:    agent.Hostname,
				})
				s.schedulePersistLocked()
			}
			s.mu.Unlock()
		},
		OnMessage: s.onOpAMPMessage,
	}
	return opamptypes.ConnectionResponse{Accept: true, ConnectionCallbacks: callbacks}
}

func (s *Server) onOpAMPMessage(ctx context.Context, conn opamptypes.Connection, msg *protobufs.AgentToServer) *protobufs.ServerToAgent {
	instanceUID := hex.EncodeToString(msg.GetInstanceUid())
	agent := s.agentFromOpAMPMessage(instanceUID, msg)

	var remoteConfig *protobufs.AgentRemoteConfig
	var command *protobufs.ServerToAgentCommand
	s.mu.Lock()
	s.connections[conn] = instanceUID
	previousAgentID := s.agentsByInstance[instanceUID]
	var previous Agent
	hadPrevious := false
	if previousAgentID != "" && (agent.ID == instanceUID || looksLikeRawInstanceUID(agent.ID)) {
		agent.ID = previousAgentID
	}
	if previousAgentID != "" && previousAgentID != agent.ID {
		if previous, ok := s.agents[previousAgentID]; ok {
			agent = mergeAgent(agent, previous)
			delete(s.agents, previousAgentID)
		}
		if s.restartPending[previousAgentID] {
			s.restartPending[agent.ID] = true
			delete(s.restartPending, previousAgentID)
		}
	}
	s.agentsByInstance[instanceUID] = agent.ID
	if existing, ok := s.agents[agent.ID]; ok {
		previous = existing
		hadPrevious = true
		agent = mergeAgent(agent, existing)
	}
	if assignment, ok := s.configs[agent.Ring]; ok {
		agent.DesiredConfigHash = configHash(assignment.Config)
		if msg.RemoteConfigStatus == nil || !sameHash(msg.RemoteConfigStatus.LastRemoteConfigHash, assignment.Config) {
			remoteConfig = remoteConfigForAssignment(assignment)
		}
	}
	if s.restartPending[agent.ID] && agentAcceptsRestart(agent) {
		command = &protobufs.ServerToAgentCommand{Type: protobufs.CommandType_CommandType_Restart}
		delete(s.restartPending, agent.ID)
		agent.RestartPending = false
		s.appendEventLocked(Event{
			Action:      "agent.restart_sent",
			AgentID:     agent.ID,
			InstanceUID: agent.InstanceUID,
			Ring:        agent.Ring,
			Hostname:    agent.Hostname,
		})
	}
	agent.Connected = true
	agent.UpdatedAt = s.now().UTC()
	if hadPrevious {
		s.emitAgentDiffEventsLocked(previous, agent)
	} else {
		s.emitAgentInitialEventsLocked(agent)
	}
	if remoteConfig != nil {
		s.appendEventLocked(Event{
			Action:            "agent.config_offered",
			AgentID:           agent.ID,
			InstanceUID:       agent.InstanceUID,
			Ring:              agent.Ring,
			Hostname:          agent.Hostname,
			CurrentConfigHash: agent.DesiredConfigHash,
			CurrentStatus:     agent.RemoteConfigStatus,
		})
	}
	s.agents[agent.ID] = agent
	s.schedulePersistLocked()
	s.mu.Unlock()

	return &protobufs.ServerToAgent{
		InstanceUid: msg.GetInstanceUid(),
		Capabilities: uint64(protobufs.ServerCapabilities_ServerCapabilities_AcceptsStatus |
			protobufs.ServerCapabilities_ServerCapabilities_OffersRemoteConfig |
			protobufs.ServerCapabilities_ServerCapabilities_AcceptsEffectiveConfig),
		RemoteConfig: remoteConfig,
		Command:      command,
	}
}

func agentAcceptsRestart(agent Agent) bool {
	return protobufs.AgentCapabilities(agent.Capabilities)&protobufs.AgentCapabilities_AgentCapabilities_AcceptsRestartCommand != 0
}

func mergeAgent(current Agent, previous Agent) Agent {
	if current.Ring == "" {
		current.Ring = previous.Ring
	}
	if current.Version == "" {
		current.Version = previous.Version
	}
	if current.Hostname == "" {
		current.Hostname = previous.Hostname
	}
	if current.Health == "" {
		current.Health = previous.Health
	}
	if current.EffectiveConfig == "" {
		current.EffectiveConfig = previous.EffectiveConfig
	}
	if current.RemoteConfigStatus == "" {
		current.RemoteConfigStatus = previous.RemoteConfigStatus
	}
	if current.DesiredConfigHash == "" {
		current.DesiredConfigHash = previous.DesiredConfigHash
	}
	if current.Capabilities == 0 {
		current.Capabilities = previous.Capabilities
	}
	if !current.RestartPending && previous.RestartPending {
		current.RestartPending = previous.RestartPending
	}
	return current
}

func (s *Server) agentFromOpAMPMessage(instanceUID string, msg *protobufs.AgentToServer) Agent {
	attrs := map[string]string{}
	if msg.AgentDescription != nil {
		for _, kv := range msg.AgentDescription.IdentifyingAttributes {
			attrs[kv.Key] = anyValueString(kv.Value)
		}
		for _, kv := range msg.AgentDescription.NonIdentifyingAttributes {
			attrs[kv.Key] = anyValueString(kv.Value)
		}
	}
	agentID := attrs["service.instance.id"]
	if agentID == "" && attrs["host.name"] != "" && attrs["service.name"] != "" {
		agentID = attrs["host.name"] + ":" + attrs["service.name"]
	}
	if agentID == "" && attrs["host.name"] != "" {
		agentID = attrs["host.name"]
	}
	if agentID == "" {
		agentID = instanceUID
	}
	health := ""
	if msg.Health != nil {
		if msg.Health.Healthy {
			health = "healthy"
		} else {
			health = "unhealthy"
		}
		if msg.Health.Status != "" {
			health = msg.Health.Status
		}
		if msg.Health.LastError != "" {
			health = health + ": " + msg.Health.LastError
		}
	}
	remoteConfigStatus := ""
	if msg.RemoteConfigStatus != nil {
		remoteConfigStatus = msg.RemoteConfigStatus.Status.String()
		if msg.RemoteConfigStatus.ErrorMessage != "" {
			remoteConfigStatus += ": " + msg.RemoteConfigStatus.ErrorMessage
		}
	}
	effectiveConfig := ""
	if msg.EffectiveConfig != nil && msg.EffectiveConfig.ConfigMap != nil {
		effectiveConfig = configMapSummary(msg.EffectiveConfig.ConfigMap)
	}
	ring := attrs["deployment.ring"]
	if ring == "" {
		ring = attrs["service.namespace"]
	}
	if ring == "" {
		ring = "dev"
	}
	agent := Agent{
		ID:                 agentID,
		InstanceUID:        instanceUID,
		Ring:               ring,
		Version:            attrs["service.version"],
		Hostname:           attrs["host.name"],
		Health:             health,
		Capabilities:       msg.Capabilities,
		EffectiveConfig:    effectiveConfig,
		RemoteConfigStatus: remoteConfigStatus,
	}
	if agent.Hostname != "" && (agent.ID == instanceUID || looksLikeRawInstanceUID(agent.ID)) {
		if attrs["service.name"] != "" {
			agent.ID = agent.Hostname + ":" + attrs["service.name"]
		} else {
			agent.ID = agent.Hostname
		}
	}
	return agent
}

func looksLikeRawInstanceUID(value string) bool {
	if len(value) != 32 {
		return false
	}
	for _, r := range value {
		if (r < '0' || r > '9') && (r < 'a' || r > 'f') && (r < 'A' || r > 'F') {
			return false
		}
	}
	return true
}

func remoteConfigForAssignment(assignment ConfigAssignment) *protobufs.AgentRemoteConfig {
	return &protobufs.AgentRemoteConfig{
		ConfigHash: configHashBytes(assignment.Config),
		Config: &protobufs.AgentConfigMap{ConfigMap: map[string]*protobufs.AgentConfigFile{
			"collector.yaml": {
				Body:        []byte(assignment.Config),
				ContentType: "text/yaml",
			},
		}},
	}
}

func sameHash(hash []byte, config string) bool {
	return hex.EncodeToString(hash) == configHash(config)
}

func (s *Server) appendEventLocked(event Event) {
	event.Sequence = s.nextEventSeq
	s.nextEventSeq++
	event.Timestamp = s.now().UTC()
	s.events = append(s.events, event)
	const maxEvents = 10000
	if len(s.events) > maxEvents {
		s.events = append([]Event(nil), s.events[len(s.events)-maxEvents:]...)
	}
}

func (s *Server) emitAgentDiffEventsLocked(previous Agent, current Agent) {
	if !previous.Connected && current.Connected {
		action := "agent.connected"
		if previous.UpdatedAt.IsZero() {
			action = "agent.connected"
		}
		s.appendEventLocked(Event{
			Action:      action,
			AgentID:     current.ID,
			InstanceUID: current.InstanceUID,
			Ring:        current.Ring,
			Hostname:    current.Hostname,
		})
	}
	if previous.InstanceUID != "" && current.InstanceUID != "" && previous.InstanceUID != current.InstanceUID {
		s.appendEventLocked(Event{
			Action:      "agent.reconnected",
			AgentID:     current.ID,
			InstanceUID: current.InstanceUID,
			Ring:        current.Ring,
			Hostname:    current.Hostname,
			Reason:      "instance_uid_changed",
		})
	}
	if previous.Version != "" && current.Version != "" && previous.Version != current.Version {
		s.appendEventLocked(Event{
			Action:          "agent.version_changed",
			AgentID:         current.ID,
			InstanceUID:     current.InstanceUID,
			Ring:            current.Ring,
			Hostname:        current.Hostname,
			PreviousVersion: previous.Version,
			CurrentVersion:  current.Version,
			Direction:       versionDirection(previous.Version, current.Version),
		})
	}
	if previous.Health != current.Health && current.Health != "" {
		s.appendEventLocked(Event{
			Action:         "agent.health_changed",
			AgentID:        current.ID,
			InstanceUID:    current.InstanceUID,
			Ring:           current.Ring,
			Hostname:       current.Hostname,
			PreviousHealth: previous.Health,
			CurrentHealth:  current.Health,
		})
	}
	if previous.RemoteConfigStatus != current.RemoteConfigStatus && current.RemoteConfigStatus != "" {
		s.appendEventLocked(Event{
			Action:         "agent.config_status_changed",
			AgentID:        current.ID,
			InstanceUID:    current.InstanceUID,
			Ring:           current.Ring,
			Hostname:       current.Hostname,
			PreviousStatus: previous.RemoteConfigStatus,
			CurrentStatus:  current.RemoteConfigStatus,
		})
	}
	if previous.EffectiveConfig != current.EffectiveConfig && current.EffectiveConfig != "" {
		s.appendEventLocked(Event{
			Action:      "agent.effective_config_changed",
			AgentID:     current.ID,
			InstanceUID: current.InstanceUID,
			Ring:        current.Ring,
			Hostname:    current.Hostname,
		})
	}
}

func (s *Server) emitAgentInitialEventsLocked(agent Agent) {
	s.appendEventLocked(Event{
		Action:      "agent.connected",
		AgentID:     agent.ID,
		InstanceUID: agent.InstanceUID,
		Ring:        agent.Ring,
		Hostname:    agent.Hostname,
	})
	if agent.Health != "" {
		s.appendEventLocked(Event{
			Action:        "agent.health_changed",
			AgentID:       agent.ID,
			InstanceUID:   agent.InstanceUID,
			Ring:          agent.Ring,
			Hostname:      agent.Hostname,
			CurrentHealth: agent.Health,
		})
	}
	if agent.RemoteConfigStatus != "" {
		s.appendEventLocked(Event{
			Action:        "agent.config_status_changed",
			AgentID:       agent.ID,
			InstanceUID:   agent.InstanceUID,
			Ring:          agent.Ring,
			Hostname:      agent.Hostname,
			CurrentStatus: agent.RemoteConfigStatus,
		})
	}
}

func versionDirection(previous string, current string) string {
	prevParts, prevOK := parseVersion(previous)
	currParts, currOK := parseVersion(current)
	if !prevOK || !currOK {
		return "changed"
	}
	for i := 0; i < len(prevParts) || i < len(currParts); i++ {
		prev := 0
		if i < len(prevParts) {
			prev = prevParts[i]
		}
		curr := 0
		if i < len(currParts) {
			curr = currParts[i]
		}
		if curr > prev {
			return "upgrade"
		}
		if curr < prev {
			return "downgrade"
		}
	}
	return "changed"
}

func parseVersion(version string) ([]int, bool) {
	version = strings.TrimPrefix(strings.TrimSpace(version), "v")
	if version == "" {
		return nil, false
	}
	parts := strings.Split(version, ".")
	values := make([]int, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		digits := strings.Builder{}
		for _, r := range part {
			if r < '0' || r > '9' {
				break
			}
			digits.WriteRune(r)
		}
		if digits.Len() == 0 {
			return nil, false
		}
		value, err := strconv.Atoi(digits.String())
		if err != nil {
			return nil, false
		}
		values = append(values, value)
	}
	return values, true
}

func configMapSummary(configMap *protobufs.AgentConfigMap) string {
	names := make([]string, 0, len(configMap.ConfigMap))
	for name := range configMap.ConfigMap {
		names = append(names, name)
	}
	sort.Strings(names)
	return strings.Join(names, ",")
}

func anyValueString(value *protobufs.AnyValue) string {
	if value == nil {
		return ""
	}
	switch v := value.Value.(type) {
	case *protobufs.AnyValue_StringValue:
		return v.StringValue
	case *protobufs.AnyValue_IntValue:
		return fmt.Sprintf("%d", v.IntValue)
	case *protobufs.AnyValue_DoubleValue:
		return fmt.Sprintf("%f", v.DoubleValue)
	case *protobufs.AnyValue_BoolValue:
		return fmt.Sprintf("%t", v.BoolValue)
	case *protobufs.AnyValue_BytesValue:
		return hex.EncodeToString(v.BytesValue)
	default:
		return ""
	}
}

type logAdapter struct{}

func (logAdapter) Debugf(ctx context.Context, format string, v ...interface{}) {}

func (logAdapter) Errorf(ctx context.Context, format string, v ...interface{}) {}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, status int, code string) {
	writeJSON(w, status, map[string]string{"error": code})
}

func writeHTML(w http.ResponseWriter, status int, tpl *template.Template, payload any) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	_ = tpl.Execute(w, payload)
}

var uiRootTemplate = template.Must(template.New("root").Parse(`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>OpAMP Server</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 24px; color: #17202a; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #c8d1dc; padding: 8px; text-align: left; vertical-align: top; }
    th { background: #eef3f8; }
    code { background: #f4f6f8; padding: 2px 4px; }
    .muted { color: #5f6b7a; }
  </style>
</head>
<body>
  <h1>OpAMP Server</h1>
  <p class="muted">Vanilla OpAMP POC control-plane UI. JSON endpoints: <a href="/v1/inventory">inventory</a> and <a href="/v1/opamp/connections">connections</a>.</p>
  <p class="muted">Agents marked limited are connected but did not report enough metadata for full version/hostname/config visibility.</p>
  <h2>Agents</h2>
  <table>
    <tr>
      <th>ID</th>
      <th>Ring</th>
      <th>Hostname</th>
      <th>Version</th>
      <th>Health</th>
      <th>Connected</th>
      <th>Remote config</th>
      <th>Metadata</th>
      <th>Updated</th>
    </tr>
    {{range .Agents}}
    <tr>
      <td><a href="/agent?id={{.ID}}">{{.ID}}</a></td>
      <td>{{.Ring}}</td>
      <td>{{.Hostname}}</td>
      <td>{{.Version}}</td>
      <td>{{.Health}}</td>
      <td>{{.Connected}}</td>
      <td>{{.RemoteConfigStatus}}</td>
      <td>{{if .LimitedMetadata}}limited{{else}}complete{{end}}</td>
      <td>{{.UpdatedAt}}</td>
    </tr>
    {{else}}
    <tr><td colspan="9">No agents connected yet.</td></tr>
    {{end}}
  </table>
</body>
</html>`))

var uiAgentTemplate = template.Must(template.New("agent").Parse(`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>OpAMP Agent {{.Agent.ID}}</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 24px; color: #17202a; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 18px; }
    th, td { border: 1px solid #c8d1dc; padding: 8px; text-align: left; vertical-align: top; }
    th { background: #eef3f8; width: 220px; }
    textarea { width: 100%; max-width: 920px; min-height: 280px; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
    pre { background: #f4f6f8; border: 1px solid #d7dee8; padding: 12px; overflow: auto; }
    input[type="submit"] { padding: 8px 12px; }
    .muted { color: #5f6b7a; }
  </style>
</head>
<body>
  <h1>Agent {{.Agent.ID}}</h1>
  <p><a href="/">Back to Agents</a> · <a href="/v1/agents/{{.Agent.ID}}">JSON</a></p>

  <h2>Status</h2>
  <table>
    <tr><th>ID</th><td>{{.Agent.ID}}</td></tr>
    <tr><th>Instance UID</th><td>{{.Agent.InstanceUID}}</td></tr>
    <tr><th>Ring</th><td>{{.Agent.Ring}}</td></tr>
    <tr><th>Version</th><td>{{.Agent.Version}}</td></tr>
    <tr><th>Hostname</th><td>{{.Agent.Hostname}}</td></tr>
    <tr><th>Health</th><td>{{.Agent.Health}}</td></tr>
    <tr><th>Connected</th><td>{{.Agent.Connected}}</td></tr>
    <tr><th>Capabilities</th><td>{{.Agent.Capabilities}}</td></tr>
    <tr><th>Desired config hash</th><td>{{.Agent.DesiredConfigHash}}</td></tr>
    <tr><th>Remote config status</th><td>{{.Agent.RemoteConfigStatus}}</td></tr>
    <tr><th>Restart command pending</th><td>{{.Agent.RestartPending}}</td></tr>
    <tr><th>Metadata</th><td>{{if .Agent.LimitedMetadata}}limited{{else}}complete{{end}}</td></tr>
    <tr><th>Updated at</th><td>{{.Agent.UpdatedAt}}</td></tr>
  </table>

  <h2>Restart</h2>
  <form action="/agent/{{.Agent.ID}}/restart" method="post">
    <input type="submit" value="Send Restart Command">
  </form>

  <h2>Current Effective Configuration</h2>
  <pre>{{if .Agent.EffectiveConfig}}{{.Agent.EffectiveConfig}}{{else}}not reported by agent yet{{end}}</pre>

  <h2>Additional Configuration</h2>
  <form action="/agent/{{.Agent.ID}}/config" method="post">
    <input type="hidden" name="ring" value="{{.Agent.Ring}}">
    <textarea name="config" spellcheck="false">receivers:
  filelog:
</textarea><br>
    <input type="submit" value="Save and Send to Agent">
  </form>

  <p class="muted">Upstream opamp-go example also demonstrates client certificate rotation, connection settings offers, and custom messages. Those controls are not implemented in this vanilla POC UI.</p>
</body>
</html>`))

var uiErrorTemplate = template.Must(template.New("error").Parse(`<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>OpAMP Server Error</title></head>
<body>
  <h1>OpAMP Server Error</h1>
  <p>{{.Error}}</p>
  <p><a href="/">Back to Agents</a></p>
</body>
</html>`))
