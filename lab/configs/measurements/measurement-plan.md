# Measurement Plan

Goal: compare OCB logs-only collectors, Elastic Agent/Fleet, Fleet with OpenTelemetry Collectors, EDOT, and upstream Collector for logs ingestion and remote-management overhead.

## Variants

- `otelcol-logs-min`: OCB logs-only collector without OpAMP.
- `otelcol-logs-opamp`: OCB logs-only collector with OpAMP.
- Elastic Agent managed by Fleet.
- Fleet OpAMP visibility for upstream `otelcol-contrib`, with no Elastic Agent in the scenario.
- EDOT Collector baseline.
- Upstream OpenTelemetry Collector Contrib baseline.

## Required Measurements

1. Binary size: final executable bytes after stripping policy is decided.
2. Image size: compressed and uncompressed container image bytes.
3. RSS idle: resident memory after startup stabilization with no input.
4. RSS load: resident memory during sustained log generation.
5. CPU load: process CPU during sustained log generation.
6. Startup time: process start to healthy health-check response.
7. Throughput before loss/backpressure: maximum accepted log records per second before dropped records, queue saturation, retry growth, or source backpressure.

## Test Controls

- Use the same host or node type for every run.
- Pin collector versions and image tags.
- Use identical log payload size distributions.
- Keep Elastic Cloud region and deployment size constant.
- Record exporter failures and backend throttling separately from collector-local drops.
- Run at least three trials per variant and report median plus min/max.

## Suggested Load Sweep

Start at a low rate and increase until the first sustained failure signal:

```text
1k logs/s -> 5k logs/s -> 10k logs/s -> 25k logs/s -> 50k logs/s -> 100k logs/s
```

Failure signals:

- Collector self-telemetry reports dropped log records.
- Export queue remains above 80% for more than 60 seconds.
- Export retry count grows continuously for more than 60 seconds.
- Source generator blocks or reports write errors.
- Elastic backend returns sustained throttling or non-2xx responses.

## Output

Record raw results in `results-template.csv` and keep per-run notes in a separate local file if they contain environment identifiers.
