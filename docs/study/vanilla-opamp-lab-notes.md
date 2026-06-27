# Vanilla OpAMP Lab Notes

This document records operator friction, defects, and fixes discovered while testing the custom Go OpAMP server on the direct lab. These notes are inputs for the final maintenance and setup experience comparison.

## Identity and Status Visibility Issue

During the vanilla UI lab run, connected agents initially appeared with only raw OpAMP instance UIDs. The UI/API did not reliably show the operator fields needed for a control-plane comparison:

- stable or readable agent identity;
- collector version;
- hostname;
- health status;
- remote config status;
- desired config hash.

The capabilities bitmask was present, so this was not primarily a missing capabilities problem. The visible value was `18437` for connected collectors, while the missing fields were identity and status metadata.

## Investigation Notes

Observed behavior:

- VM and k3s collectors connected to the OpAMP server.
- Inventory showed raw hexadecimal IDs for several agents.
- `version`, `hostname`, and `health` were initially empty for some entries.
- `remote_config_status` became `RemoteConfigStatuses_UNSET` once the collector reported remote config state.
- `desired_config_hash` remained empty until the server assigned a desired remote config, which is expected.

Root causes and contributing factors:

- The collector configs only sent `service.name`, `deployment.environment`, and `deployment.ring` in `agent_description`.
- Adding `agent_description.identifying_attributes` was rejected by the deployed Collector build; the accepted config surface for this lab was `agent_description.non_identifying_attributes`.
- The Collector OpAMP extension sometimes reported a raw OpAMP instance UID as the agent ID even when hostname/version were available.
- The server created an entry from the first message keyed by raw `instance_uid`; later richer messages could create a second logical entry instead of merging with the first.
- The vanilla server UI was not part of the original minimal API-only implementation, so it had no prior handling for these operator-facing edge cases.

## Corrections Applied

Collector configuration corrections:

- Added `service.instance.id`, `service.version`, and `host.name` to OpAMP `agent_description.non_identifying_attributes`.
- Added matching resource attributes for emitted logs.
- Added host collector environment values for `SERVICE_INSTANCE_ID`, `COLLECTOR_VERSION`, and `HOST_NAME`.
- Added k8s downward API values for node and pod identity, then used them for service instance identity.

Server implementation corrections:

- Updated `lab/opamp-server/internal/server/server.go` to merge agent state when a later OpAMP message enriches an earlier raw instance UID entry.
- Added a readable identity fallback when the incoming ID is missing or looks like a raw 32-character OpAMP UID.
- Normalized public API/UI agent representation so inventory and detail pages show a useful operator ID when hostname is available.
- Allowed lookup/config assignment by the normalized public ID while keeping the internal connection map keyed safely.
- Added regression tests in `lab/opamp-server/internal/server/server_test.go` for delayed agent description, readable ID fallback, and raw hex ID replacement.

## Lab Verification

After redeploying the corrected server and restarting collectors, active agents exposed:

- readable IDs such as host or k8s node/pod identifiers;
- `version: 0.151.0`;
- non-empty `hostname`;
- `health: StatusOK`;
- `capabilities: 18437`;
- `remote_config_status: RemoteConfigStatuses_UNSET`.

`desired_config_hash` was still empty in the baseline inventory because no desired remote config had been assigned during that verification pass.

Verification commands completed successfully:

- `task opamp:test`;
- `task study:check`;
- `git diff --check`;
- `task ci:local`.

## Comparative Impact

For the final report, score the vanilla custom Go server as a minimal reference control plane, not as a ready management UI.

Important maintenance-experience findings:

- The lab required source-code changes in `server.go` to expose useful operator identity and status.
- The initial API-only shape hid practical UI and inventory requirements until tested with real collectors.
- Collector OpAMP metadata behavior required empirical adjustment; the accepted `agent_description` shape differed from the first attempted config.
- Remote config hash/status visibility depends on actually assigning desired config; an empty desired hash is not itself a failure in baseline mode.
- The custom Go server remains valuable as a protocol-level reference, but its setup and maintenance score must include the engineering effort needed to build and harden the UI/inventory surface.
