#!/usr/bin/env node
import { writeFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const out = resolve(root, "lab/configs/elastic/opamp-visibility-kibana.ndjson");
const version = "9.5.0";

function dataView(id, title, name) {
  return {
    type: "index-pattern",
    id,
    attributes: { title, name, timeFieldName: "@timestamp" },
    references: [],
  };
}

function vega(id, title, description, spec) {
  return {
    type: "visualization",
    id,
    attributes: {
      title,
      description,
      visState: JSON.stringify({
        title,
        type: "vega",
        params: { spec: JSON.stringify(spec, null, 2) },
      }),
      uiStateJSON: "{}",
      version: 1,
      kibanaSavedObjectMeta: {
        searchSourceJSON: JSON.stringify({
          query: { query: "", language: "kuery" },
          filter: [],
        }),
      },
    },
    references: [],
  };
}

function lineSpec(index, field, title, interval = "30s") {
  return {
    $schema: "https://vega.github.io/schema/vega/v5.json",
    autosize: { type: "fit", contains: "padding" },
    padding: 5,
    data: [{
      name: "table",
      url: {
        "%context%": true,
        "%timefield%": "@timestamp",
        index,
        body: {
          size: 0,
          aggs: {
            times: {
              date_histogram: { field: "@timestamp", fixed_interval: interval },
              aggs: { value: { max: { field } } },
            },
          },
        },
      },
      format: { property: "aggregations.times.buckets" },
    }],
    scales: [
      { name: "x", type: "time", domain: { data: "table", field: "key" }, range: "width" },
      { name: "y", type: "linear", domain: { data: "table", field: "value.value" }, nice: true, zero: true, range: "height" },
    ],
    axes: [
      { orient: "bottom", scale: "x", title: "Time" },
      { orient: "left", scale: "y", title },
    ],
    marks: [{
      type: "line",
      from: { data: "table" },
      encode: {
        enter: { stroke: { value: "#36a2ef" }, strokeWidth: { value: 2 } },
        update: {
          x: { scale: "x", field: "key" },
          y: { scale: "y", field: "value.value" },
        },
      },
    }],
  };
}

function eventBars(index, title, groupField = "event.action") {
  return barSpec(index, groupField, "Events", title);
}

function barSpec(index, field, yTitle, title) {
  return {
    $schema: "https://vega.github.io/schema/vega/v5.json",
    autosize: { type: "fit", contains: "padding" },
    padding: 5,
    data: [{
      name: "table",
      url: {
        "%context%": true,
        "%timefield%": "@timestamp",
        index,
        body: {
          size: 0,
          aggs: {
            by_key: {
              terms: { field, size: 12 },
            },
          },
        },
      },
      format: { property: "aggregations.by_key.buckets" },
    }],
    scales: [
      { name: "x", type: "linear", domain: { data: "table", field: "doc_count" }, nice: true, zero: true, range: "width" },
      { name: "y", type: "band", domain: { data: "table", field: "key" }, range: "height", padding: 0.15 },
    ],
    axes: [
      { orient: "bottom", scale: "x", title: yTitle },
      { orient: "left", scale: "y", title: field },
    ],
    title,
    marks: [{
      type: "rect",
      from: { data: "table" },
      encode: {
        enter: { fill: { value: "#54b399" } },
        update: {
          x: { scale: "x", value: 0 },
          x2: { scale: "x", field: "doc_count" },
          y: { scale: "y", field: "key" },
          height: { scale: "y", band: 1 },
        },
      },
    }],
  };
}

function termsBars(index, field, title) {
  return barSpec(index, field, "Documents", title);
}

function dateHistogram(index, title, interval = "1m") {
  return {
    $schema: "https://vega.github.io/schema/vega/v5.json",
    autosize: { type: "fit", contains: "padding" },
    padding: 5,
    title,
    data: [{
      name: "table",
      url: {
        "%context%": true,
        "%timefield%": "@timestamp",
        index,
        body: {
          size: 0,
          aggs: { times: { date_histogram: { field: "@timestamp", fixed_interval: interval } } },
        },
      },
      format: { property: "aggregations.times.buckets" },
    }],
    scales: [
      { name: "x", type: "time", domain: { data: "table", field: "key" }, range: "width" },
      { name: "y", type: "linear", domain: { data: "table", field: "doc_count" }, nice: true, zero: true, range: "height" },
    ],
    axes: [
      { orient: "bottom", scale: "x", title: "Time" },
      { orient: "left", scale: "y", title: "Documents" },
    ],
    marks: [{
      type: "line",
      from: { data: "table" },
      encode: {
        enter: { stroke: { value: "#d36086" }, strokeWidth: { value: 2 } },
        update: {
          x: { scale: "x", field: "key" },
          y: { scale: "y", field: "doc_count" },
        },
      },
    }],
  };
}

function dashboard(id, title, description, panels) {
  const refs = panels.map((panel, idx) => ({
    type: "visualization",
    id: panel.id,
    name: `panel_${idx}`,
  }));
  return {
    type: "dashboard",
    id,
    attributes: {
      title,
      description,
      panelsJSON: JSON.stringify(
        panels.map((panel, idx) => ({
          version,
          type: "visualization",
          gridData: panel.grid,
          panelIndex: `${idx}`,
          embeddableConfig: {},
          panelRefName: `panel_${idx}`,
        })),
      ),
      optionsJSON: JSON.stringify({
        useMargins: true,
        syncColors: false,
        syncCursor: true,
        syncTooltips: true,
      }),
      timeRestore: false,
      version: 1,
      kibanaSavedObjectMeta: {
        searchSourceJSON: JSON.stringify({
          query: { query: "", language: "kuery" },
          filter: [],
        }),
      },
    },
    references: refs,
  };
}

const visualizations = [
  vega("opamp-viz-server-connected-agents", "OpAMP connected agents", "Connected agents over time from metrics-opamp.server.", lineSpec("metrics-opamp.server-*", "server.connected_agents", "Connected agents")),
  vega("opamp-viz-server-goroutines", "OpAMP server goroutines", "Runtime goroutine pressure on the vanilla OpAMP server.", lineSpec("metrics-opamp.server-*", "server.num_goroutine", "Goroutines")),
  vega("opamp-viz-server-heap", "OpAMP heap allocation", "Heap allocation on the vanilla OpAMP server.", lineSpec("metrics-opamp.server-*", "server.heap_alloc_bytes", "Heap alloc bytes")),
  vega("opamp-viz-agent-events", "OpAMP lifecycle events", "Lifecycle, config and version events emitted by the OpAMP server.", eventBars("logs-opamp.events-*", "OpAMP events by action")),
  vega("opamp-viz-version-direction", "Upgrade and downgrade events", "Version transitions by direction.", eventBars("logs-opamp.events-*", "Version changes", "agent.version_direction")),
  vega("opamp-viz-config-status", "Remote config status changes", "Remote config lifecycle status changes.", eventBars("logs-opamp.events-*", "Config status", "agent.current_status")),
  vega("opamp-viz-inventory-version", "Inventory by collector version", "Latest indexed inventory documents by version.", termsBars("logs-opamp.inventory-*", "agent.version", "Inventory by version")),
  vega("opamp-viz-inventory-ring", "Inventory by ring", "Latest indexed inventory documents by ring.", termsBars("logs-opamp.inventory-*", "agent.ring", "Inventory by ring")),
  vega("opamp-viz-host-cpu", "Host load average", "Host 1m load average on VM collector hosts.", lineSpec("metrics-hostmetricsreceiver.otel-*,metrics-metrics.host.otel-*", "metrics.system.cpu.load_average.1m", "Host 1m load average", "1m")),
  vega("opamp-viz-k8s-cpu", "Kubernetes CPU usage", "Kubernetes node CPU usage from kubeletstats.", lineSpec("metrics-kubeletstatsreceiver.otel-*,metrics-metrics.kubernetes_node.otel-*", "metrics.k8s.node.cpu.usage", "Kubernetes node CPU usage", "1m")),
  vega("opamp-viz-collector-failures", "Collector refused log records", "Collector self-observability refused log record metrics.", lineSpec("metrics-metrics.collector.otel-*", "metrics.otelcol_receiver_refused_log_records_total", "Refused log records", "1m")),
  vega("opamp-viz-app-log-rate", "Synthetic app log rate", "Application log throughput through the namespace collector.", dateHistogram("logs-app.synthetic.otel-*", "App logs per minute")),
  vega("opamp-viz-app-errors", "Synthetic app errors", "Synthetic app error events by level.", termsBars("logs-app.synthetic.otel-*", "attributes.level", "App logs by level")),
  vega("opamp-viz-app-metrics", "Synthetic app emitted events", "Application Prometheus metric scraped by the app collector.", lineSpec("metrics-metrics.application.otel-*", "metrics.synthetic_app_log_events_total", "Synthetic app events", "1m")),
];

const panel = (id, x, y, w = 24, h = 12) => ({ id, grid: { x, y, w, h, i: id } });

const dashboards = [
  dashboard("opamp-lab-visibility-overview", "OpAMP 360 Overview", "360 view of OpAMP control-plane health, lifecycle events, inventory and application telemetry.", [
    panel("opamp-viz-server-connected-agents", 0, 0),
    panel("opamp-viz-agent-events", 24, 0),
    panel("opamp-viz-config-status", 0, 12),
    panel("opamp-viz-app-log-rate", 24, 12),
    panel("opamp-viz-collector-failures", 0, 24),
    panel("opamp-viz-inventory-version", 24, 24),
  ]),
  dashboard("opamp-lab-agent-lifecycle", "OpAMP Agent Lifecycle", "Agent disconnects, reconnects, restart commands, upgrades, downgrades and remote config impact.", [
    panel("opamp-viz-agent-events", 0, 0),
    panel("opamp-viz-version-direction", 24, 0),
    panel("opamp-viz-config-status", 0, 12),
    panel("opamp-viz-inventory-ring", 24, 12),
  ]),
  dashboard("opamp-lab-volumetry-capacity", "OpAMP Volumetry & Capacity", "Server, VM, Kubernetes and collector load during experimentation and volumetry tests.", [
    panel("opamp-viz-server-connected-agents", 0, 0),
    panel("opamp-viz-server-goroutines", 24, 0),
    panel("opamp-viz-server-heap", 0, 12),
    panel("opamp-viz-host-cpu", 24, 12),
    panel("opamp-viz-k8s-cpu", 0, 24),
    panel("opamp-viz-collector-failures", 24, 24),
  ]),
  dashboard("opamp-lab-app-collector", "OpAMP App Collector", "Namespace-scoped application collector telemetry for the synthetic app.", [
    panel("opamp-viz-app-log-rate", 0, 0),
    panel("opamp-viz-app-errors", 24, 0),
    panel("opamp-viz-app-metrics", 0, 12),
    panel("opamp-viz-collector-failures", 24, 12),
  ]),
];

const objects = [
  dataView("opamp-lab-logs", "logs-*-*,logs-opamp.*-*", "OpAMP Lab Logs"),
  dataView("opamp-lab-metrics", "metrics-*-*,metrics-opamp.*-*", "OpAMP Lab Metrics"),
  dataView("opamp-control-plane", "logs-opamp.*-*,metrics-opamp.*-*", "OpAMP Control Plane"),
  dataView("opamp-app-telemetry", "logs-app.synthetic.otel-*,metrics-metrics.application.otel-*", "OpAMP App Telemetry"),
  ...visualizations,
  ...dashboards,
];

writeFileSync(out, `${objects.map((object) => JSON.stringify(object)).join("\n")}\n`);
