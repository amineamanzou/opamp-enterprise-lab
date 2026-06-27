# OpenLit Functional And Maintainability Summary

Date: 2026-06-25

## Scope Adjustment

OpenLit volumetry paliers were not run. This pass evaluates product completeness and maintainability because Fleet Hub uses an OpAMP implementation underneath; protocol fan-out belongs to the lower-level OpAMP tests already covered elsewhere in the study.

## Deployment Result

### Local Workstation

- OpenLit source was cloned into `tmp/openlit-src`.
- The official Docker Compose file conflicted with existing local services on OTLP ports, so a local override was required.
- The smoke stack used shifted host ports: UI `localhost:3300`, OTLP `localhost:14317/14318`, OpAMP `localhost:14320`, API `localhost:18080`, ClickHouse `localhost:18123/19100`.
- `openlit-opamp-clickhouse` and `openlit-opamp-app` reached Docker `healthy`.
- The UI returned `307` to `/home` from `localhost:3300`.
- The documented `/health` endpoint on the OpAMP API port returned `404` in this image, while Docker health remained green.
- Container logs showed a Prisma seed validation error around `organisationId`, then migrations and server initialization continued successfully.

### Hetzner Smoke VM

- Terraform provisioned a single `cx23` VM by overriding the broader lab topology to disable host-agent, k3s, and optional-load VMs.
- OpenLit was deployed from the upstream repository with Docker Compose on the VM.
- The cloud override exposed the UI on HTTP `:80`, OTLP on `:4317/:4318`, OpAMP on `:4320`, and kept the OpAMP API bound to localhost on the VM.
- `openlit-cloud-clickhouse` and `openlit-cloud-app` reached Docker `healthy`.
- The public UI returned `307` to `/home`.
- The API `/health` endpoint again returned `404`, matching the local observation while container health stayed green.
- Startup logs again showed the Prisma seed validation error around `organisationId`, then server initialization continued successfully.

### Hetzner Multi-VM Extension

- Terraform was later expanded to the full lab shape: one OpenLit/OpAMP host, one host-agent VM, one k3s server, and one k3s worker.
- Firewall rules needed a follow-up update because the original OpAMP and k3s peer CIDR allowlists referenced prior lab hosts.
- The host-agent VM was bootstrapped with Ansible, synthetic logs, an OCB collector binary, and `opampsupervisor`.
- The first host-agent bridge attempt failed because the rendered endpoint used plain `ws://` while OpenLit's OpAMP server listens with TLS. Switching to `wss://` and adding `server.tls.insecure_skip_verify` to the supervisor config fixed the bridge.
- k3s installed successfully with one control-plane node and one worker node, both `Ready`.
- The Kubernetes DaemonSet collector scenario rolled out two collector pods and two synthetic log pods.
- The namespace-scoped application collector scenario rolled out one app collector pod and two synthetic app pods.
- The Kubernetes collectors initially failed TLS verification because OpenLit's development certificate did not include the public host in SANs. Adding `server.ws.tls.insecure_skip_verify: true` to the `opampextension` config fixed the k8s OpAMP bridge for this lab.

## Fleet Hub Evidence

- Browser-use opened `localhost:3300/fleet-hub`.
- Unauthenticated access redirected to the local signup/login page.
- The browser reused an existing local OpenLit session; screenshots of authenticated views were sanitized before saving.
- Fleet Hub listed the integrated `otelcol-contrib` collector.
- Visible list fields included instance ID, name, operating system, version, started time, and `StatusOK`.
- Collector detail exposed version, started time, host name, and health status.
- Detail page included `Custom Configuration` and `Effective Configuration (readonly)` panels, but both remained `Loading...` during the observation window.
- Browser-use also opened the Hetzner UI, created a synthetic smoke user, completed personal-organisation onboarding, and captured Fleet Hub from the public deployment.
- The Hetzner Fleet Hub view listed the integrated `otelcol-contrib` collector with version `0.142.0` and `StatusOK`.
- The Hetzner collector detail reproduced the same UI/API gap: metadata and health rendered, while Custom and Effective Configuration panels remained `Loading...`.
- After adding the host-agent and Kubernetes scenarios, Fleet Hub listed the host bridge, two k3s DaemonSet collectors, and the namespace-scoped app collector as `StatusOK`.

Screenshots:

- `screenshots/openlit-fleet-hub-sanitized.png`
- `screenshots/openlit-collector-detail-loading-config-sanitized.png`
- `screenshots/openlit-hetzner-fleet-hub-sanitized.png`
- `screenshots/openlit-hetzner-collector-detail-loading-config-sanitized.png`
- `screenshots/openlit-hetzner-fleet-hub-bridge-k8s-sanitized.png`

## API Evidence

The OpAMP API exposed richer state than the UI rendered in this smoke pass:

- `/api/agents` returned one connected agent in both local and Hetzner deployments.
- Agent ID: `019efe90-f747-74d8-bfca-1c4fd47d9e18`.
- Service name: `otelcol-contrib`.
- Service version: `0.142.0`.
- Health: `StatusOK`, healthy true.
- Component health included `extensions`, `pipeline:logs`, `pipeline:metrics`, and `pipeline:traces`.
- Effective config was present via API and included OTLP receivers, ClickHouse exporter, batch and memory limiter processors, and OpAMP extension config.
- Custom instance config was empty.
- Remote config status was present.
- The Hetzner agent reported the same service name, version, `StatusOK` health, component health, and API-side effective config availability.
- After bridge and k8s rollout, `/api/agents` returned `StatusOK` for:
  - the host-agent supervisor bridge (`deployment.ring=dev`);
  - two Kubernetes DaemonSet collectors (`deployment.ring=k8s`);
  - one namespace-scoped app collector (`deployment.ring=app`).

## Remote Config Safety

Bad config validation was tested through the OpAMP API without applying a destructive valid config:

| Test | Result |
| --- | --- |
| Invalid YAML body | HTTP 400 with YAML parse error in local and Hetzner deployments. |
| Scalar YAML instead of map | HTTP 400 with "Configuration must be a valid YAML object with key-value pairs" in local and Hetzner deployments. |

This is a positive maintainability signal: the API rejects malformed config before rollout.

## TLS Operation

- Development mode generated certificates and ran with insecure verification enabled.
- A TLS minimum-version connection settings offer for `TLSv1.3` returned HTTP 200 in local and Hetzner deployments.
- Logs then showed the offer was sent, but the server timed out waiting for agent reconnect after 5 seconds.
- The agent remained `StatusOK` afterward.

## Capability Notes

| Capability | Observed status |
| --- | --- |
| OpAMP inventory | Lab-proven for the integrated collector in local and Hetzner smoke. |
| Health status | Lab-proven via UI and API in local and Hetzner smoke. |
| Component health | Lab-proven via API; not fully visible in the captured UI state. |
| Effective config | Lab-proven via API; UI panel stayed loading in local and Hetzner smoke. |
| Custom config editor | UI present but disabled/loading during the observation window. |
| Bad config guardrail | Lab-proven via API in local and Hetzner smoke. |
| Host-agent OpAMP bridge | Lab-proven on Hetzner after switching the bridge to `wss` with dev TLS skip-verify. |
| Kubernetes DaemonSet collectors | Lab-proven on Hetzner: two k3s node collectors reported `StatusOK` in OpenLit. |
| Kubernetes app collector | Lab-proven on Hetzner: namespace-scoped collector reported `StatusOK` in OpenLit. |
| TLS/mTLS operations | Partially proven: dev cert generation and API offer path work; reconnect behavior needs follow-up. |
| External collector onboarding | Not tested in this pass because the available local `opampsupervisor` binary is Linux-only. |
| Volumetry | Deliberately out of scope. |

## Maintainer Friction

- Official compose required host-specific port overrides in a workstation with existing OTLP services.
- Compose list merging appended original ports until the override used explicit list replacement.
- The UI route required authentication before Fleet Hub evidence.
- A raw authenticated screenshot would expose account identity, so DOM sanitization was required before capture.
- UI/API alignment needs follow-up because API returned effective config while the UI config panels remained loading.
- OpenLit development certificates are localhost-oriented, so remote bridge and Kubernetes tests require either a proper SAN-bearing certificate or explicit lab-only TLS skip-verify.
- The stock scripts originally rendered `ws://` endpoints; OpenLit's deployed OpAMP server required `wss://`.

## Config Editor Loading Root Cause

The Fleet Hub detail page does not issue a separate config fetch. It renders `agent.CustomInstanceConfig` and `agent.EffectiveConfig` directly through the shared `CodeEditor` component, which wraps Monaco Editor.

Observed on the Hetzner deployment:

- The raw OpAMP API endpoint `/api/agent?id=<agent-id>` returned `EffectiveConfig` as a non-empty string.
- The authenticated Next.js route `/api/fleet-hub/<agent-id>` returned `{ data: ... }` with `data.EffectiveConfig` as a non-empty string and `data.CustomInstanceConfig` as an empty string.
- After waiting on the Fleet Hub detail page, the DOM still contained `Loading...`, but had zero `.monaco-editor` elements.
- The page contained the Monaco loader script URL from `https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/min/vs/loader.js`.
- Browser globals `window.require` and `window.monaco` stayed `undefined`.
- The OpenLit response header sets `Content-Security-Policy: script-src 'self' 'unsafe-inline' 'unsafe-eval'`, which does not allow loading scripts from `cdn.jsdelivr.net`.

Conclusion: the `Loading...` panels are not caused by missing OpAMP config data. They are Monaco editor loaders stuck because the deployed CSP blocks the external Monaco CDN loader used by `@monaco-editor/react`.

Likely fixes:

- bundle/self-host Monaco assets and configure the editor loader to use same-origin assets; or
- extend the CSP `script-src` to include the Monaco CDN and verify any worker-related directives; or
- replace Monaco in Fleet Hub config panels with a non-CDN text/code component for self-hosted deployments.
