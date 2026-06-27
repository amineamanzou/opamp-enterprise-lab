# Local Encrypted Secrets

This directory contains plaintext templates only. Real SOPS files may be created
locally for private runs, but `*.sops.yaml` is ignored and must not be committed.

Local SOPS files used by the cloud lab, when present:

- `hcloud.sops.yaml`
- `elastic-cloud.sops.yaml`

Render them locally with:

```sh
task secrets:render
```

The rendered files go to `secrets/*.env`, which is gitignored.
