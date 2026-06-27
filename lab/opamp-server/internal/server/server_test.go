package server

import (
	"bytes"
	"context"
	"encoding/hex"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/open-telemetry/opamp-go/protobufs"
)

func TestInventoryAndRemoteConfigLifecycle(t *testing.T) {
	srv := New()
	fixed := time.Date(2026, 6, 18, 10, 0, 0, 0, time.UTC)
	srv.now = func() time.Time { return fixed }
	router := srv.Router()

	sendJSON(t, router, http.MethodPost, "/v1/agents", map[string]any{
		"id":       "agent-001",
		"ring":     "canary",
		"version":  "0.1.0",
		"hostname": "lab-host-01",
		"health":   "healthy",
	}, http.StatusCreated)

	configResp := sendJSON(t, router, http.MethodPut, "/v1/agents/agent-001/config", map[string]any{
		"ring":   "canary",
		"config": "receivers:\n  filelog:\n",
	}, http.StatusOK)
	if configResp["config_hash"] == "" {
		t.Fatal("expected config hash")
	}

	sendJSON(t, router, http.MethodPost, "/v1/agents/agent-001/effective-config", map[string]any{
		"config": "receivers:\n  filelog:\n",
		"status": "applied",
	}, http.StatusOK)

	req := httptest.NewRequest(http.MethodGet, "/v1/inventory", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("inventory status = %d", rec.Code)
	}

	var inventory struct {
		Agents []Agent `json:"agents"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &inventory); err != nil {
		t.Fatal(err)
	}
	if len(inventory.Agents) != 1 {
		t.Fatalf("agents len = %d", len(inventory.Agents))
	}
	if inventory.Agents[0].RemoteConfigStatus != "applied" {
		t.Fatalf("status = %q", inventory.Agents[0].RemoteConfigStatus)
	}
}

func TestInvalidConfigIsRejected(t *testing.T) {
	srv := New()
	router := srv.Router()

	sendJSON(t, router, http.MethodPost, "/v1/agents", map[string]any{
		"id":   "agent-001",
		"ring": "canary",
	}, http.StatusCreated)

	sendJSON(t, router, http.MethodPut, "/v1/agents/agent-001/config", map[string]any{
		"ring":   "canary",
		"config": "INVALID",
	}, http.StatusBadRequest)
}

func TestRolloutRingsRejectMismatchedAssignment(t *testing.T) {
	srv := New()
	router := srv.Router()

	sendJSON(t, router, http.MethodPost, "/v1/agents", map[string]any{
		"id":   "agent-001",
		"ring": "dev",
	}, http.StatusCreated)

	sendJSON(t, router, http.MethodPut, "/v1/agents/agent-001/config", map[string]any{
		"ring":   "prod",
		"config": "receivers:\n  filelog:\n",
	}, http.StatusConflict)
}

func TestOpAMPClientRegistersInventory(t *testing.T) {
	srv := New()
	msg := testAgentMessage("agent-opamp-001", "canary")
	msg.Health = &protobufs.ComponentHealth{Healthy: true, Status: "healthy"}

	response := srv.onOpAMPMessage(context.Background(), fakeConnection{}, msg)
	if response == nil {
		t.Fatal("expected OpAMP response")
	}
	agent := getAgentFromRouter(t, srv.Router(), "agent-opamp-001")
	if !agent.Connected {
		t.Fatal("expected connected agent")
	}
	if agent.Health != "healthy" {
		t.Fatalf("health = %q", agent.Health)
	}
	if agent.InstanceUID == "" {
		t.Fatal("expected instance uid")
	}
}

func TestOpAMPRemoteConfigOfferAndStatus(t *testing.T) {
	srv := New()
	router := srv.Router()

	configResp := sendJSON(t, router, http.MethodPut, "/v1/rings/canary/config", map[string]any{
		"config": "receivers:\n  filelog:\n",
	}, http.StatusOK)
	wantHash, _ := configResp["config_hash"].(string)

	firstMsg := testAgentMessage("agent-opamp-002", "canary")
	firstResponse := srv.onOpAMPMessage(context.Background(), fakeConnection{}, firstMsg)
	if firstResponse.RemoteConfig == nil {
		t.Fatal("expected remote config offer")
	}
	if got := hexHash(firstResponse.RemoteConfig.ConfigHash); got != wantHash {
		t.Fatalf("remote config hash = %q, want %q", got, wantHash)
	}

	statusMsg := testAgentMessage("agent-opamp-002", "canary")
	statusMsg.RemoteConfigStatus = &protobufs.RemoteConfigStatus{
		LastRemoteConfigHash: firstResponse.RemoteConfig.ConfigHash,
		Status:               protobufs.RemoteConfigStatuses_RemoteConfigStatuses_APPLIED,
	}
	secondResponse := srv.onOpAMPMessage(context.Background(), fakeConnection{}, statusMsg)
	if secondResponse.RemoteConfig != nil {
		t.Fatal("did not expect remote config after applied status")
	}
	agent := getAgentFromRouter(t, router, "agent-opamp-002")
	if agent.DesiredConfigHash != wantHash {
		t.Fatalf("desired hash = %q, want %q", agent.DesiredConfigHash, wantHash)
	}
	if agent.RemoteConfigStatus != protobufs.RemoteConfigStatuses_RemoteConfigStatuses_APPLIED.String() {
		t.Fatalf("remote config status = %q", agent.RemoteConfigStatus)
	}
}

func TestRestartCommandLifecycle(t *testing.T) {
	srv := New()
	router := srv.Router()
	msg := testAgentMessage("agent-opamp-restart", "canary")
	msg.Capabilities |= uint64(protobufs.AgentCapabilities_AgentCapabilities_AcceptsRestartCommand)
	srv.onOpAMPMessage(context.Background(), fakeConnection{}, msg)

	resp := sendJSON(t, router, http.MethodPost, "/v1/agents/agent-opamp-restart/restart", nil, http.StatusOK)
	if resp["status"] != "pending" || resp["command"] != "restart" {
		t.Fatalf("restart response = %+v", resp)
	}
	agent := getAgentFromRouter(t, router, "agent-opamp-restart")
	if !agent.RestartPending {
		t.Fatal("expected restart pending after API request")
	}

	response := srv.onOpAMPMessage(context.Background(), fakeConnection{}, msg)
	if response.Command == nil || response.Command.Type != protobufs.CommandType_CommandType_Restart {
		t.Fatalf("expected restart command, got %+v", response.Command)
	}
	agent = getAgentFromRouter(t, router, "agent-opamp-restart")
	if agent.RestartPending {
		t.Fatal("expected restart pending to clear after command is sent")
	}

	response = srv.onOpAMPMessage(context.Background(), fakeConnection{}, msg)
	if response.Command != nil {
		t.Fatalf("expected restart command to be one-shot, got %+v", response.Command)
	}
}

func TestRestartCommandRequiresCapability(t *testing.T) {
	srv := New()
	router := srv.Router()
	msg := testAgentMessage("agent-no-restart", "canary")
	srv.onOpAMPMessage(context.Background(), fakeConnection{}, msg)

	sendJSON(t, router, http.MethodPost, "/v1/agents/agent-no-restart/restart", nil, http.StatusUnprocessableEntity)
}

func TestRestartCommandRequiresConnectedAgent(t *testing.T) {
	srv := New()
	router := srv.Router()
	sendJSON(t, router, http.MethodPost, "/v1/agents", map[string]any{
		"id":           "agent-disconnected",
		"ring":         "canary",
		"capabilities": uint64(protobufs.AgentCapabilities_AgentCapabilities_AcceptsRestartCommand),
	}, http.StatusCreated)

	sendJSON(t, router, http.MethodPost, "/v1/agents/agent-disconnected/restart", nil, http.StatusConflict)
}

func TestOpAMPConnectionCloseMarksAgentDisconnected(t *testing.T) {
	srv := New()
	conn := fakeConnection{}
	msg := testAgentMessage("agent-opamp-003", "canary")
	srv.onOpAMPMessage(context.Background(), conn, msg)

	callbacks := srv.onOpAMPConnecting(httptest.NewRequest(http.MethodGet, "/v1/opamp", nil)).ConnectionCallbacks
	callbacks.OnConnectionClose(conn)

	agent := getAgentFromRouter(t, srv.Router(), "agent-opamp-003")
	if agent.Connected {
		t.Fatal("expected disconnected agent")
	}
}

func TestEventsEndpointTracksAgentLifecycle(t *testing.T) {
	srv := New()
	router := srv.Router()
	conn := fakeConnection{}
	msg := testAgentMessage("agent-events", "canary")
	msg.Health = &protobufs.ComponentHealth{Healthy: true, Status: "StatusOK"}

	srv.onOpAMPMessage(context.Background(), conn, msg)
	callbacks := srv.onOpAMPConnecting(httptest.NewRequest(http.MethodGet, "/v1/opamp", nil)).ConnectionCallbacks
	callbacks.OnConnectionClose(conn)

	events := getEventsFromRouter(t, router, "")
	actions := eventActions(events)
	for _, want := range []string{"agent.connected", "agent.health_changed", "agent.disconnected"} {
		if !containsString(actions, want) {
			t.Fatalf("events missing %q: %+v", want, events)
		}
	}

	afterFirst := getEventsFromRouter(t, router, "?after_seq=1")
	for _, event := range afterFirst {
		if event.Sequence <= 1 {
			t.Fatalf("after_seq returned old event: %+v", event)
		}
	}
}

func TestEventsEndpointTracksVersionAndConfigChanges(t *testing.T) {
	srv := New()
	router := srv.Router()
	msg := testAgentMessage("agent-version", "canary")
	srv.onOpAMPMessage(context.Background(), fakeConnection{}, msg)

	upgraded := testAgentMessage("agent-version", "canary")
	upgraded.AgentDescription = testAgentDescriptionWithVersion("agent-version", "canary", "0.152.0")
	srv.onOpAMPMessage(context.Background(), fakeConnection{}, upgraded)

	downgraded := testAgentMessage("agent-version", "canary")
	downgraded.AgentDescription = testAgentDescriptionWithVersion("agent-version", "canary", "0.150.0")
	srv.onOpAMPMessage(context.Background(), fakeConnection{}, downgraded)

	configResp := sendJSON(t, router, http.MethodPut, "/v1/agents/agent-version/config", map[string]any{
		"ring":   "canary",
		"config": "receivers:\n  filelog:\n",
	}, http.StatusOK)
	wantHash, _ := configResp["config_hash"].(string)

	statusMsg := testAgentMessage("agent-version", "canary")
	statusMsg.AgentDescription = testAgentDescriptionWithVersion("agent-version", "canary", "0.150.0")
	statusMsg.RemoteConfigStatus = &protobufs.RemoteConfigStatus{
		LastRemoteConfigHash: configHashBytes("receivers:\n  filelog:\n"),
		Status:               protobufs.RemoteConfigStatuses_RemoteConfigStatuses_APPLIED,
	}
	srv.onOpAMPMessage(context.Background(), fakeConnection{}, statusMsg)

	events := getEventsFromRouter(t, router, "")
	var sawUpgrade, sawDowngrade, sawAssigned, sawApplied bool
	for _, event := range events {
		switch event.Action {
		case "agent.version_changed":
			if event.PreviousVersion == "0.151.0" && event.CurrentVersion == "0.152.0" && event.Direction == "upgrade" {
				sawUpgrade = true
			}
			if event.PreviousVersion == "0.152.0" && event.CurrentVersion == "0.150.0" && event.Direction == "downgrade" {
				sawDowngrade = true
			}
		case "agent.config_assigned":
			if event.CurrentConfigHash == wantHash {
				sawAssigned = true
			}
		case "agent.config_status_changed":
			if event.CurrentStatus == protobufs.RemoteConfigStatuses_RemoteConfigStatuses_APPLIED.String() {
				sawApplied = true
			}
		}
	}
	if !sawUpgrade || !sawDowngrade || !sawAssigned || !sawApplied {
		t.Fatalf("missing expected events: upgrade=%v downgrade=%v assigned=%v applied=%v events=%+v", sawUpgrade, sawDowngrade, sawAssigned, sawApplied, events)
	}
}

func TestOpAMPMessageMergesAgentWhenDescriptionArrivesAfterInstanceUID(t *testing.T) {
	srv := New()
	router := srv.Router()
	conn := fakeConnection{}
	instanceUID := []byte("1234567890abcdef")

	firstMsg := &protobufs.AgentToServer{
		InstanceUid: instanceUID,
		SequenceNum: 1,
		Capabilities: uint64(protobufs.AgentCapabilities_AgentCapabilities_ReportsHealth |
			protobufs.AgentCapabilities_AgentCapabilities_ReportsEffectiveConfig),
		Health: &protobufs.ComponentHealth{Healthy: true, Status: "StatusStarting"},
	}
	srv.onOpAMPMessage(context.Background(), conn, firstMsg)

	rawID := hex.EncodeToString(instanceUID)
	rawAgent := getAgentFromRouter(t, router, rawID)
	if rawAgent.ID == "" {
		t.Fatal("expected raw instance uid agent before description")
	}

	secondMsg := &protobufs.AgentToServer{
		InstanceUid:      instanceUID,
		SequenceNum:      2,
		Capabilities:     firstMsg.Capabilities,
		AgentDescription: testAgentDescription("stable-agent-id", "k8s"),
		Health:           &protobufs.ComponentHealth{Healthy: true, Status: "StatusOK"},
	}
	srv.onOpAMPMessage(context.Background(), conn, secondMsg)

	if stale := getAgentFromRouter(t, router, rawID); stale.ID != "" {
		t.Fatalf("expected raw instance uid agent to be merged away, got %+v", stale)
	}
	agent := getAgentFromRouter(t, router, "stable-agent-id")
	if agent.ID != "stable-agent-id" {
		t.Fatalf("agent id = %q", agent.ID)
	}
	if agent.InstanceUID != rawID {
		t.Fatalf("instance uid = %q, want %q", agent.InstanceUID, rawID)
	}
	if agent.Version != "0.151.0" || agent.Hostname == "" || agent.Health != "StatusOK" {
		t.Fatalf("agent fields not merged from description/status: %+v", agent)
	}
}

func TestOpAMPMessageUsesReadableAgentIDFallback(t *testing.T) {
	srv := New()
	instanceUID := []byte("abcdef1234567890")
	msg := &protobufs.AgentToServer{
		InstanceUid:  instanceUID,
		SequenceNum:  1,
		Capabilities: uint64(protobufs.AgentCapabilities_AgentCapabilities_ReportsHealth),
		AgentDescription: &protobufs.AgentDescription{
			NonIdentifyingAttributes: []*protobufs.KeyValue{
				stringKV("service.name", "opamp-poc-k8s-logs"),
				stringKV("service.version", "0.151.0"),
				stringKV("host.name", "opamp-poc-k3s-server"),
				stringKV("deployment.ring", "k8s"),
			},
		},
		Health: &protobufs.ComponentHealth{Healthy: true, Status: "StatusOK"},
	}
	srv.onOpAMPMessage(context.Background(), fakeConnection{}, msg)

	agent := getAgentFromRouter(t, srv.Router(), "opamp-poc-k3s-server:opamp-poc-k8s-logs")
	if agent.ID != "opamp-poc-k3s-server:opamp-poc-k8s-logs" {
		t.Fatalf("agent id = %q", agent.ID)
	}
	if agent.InstanceUID != hex.EncodeToString(instanceUID) {
		t.Fatalf("instance uid = %q", agent.InstanceUID)
	}
	if agent.Version != "0.151.0" || agent.Hostname != "opamp-poc-k3s-server" || agent.Ring != "k8s" {
		t.Fatalf("agent fields = %+v", agent)
	}
}

func TestOpAMPMessageReplacesRawHexAgentIDWhenHostnameExists(t *testing.T) {
	srv := New()
	rawID := "cea221e2aa0e4e4196f0c234ec515492"
	instanceUID, err := hex.DecodeString(rawID)
	if err != nil {
		t.Fatal(err)
	}
	msg := &protobufs.AgentToServer{
		InstanceUid:  instanceUID,
		SequenceNum:  1,
		Capabilities: uint64(protobufs.AgentCapabilities_AgentCapabilities_ReportsHealth),
		AgentDescription: &protobufs.AgentDescription{
			IdentifyingAttributes: []*protobufs.KeyValue{
				stringKV("service.instance.id", rawID),
			},
			NonIdentifyingAttributes: []*protobufs.KeyValue{
				stringKV("service.version", "0.151.0"),
				stringKV("host.name", "opamp-poc-host-agent"),
			},
		},
		Health: &protobufs.ComponentHealth{Healthy: true, Status: "StatusOK"},
	}
	srv.onOpAMPMessage(context.Background(), fakeConnection{}, msg)

	if stale := getAgentFromRouter(t, srv.Router(), rawID); stale.ID != "" {
		t.Fatalf("expected raw hex id to be replaced, got %+v", stale)
	}
	agent := getAgentFromRouter(t, srv.Router(), "opamp-poc-host-agent")
	if agent.ID != "opamp-poc-host-agent" {
		t.Fatalf("agent id = %q", agent.ID)
	}
	if agent.InstanceUID != rawID || agent.Version != "0.151.0" || agent.Health != "StatusOK" {
		t.Fatalf("agent fields = %+v", agent)
	}
}

func TestOpAMPMessageWithoutDescriptionKeepsReadableIdentity(t *testing.T) {
	srv := New()
	router := srv.Router()
	conn := fakeConnection{}
	instanceUID := []byte("stable-agent-uid")

	firstMsg := testAgentMessage("stable-agent", "canary")
	firstMsg.InstanceUid = instanceUID
	firstMsg.Health = &protobufs.ComponentHealth{Healthy: true, Status: "StatusOK"}
	firstMsg.EffectiveConfig = &protobufs.EffectiveConfig{
		ConfigMap: &protobufs.AgentConfigMap{ConfigMap: map[string]*protobufs.AgentConfigFile{
			"collector.yaml": {Body: []byte("receivers:\n  filelog:\n")},
		}},
	}
	srv.onOpAMPMessage(context.Background(), conn, firstMsg)

	partialMsg := &protobufs.AgentToServer{
		InstanceUid:  instanceUID,
		SequenceNum:  2,
		Capabilities: firstMsg.Capabilities,
		Health:       &protobufs.ComponentHealth{Healthy: true, Status: "StatusOK"},
	}
	srv.onOpAMPMessage(context.Background(), conn, partialMsg)

	rawID := hex.EncodeToString(instanceUID)
	if stale := getAgentFromRouter(t, router, rawID); stale.ID != "" {
		t.Fatalf("expected no raw uid duplicate after partial message, got %+v", stale)
	}
	agent := getAgentFromRouter(t, router, "stable-agent")
	if agent.ID != "stable-agent" {
		t.Fatalf("agent id = %q", agent.ID)
	}
	if agent.Version != "0.151.0" || agent.Hostname != "stable-agent.example.invalid" || agent.Health != "StatusOK" {
		t.Fatalf("agent metadata regressed after partial message: %+v", agent)
	}
	if agent.EffectiveConfig != "collector.yaml" {
		t.Fatalf("effective config = %q", agent.EffectiveConfig)
	}
	if agent.LimitedMetadata {
		t.Fatalf("expected complete metadata, got %+v", agent)
	}
}

func TestStatsEndpointCountsAgentsAndConnections(t *testing.T) {
	srv := New()
	conn := fakeConnection{}
	srv.onOpAMPMessage(context.Background(), conn, testAgentMessage("agent-stats", "canary"))

	rec := request(t, srv.Router(), http.MethodGet, "/v1/stats", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("stats status = %d, body %s", rec.Code, rec.Body.String())
	}
	var stats Stats
	if err := json.Unmarshal(rec.Body.Bytes(), &stats); err != nil {
		t.Fatal(err)
	}
	if stats.Agents != 1 || stats.ConnectedAgents != 1 || stats.Connections != 1 {
		t.Fatalf("stats = %+v", stats)
	}
	if stats.NumGoroutine == 0 || stats.CollectedAt.IsZero() {
		t.Fatalf("runtime stats missing: %+v", stats)
	}
}

func TestPersistentStateRestoresMetadataAfterServerRestart(t *testing.T) {
	t.Setenv("OPAMP_DATA_DIR", t.TempDir())
	first := New()
	instanceUID := []byte("persist-agent-uid")
	msg := testAgentMessage("persist-agent", "canary")
	msg.InstanceUid = instanceUID
	msg.Health = &protobufs.ComponentHealth{Healthy: true, Status: "StatusOK"}
	first.onOpAMPMessage(context.Background(), fakeConnection{}, msg)
	if err := first.persistState(); err != nil {
		t.Fatal(err)
	}

	second := New()
	partialMsg := &protobufs.AgentToServer{
		InstanceUid:  instanceUID,
		SequenceNum:  2,
		Capabilities: msg.Capabilities,
		Health:       &protobufs.ComponentHealth{Healthy: true, Status: "StatusOK"},
	}
	second.onOpAMPMessage(context.Background(), fakeConnection{}, partialMsg)

	rawID := hex.EncodeToString(instanceUID)
	if stale := getAgentFromRouter(t, second.Router(), rawID); stale.ID != "" {
		t.Fatalf("expected no raw uid duplicate after persisted restart, got %+v", stale)
	}
	agent := getAgentFromRouter(t, second.Router(), "persist-agent")
	if agent.Version != "0.151.0" || agent.Hostname != "persist-agent.example.invalid" || agent.LimitedMetadata {
		t.Fatalf("restored agent metadata = %+v", agent)
	}
}

func TestUIRootListsAgents(t *testing.T) {
	srv := New()
	router := srv.Router()

	sendJSON(t, router, http.MethodPost, "/v1/agents", map[string]any{
		"id":       "agent-001",
		"ring":     "canary",
		"version":  "0.1.0",
		"hostname": "lab-host-01",
		"health":   "healthy",
	}, http.StatusCreated)

	rec := request(t, router, http.MethodGet, "/", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("root status = %d, body %s", rec.Code, rec.Body.String())
	}
	if got := rec.Header().Get("Content-Type"); !strings.Contains(got, "text/html") {
		t.Fatalf("content-type = %q", got)
	}
	body := rec.Body.String()
	for _, want := range []string{"OpAMP Server", "Agents", "agent-001", "/agent?id=agent-001", "lab-host-01", "0.1.0", "healthy", "complete"} {
		if !strings.Contains(body, want) {
			t.Fatalf("root body missing %q:\n%s", want, body)
		}
	}
}

func TestUIAgentDetailAndConfigForm(t *testing.T) {
	srv := New()
	router := srv.Router()

	sendJSON(t, router, http.MethodPost, "/v1/agents", map[string]any{
		"id":       "agent-001",
		"ring":     "canary",
		"version":  "0.1.0",
		"hostname": "lab-host-01",
		"health":   "healthy",
	}, http.StatusCreated)
	sendJSON(t, router, http.MethodPost, "/v1/agents/agent-001/effective-config", map[string]any{
		"config": "receivers:\n  filelog:\n",
		"status": "applied",
	}, http.StatusOK)

	rec := request(t, router, http.MethodGet, "/agent?id=agent-001", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("agent detail status = %d, body %s", rec.Code, rec.Body.String())
	}
	body := rec.Body.String()
	for _, want := range []string{"Agent agent-001", "lab-host-01", "canary", "receivers:", "complete", "Save and Send to Agent"} {
		if !strings.Contains(body, want) {
			t.Fatalf("agent detail missing %q:\n%s", want, body)
		}
	}

	form := strings.NewReader("ring=canary&config=receivers%3A%0A++otlp%3A%0A")
	rec = request(t, router, http.MethodPost, "/agent/agent-001/config", form)
	rec.Result().Body.Close()
	if rec.Code != http.StatusSeeOther {
		t.Fatalf("config form status = %d, body %s", rec.Code, rec.Body.String())
	}
	if location := rec.Header().Get("Location"); location != "/agent?id=agent-001" {
		t.Fatalf("redirect location = %q", location)
	}

	agent := getAgentFromRouter(t, router, "agent-001")
	if agent.RemoteConfigStatus != "pending" {
		t.Fatalf("remote config status = %q", agent.RemoteConfigStatus)
	}
	if agent.DesiredConfigHash == "" {
		t.Fatal("expected desired config hash")
	}
}

func TestUIConfigFormShowsValidationError(t *testing.T) {
	srv := New()
	router := srv.Router()

	sendJSON(t, router, http.MethodPost, "/v1/agents", map[string]any{
		"id":   "agent-001",
		"ring": "canary",
	}, http.StatusCreated)

	form := strings.NewReader("ring=canary&config=INVALID")
	rec := request(t, router, http.MethodPost, "/agent/agent-001/config", form)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("invalid form status = %d, body %s", rec.Code, rec.Body.String())
	}
	if body := rec.Body.String(); !strings.Contains(body, "invalid_config") {
		t.Fatalf("body missing validation error:\n%s", body)
	}
}

func testAgentMessage(agentID string, ring string) *protobufs.AgentToServer {
	return &protobufs.AgentToServer{
		InstanceUid:      []byte(agentID + "-uid"),
		SequenceNum:      1,
		AgentDescription: testAgentDescription(agentID, ring),
		Capabilities: uint64(protobufs.AgentCapabilities_AgentCapabilities_AcceptsRemoteConfig |
			protobufs.AgentCapabilities_AgentCapabilities_ReportsRemoteConfig |
			protobufs.AgentCapabilities_AgentCapabilities_ReportsHealth |
			protobufs.AgentCapabilities_AgentCapabilities_ReportsEffectiveConfig),
	}
}

type fakeConnection struct{}

func (fakeConnection) Connection() net.Conn { return nil }

func (fakeConnection) Send(ctx context.Context, message *protobufs.ServerToAgent) error { return nil }

func (fakeConnection) Disconnect() error { return nil }

func sendJSON(t *testing.T, handler http.Handler, method string, path string, payload any, wantStatus int) map[string]any {
	t.Helper()

	body, err := json.Marshal(payload)
	if err != nil {
		t.Fatal(err)
	}
	req := httptest.NewRequest(method, path, bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != wantStatus {
		t.Fatalf("%s status = %d, want %d, body %s", path, rec.Code, wantStatus, rec.Body.String())
	}

	var result map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	return result
}

func getAgentFromRouter(t *testing.T, handler http.Handler, id string) Agent {
	t.Helper()

	req := httptest.NewRequest(http.MethodGet, "/v1/agents/"+id, nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code == http.StatusNotFound {
		return Agent{}
	}
	if rec.Code != http.StatusOK {
		t.Fatalf("get agent status = %d, body %s", rec.Code, rec.Body.String())
	}
	var agent Agent
	if err := json.Unmarshal(rec.Body.Bytes(), &agent); err != nil {
		t.Fatal(err)
	}
	return agent
}

func testAgentDescription(agentID string, ring string) *protobufs.AgentDescription {
	return testAgentDescriptionWithVersion(agentID, ring, "0.151.0")
}

func testAgentDescriptionWithVersion(agentID string, ring string, version string) *protobufs.AgentDescription {
	return &protobufs.AgentDescription{
		IdentifyingAttributes: []*protobufs.KeyValue{
			stringKV("service.name", "otelcol"),
			stringKV("service.instance.id", agentID),
			stringKV("service.version", version),
		},
		NonIdentifyingAttributes: []*protobufs.KeyValue{
			stringKV("host.name", agentID+".example.invalid"),
			stringKV("deployment.ring", ring),
		},
	}
}

func stringKV(key string, value string) *protobufs.KeyValue {
	return &protobufs.KeyValue{
		Key:   key,
		Value: &protobufs.AnyValue{Value: &protobufs.AnyValue_StringValue{StringValue: value}},
	}
}

func hexHash(hash []byte) string {
	return hex.EncodeToString(hash)
}

func request(t *testing.T, handler http.Handler, method string, path string, body io.Reader) *httptest.ResponseRecorder {
	t.Helper()

	req := httptest.NewRequest(method, path, body)
	if body != nil {
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	}
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	return rec
}

func getEventsFromRouter(t *testing.T, handler http.Handler, query string) []Event {
	t.Helper()

	rec := request(t, handler, http.MethodGet, "/v1/events"+query, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("events status = %d, body %s", rec.Code, rec.Body.String())
	}
	var body struct {
		Events []Event `json:"events"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	return body.Events
}

func eventActions(events []Event) []string {
	actions := make([]string, 0, len(events))
	for _, event := range events {
		actions = append(actions, event.Action)
	}
	return actions
}

func containsString(values []string, want string) bool {
	for _, value := range values {
		if value == want {
			return true
		}
	}
	return false
}
