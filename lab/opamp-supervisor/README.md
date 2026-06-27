# OpAMP Supervisor Scenario

This directory holds the upstream `opampsupervisor` scenario for the lab.

The supervisor binary is published by the OpenTelemetry Collector releases project, not built with `go install` from the contrib module. Use:

```sh
task opamp:supervisor:build
```

For the Linux amd64 lab hosts, use:

```sh
task opamp:supervisor:build:linux
```

The lab template expects these non-secret environment variables:

- `OPAMP_SERVER_WS_ENDPOINT`: WebSocket endpoint such as `ws://opamp.example:4320/v1/opamp`.
- `OPAMP_AUTH_TOKEN`: lab enrollment token, kept outside git.
- `OPAMP_SUPERVISED_COLLECTOR`: path to the collector binary managed by the supervisor.
- `OPAMP_SUPERVISED_CONFIG`: path to the collector config file managed by the supervisor.
- `OPAMP_RING`: rollout ring, for example `dev`, `canary`, or `stable`.

Deploy the VM host-agent supervisor path with:

```sh
task ocb:build
task collector:env
task ansible:collector:supervisor
```

This replaces the direct `otelcol-logs-opamp` systemd service on the VM host agent with `opampsupervisor-logs`, while keeping the same supervised Collector binary and synthetic log source.
