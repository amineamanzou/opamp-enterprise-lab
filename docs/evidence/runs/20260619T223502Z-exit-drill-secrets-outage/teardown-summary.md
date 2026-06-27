# Teardown Summary

Teardown date: 2026-06-19 UTC.

Terraform destroy was run from `lab/infra/hcloud` with cloud secrets loaded from the local secret files.

## Destroyed Resources

Terraform reported:

- 4 Hetzner servers destroyed.
- 1 Hetzner firewall destroyed.
- 1 Hetzner SSH key destroyed.
- Total: 6 resources destroyed.

## Verification

Post-destroy checks:

- `terraform -chdir=lab/infra/hcloud state list` returned no resources.
- Hetzner API query for servers with label `project=opamp-poc` returned count `0`.
- Hetzner API query for firewalls with label `project=opamp-poc` returned count `0`.

## Final State

The lab compute infrastructure is gone. Any remaining evidence is local repository documentation and Elastic/Bindplane/Fleet SaaS-side historical state.
