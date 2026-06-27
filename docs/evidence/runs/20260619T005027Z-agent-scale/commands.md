# Commands

```sh
task opamp:agent-swarm:build
task opamp:scale:agents
task evidence:agent-scale
```

Override defaults:

```sh
OPAMP_AGENT_SCALE_COUNTS="100 250 500 1000 2000 5000" \
OPAMP_AGENT_SCALE_DURATION=5m \
OPAMP_AGENT_SCALE_RAMP_PER_SECOND=50 \
task opamp:scale:agents
```
