# Commands

Fill this file during the live drill. Do not commit raw outputs containing addresses, tokens, tenant IDs, emails, or private hostnames.

## Fleet Exit

```sh
systemctl --user status <fleet-otel-service>
systemctl --user stop <fleet-otel-service>
systemctl --user start <opamp-supervisor-service>
```

## Bindplane Exit

```sh
ssh root@<host-agent> 'systemctl status observiq-otel-collector.service'
ssh root@<opamp-host> 'docker stop opamp-server-py-server'
ssh root@<opamp-host> 'systemctl start opamp-poc-server.service'
ssh root@<host-agent> 'systemctl stop observiq-otel-collector.service'
ssh root@<host-agent> 'systemctl start opampsupervisor-logs.service'
ssh root@<opamp-host> 'curl -fsS http://localhost:4321/v1/inventory'
```

## OpAMP Go Outage

```sh
ssh root@<opamp-host> 'systemctl stop opamp-poc-server.service'
sleep 45
ssh root@<host-agent> 'systemctl is-active opampsupervisor-logs.service'
ssh root@<host-agent> 'curl -fsS http://localhost:13133/'
ssh root@<opamp-host> 'systemctl start opamp-poc-server.service'
ssh root@<opamp-host> 'curl -fsS http://localhost:4321/v1/inventory'
```

## Elastic Continuity Check

```sh
curl -fsS "<elastic-query-endpoint>" \
  -H "Authorization: ApiKey <redacted-token>" \
  -H "Content-Type: application/json" \
  --data @config/elastic-continuity-query.redacted.json
```

## UI State

```sh
browser-use --headed --profile Default open "https://app.bindplane.com/"
browser-use --headed --profile Default state
browser-use --headed --profile Default open "<kibana-url>/app/fleet/agents"
browser-use --headed --profile Default state
```
