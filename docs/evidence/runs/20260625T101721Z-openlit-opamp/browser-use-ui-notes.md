# Browser-Use UI Notes

Use the local Chrome profile and capture only sanitized state.

```sh
browser-use --headed --profile Default open "<openlit-url>"
browser-use --headed --profile Default state > artifacts/browser-use/openlit-home.state.txt
browser-use --headed --profile Default screenshot
```

Required pages:

- OpenLit home or workspace page.
- Fleet Hub collector list.
- OpAMP endpoint or collector onboarding page.
- Collector detail page.
- Configuration, status, health, and error panels.
- TLS/mTLS or security settings page if visible.
- Pricing, usage, or plan page if visible in the account.

Capture:

- number of UI actions to find Fleet Hub and onboard the first collector;
- whether upstream `otelcol-contrib` is supported or a specific OpenLit distribution is required;
- fields required before OpenLit can generate an OpAMP config;
- whether remote config is editable from Fleet Hub;
- labels for healthy, unhealthy, disconnected, and config-error states;
- whether TLS/mTLS is required, optional, or self-host-only;
- friction caused by OpenLit-specific generated blocks, credentials, Controller concepts, or APIs.

Do not commit API keys, tokens, tenant IDs, emails, public IPs, private hostnames, raw account screenshots, or TLS private keys.
