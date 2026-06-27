# Browser-Use UI Notes

Use the local Chrome profile and capture only sanitized state.

```sh
browser-use --headed --profile Default open "https://app.bindplane.com/"
browser-use --headed --profile Default state > artifacts/browser-use/bindplane-home.state.txt
browser-use --headed --profile Default screenshot
```

Required pages:

- Bindplane home/project page.
- Collector onboarding flow.
- API key flow.
- Collector list and collector detail page.
- Configuration builder and rollout page.
- Health, status, error, and last check-in panels.
- Billing, usage, or plan page if visible.

Capture:

- number of UI actions to onboard the first collector;
- whether upstream `otelcol-contrib` is supported or BDOT is required;
- fields required before Bindplane can generate config;
- whether Bindplane deploys/restarts/upgrades collectors or only configures them;
- whether bad config is blocked before rollout;
- visible plan limits for collectors, volume, users, support, and self-hosting;
- friction caused by Bindplane-specific generated blocks, credentials, or APIs.

Do not commit API keys, tokens, tenant IDs, emails, public IPs, private hostnames, or raw account screenshots.
