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
systemctl status <bindplane-bdot-service>
systemctl stop <bindplane-bdot-service>
systemctl start <opamp-supervisor-service>
```

## OpAMP Go Outage

```sh
systemctl stop <opamp-go-service>
sleep 60
systemctl start <opamp-go-service>
```

## Elastic Continuity Check

```sh
curl -fsS "<elastic-query-endpoint>" \
  -H "Authorization: ApiKey <redacted-token>" \
  -H "Content-Type: application/json" \
  --data @config/elastic-continuity-query.redacted.json
```
