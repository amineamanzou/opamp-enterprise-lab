package main

import (
	"context"
	"crypto/sha256"
	"encoding/csv"
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	opampclient "github.com/open-telemetry/opamp-go/client"
	opampclienttypes "github.com/open-telemetry/opamp-go/client/types"
	"github.com/open-telemetry/opamp-go/protobufs"
)

type runStats struct {
	Endpoint       string    `json:"endpoint"`
	Agents         int       `json:"agents"`
	Connected      int64     `json:"connected"`
	ConnectFailed  int64     `json:"connect_failed"`
	Errors         int64     `json:"errors"`
	RemoteConfigs  int64     `json:"remote_configs"`
	Commands       int64     `json:"commands"`
	StartedAt      time.Time `json:"started_at"`
	FinishedAt     time.Time `json:"finished_at"`
	DurationMillis int64     `json:"duration_millis"`
}

type mockAgent struct {
	id              string
	client          opampclient.OpAMPClient
	effectiveConfig atomic.Value
}

func main() {
	var endpoint string
	var token string
	var agents int
	var ring string
	var version string
	var hostnamePrefix string
	var serviceName string
	var heartbeat time.Duration
	var duration time.Duration
	var rampPerSecond int
	var csvPath string
	var adminURL string

	flag.StringVar(&endpoint, "endpoint", "ws://127.0.0.1:4320/v1/opamp", "OpAMP WebSocket endpoint")
	flag.StringVar(&token, "token", "", "optional bearer token")
	flag.IntVar(&agents, "agents", 100, "number of mock agents")
	flag.StringVar(&ring, "ring", "scale", "deployment ring reported by mock agents")
	flag.StringVar(&version, "version", "mock-0.1.0", "service.version reported by mock agents")
	flag.StringVar(&hostnamePrefix, "hostname-prefix", "opamp-scale", "host.name prefix")
	flag.StringVar(&serviceName, "service-name", "opamp-mock-agent", "service.name reported by mock agents")
	flag.DurationVar(&heartbeat, "heartbeat", 30*time.Second, "OpAMP heartbeat interval")
	flag.DurationVar(&duration, "duration", 5*time.Minute, "run duration after all agents are started")
	flag.IntVar(&rampPerSecond, "ramp-per-second", 20, "maximum agents started per second")
	flag.StringVar(&csvPath, "csv", "", "optional CSV output path")
	flag.StringVar(&adminURL, "admin-url", "", "optional server admin base URL, e.g. http://127.0.0.1:4321")
	flag.Parse()

	if agents < 1 {
		fatalf("agents must be >= 1")
	}
	if rampPerSecond < 1 {
		fatalf("ramp-per-second must be >= 1")
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	stats := runStats{Endpoint: endpoint, Agents: agents, StartedAt: time.Now().UTC()}
	mockAgents := make([]*mockAgent, 0, agents)
	header := http.Header{}
	if token != "" {
		header.Set("Authorization", "Bearer "+token)
	}

	startDelay := time.Second / time.Duration(rampPerSecond)
	for i := 0; i < agents; i++ {
		select {
		case <-ctx.Done():
			break
		default:
		}
		agent := newMockAgent(i, ring, version, hostnamePrefix, serviceName)
		mockAgents = append(mockAgents, agent)
		if err := agent.client.Start(ctx, agent.startSettings(endpoint, header, heartbeat, &stats)); err != nil {
			atomic.AddInt64(&stats.Errors, 1)
			fmt.Fprintf(os.Stderr, "start %s: %v\n", agent.id, err)
		}
		time.Sleep(startDelay)
	}

	if adminURL != "" {
		writeSnapshot(csvPath, "after_ramp", adminURL, &stats)
	}

	timer := time.NewTimer(duration)
	select {
	case <-ctx.Done():
	case <-timer.C:
	}
	if !timer.Stop() {
		select {
		case <-timer.C:
		default:
		}
	}

	var wg sync.WaitGroup
	for _, agent := range mockAgents {
		wg.Add(1)
		go func(agent *mockAgent) {
			defer wg.Done()
			stopCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			_ = agent.client.Stop(stopCtx)
		}(agent)
	}
	wg.Wait()

	stats.FinishedAt = time.Now().UTC()
	stats.DurationMillis = stats.FinishedAt.Sub(stats.StartedAt).Milliseconds()
	if adminURL != "" {
		writeSnapshot(csvPath, "finished", adminURL, &stats)
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(stats); err != nil {
		fatalf("write stats: %v", err)
	}
}

func newMockAgent(index int, ring string, version string, hostnamePrefix string, serviceName string) *mockAgent {
	id := fmt.Sprintf("%s-%06d", hostnamePrefix, index)
	agent := &mockAgent{
		id:     id,
		client: opampclient.NewWebSocket(nil),
	}
	agent.effectiveConfig.Store(effectiveConfig("collector.yaml", []byte("receivers:\n  nop:\nservice:\n  pipelines: {}\n")))
	descr := &protobufs.AgentDescription{
		IdentifyingAttributes: []*protobufs.KeyValue{
			stringKV("service.instance.id", id),
		},
		NonIdentifyingAttributes: []*protobufs.KeyValue{
			stringKV("service.name", serviceName),
			stringKV("service.namespace", ring),
			stringKV("service.version", version),
			stringKV("host.name", id),
			stringKV("deployment.environment", "lab"),
			stringKV("deployment.ring", ring),
		},
	}
	if err := agent.client.SetAgentDescription(descr); err != nil {
		fatalf("set agent description: %v", err)
	}
	if err := agent.client.SetHealth(&protobufs.ComponentHealth{Healthy: true, Status: "StatusOK"}); err != nil {
		fatalf("set health: %v", err)
	}
	return agent
}

func (a *mockAgent) startSettings(endpoint string, header http.Header, heartbeat time.Duration, stats *runStats) opampclienttypes.StartSettings {
	return opampclienttypes.StartSettings{
		OpAMPServerURL:    endpoint,
		Header:            header,
		InstanceUid:       instanceUID(a.id),
		HeartbeatInterval: &heartbeat,
		Capabilities: protobufs.AgentCapabilities_AgentCapabilities_AcceptsRemoteConfig |
			protobufs.AgentCapabilities_AgentCapabilities_ReportsRemoteConfig |
			protobufs.AgentCapabilities_AgentCapabilities_ReportsEffectiveConfig |
			protobufs.AgentCapabilities_AgentCapabilities_ReportsHealth |
			protobufs.AgentCapabilities_AgentCapabilities_ReportsHeartbeat,
		Callbacks: opampclienttypes.Callbacks{
			OnConnect: func(ctx context.Context) {
				atomic.AddInt64(&stats.Connected, 1)
			},
			OnConnectFailed: func(ctx context.Context, err error) {
				atomic.AddInt64(&stats.ConnectFailed, 1)
			},
			OnError: func(ctx context.Context, err *protobufs.ServerErrorResponse) {
				atomic.AddInt64(&stats.Errors, 1)
			},
			OnMessage: func(ctx context.Context, msg *opampclienttypes.MessageData) {
				if msg.RemoteConfig != nil {
					atomic.AddInt64(&stats.RemoteConfigs, 1)
					a.applyRemoteConfig(ctx, msg.RemoteConfig)
				}
			},
			OnCommand: func(ctx context.Context, command *protobufs.ServerToAgentCommand) error {
				atomic.AddInt64(&stats.Commands, 1)
				return nil
			},
			GetEffectiveConfig: func(ctx context.Context) (*protobufs.EffectiveConfig, error) {
				cfg, _ := a.effectiveConfig.Load().(*protobufs.EffectiveConfig)
				return cfg, nil
			},
		},
	}
}

func (a *mockAgent) applyRemoteConfig(ctx context.Context, config *protobufs.AgentRemoteConfig) {
	a.effectiveConfig.Store(&protobufs.EffectiveConfig{ConfigMap: config.Config})
	_ = a.client.SetRemoteConfigStatus(&protobufs.RemoteConfigStatus{
		LastRemoteConfigHash: config.ConfigHash,
		Status:               protobufs.RemoteConfigStatuses_RemoteConfigStatuses_APPLIED,
	})
	_ = a.client.UpdateEffectiveConfig(ctx)
}

func effectiveConfig(name string, body []byte) *protobufs.EffectiveConfig {
	return &protobufs.EffectiveConfig{
		ConfigMap: &protobufs.AgentConfigMap{ConfigMap: map[string]*protobufs.AgentConfigFile{
			name: {Body: body, ContentType: "text/yaml"},
		}},
	}
}

func instanceUID(id string) opampclienttypes.InstanceUid {
	sum := sha256.Sum256([]byte(id))
	var uid opampclienttypes.InstanceUid
	copy(uid[:], sum[:16])
	return uid
}

func stringKV(key string, value string) *protobufs.KeyValue {
	return &protobufs.KeyValue{
		Key:   key,
		Value: &protobufs.AnyValue{Value: &protobufs.AnyValue_StringValue{StringValue: value}},
	}
}

func writeSnapshot(csvPath string, phase string, adminURL string, stats *runStats) {
	if csvPath == "" {
		return
	}
	adminURL = strings.TrimRight(adminURL, "/")
	resp, err := http.Get(adminURL + "/v1/stats")
	if err != nil {
		fmt.Fprintf(os.Stderr, "stats snapshot %s: %v\n", phase, err)
		return
	}
	defer resp.Body.Close()
	var serverStats map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&serverStats); err != nil {
		fmt.Fprintf(os.Stderr, "decode stats snapshot %s: %v\n", phase, err)
		return
	}
	newFile := false
	if _, err := os.Stat(csvPath); os.IsNotExist(err) {
		newFile = true
	}
	file, err := os.OpenFile(csvPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "open csv %s: %v\n", csvPath, err)
		return
	}
	defer file.Close()
	writer := csv.NewWriter(file)
	if newFile {
		_ = writer.Write([]string{"timestamp_utc", "phase", "target_agents", "client_connected_callbacks", "client_connect_failed", "client_errors", "remote_configs", "server_agents", "server_connected_agents", "server_connections", "server_limited_metadata", "server_heap_alloc_bytes", "server_runtime_sys_bytes", "server_goroutines"})
	}
	_ = writer.Write([]string{
		time.Now().UTC().Format(time.RFC3339),
		phase,
		fmt.Sprintf("%d", stats.Agents),
		fmt.Sprintf("%d", atomic.LoadInt64(&stats.Connected)),
		fmt.Sprintf("%d", atomic.LoadInt64(&stats.ConnectFailed)),
		fmt.Sprintf("%d", atomic.LoadInt64(&stats.Errors)),
		fmt.Sprintf("%d", atomic.LoadInt64(&stats.RemoteConfigs)),
		fmtAny(serverStats["agents"]),
		fmtAny(serverStats["connected_agents"]),
		fmtAny(serverStats["connections"]),
		fmtAny(serverStats["limited_metadata_agents"]),
		fmtAny(serverStats["heap_alloc_bytes"]),
		fmtAny(serverStats["runtime_sys_bytes"]),
		fmtAny(serverStats["num_goroutine"]),
	})
	writer.Flush()
}

func fmtAny(value any) string {
	switch v := value.(type) {
	case float64:
		return fmt.Sprintf("%.0f", v)
	case string:
		return v
	default:
		return fmt.Sprintf("%v", v)
	}
}

func fatalf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}
