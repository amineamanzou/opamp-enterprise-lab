# OpAMP Operations Experience Runbook

This runbook executes day-2 operations for the vanilla custom Go OpAMP server on `main`.

## Scope

- Target control plane: custom Go OpAMP server.
- Target managed agent: VM host collector managed by `opampsupervisor`.
- Kubernetes collectors remain direct DaemonSet collectors for this run.
- Upgrade/downgrade is measured as an operations redeploy workflow, not native OpAMP package update.
- Volumetry is a pre-sweep only: `1k`, `5k`, `10k` logs/s.

## Prepare

```sh
task opamp:build
task opamp:supervisor:build:linux
task ocb:build
task collector:env
task ansible:collector:supervisor
task evidence:ops-experience
```

Verify inventory:

```sh
ssh -o UserKnownHostsFile=/tmp/opamp_poc_known_hosts -o StrictHostKeyChecking=accept-new root@<opamp-host> \
  'curl -fsS http://127.0.0.1:4321/v1/inventory | jq .'
```

Redact public IPs before copying command output into public evidence.

## Remote Config Update

Good config:

```sh
./scripts/opamp-assign-config.sh dev lab/configs/opamp-ops/good-remote-config.yaml
```

Expected:

- `desired_config_hash` becomes non-empty.
- `remote_config_status` transitions through applying and reaches `RemoteConfigStatuses_APPLIED`.
- Current vanilla server evidence uses desired hash and remote config status. Effective config may remain empty with the supervisor path and is tracked as a visibility limitation.
- Logs continue to export.

Bad config:

```sh
./scripts/opamp-assign-config.sh dev lab/configs/opamp-ops/bad-remote-config.yaml
```

Expected:

- `remote_config_status` reaches `RemoteConfigStatuses_FAILED`.
- Supervisor logs show collector start/config failure.

Recover:

```sh
./scripts/opamp-assign-config.sh dev lab/configs/opamp-ops/good-remote-config.yaml
```

Expected:

- Status returns to `RemoteConfigStatuses_APPLIED`.
- Health returns to OK.

## Restart Agent

```sh
./scripts/opamp-restart-agent.sh opamp-poc-host-agent
```

Expected:

- API returns `{"status":"pending","command":"restart"}`.
- Inventory briefly shows reconnect behavior.
- Agent returns to connected and healthy.

## Downgrade And Upgrade

Downgrade to `0.150.0`:

```sh
task ocb:build:version VERSION=0.150.0
COLLECTOR_VERSION=0.150.0 task collector:env
task ansible:collector:supervisor:version VERSION=0.150.0
```

Return to `0.151.0`:

```sh
task ocb:build
COLLECTOR_VERSION=0.151.0 task collector:env
task ansible:collector:supervisor
```

Expected:

- Inventory version changes to the target value after each redeploy.
- Logs continue to export after recovery.
- Note this as an external deployment workflow, not OpAMP package update.

## Lab Friction To Capture

- The default direct OCB OpAMP extension path reported sparse capabilities: no usable version, hostname, health, config status, or hash. Moving the VM agent behind `opampsupervisor` fixed the main day-2 fields for the host-agent scenario.
- The custom Go server needed source changes to expose restart command handling and to preserve readable agent identity when supervisor instance IDs changed.
- `opampsupervisor` `0.151.0` rejected the documented-looking `agent.access_dirs` key, so the deployed supervisor config omits it.
- Environment override of the collector binary path was brittle during escalated Ansible runs; use `task ansible:collector:supervisor:version VERSION=...` for downgrade/upgrade evidence.
- Effective config body visibility is still incomplete on the vanilla server path, even when the supervisor reports `RemoteConfigStatuses_APPLIED`.

## Pre-Sweep Volumetry

```sh
./scripts/opamp-pre-sweep.sh
```

Default output:

```text
tmp/opamp-pre-sweep.csv
```

Expected:

- Rows for `1k`, `5k`, and `10k` logs/s.
- Generated log count, collector RSS/CPU, supervisor RSS/CPU.
- Any source write errors or collector/exporter backpressure must be copied into evidence notes.
