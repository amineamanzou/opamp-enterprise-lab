# Commands

```sh
task opamp:build
task opamp:supervisor:build:linux
task ocb:build
task collector:env
task ansible:collector:supervisor
task evidence:ops-experience
```

Remote config update:

```sh
./scripts/opamp-assign-config.sh dev lab/configs/opamp-ops/good-remote-config.yaml
./scripts/opamp-assign-config.sh dev lab/configs/opamp-ops/bad-remote-config.yaml
./scripts/opamp-assign-config.sh dev lab/configs/opamp-ops/good-remote-config.yaml
```

Restart:

```sh
./scripts/opamp-restart-agent.sh opamp-poc-host-agent
```

Version workflow:

```sh
task ocb:build:version VERSION=0.150.0
COLLECTOR_VERSION=0.150.0 task collector:env
task ansible:collector:supervisor:version VERSION=0.150.0
task ocb:build
COLLECTOR_VERSION=0.151.0 task collector:env
task ansible:collector:supervisor
```

Pre-sweep:

```sh
./scripts/opamp-pre-sweep.sh
```
