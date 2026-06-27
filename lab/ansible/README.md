# OpAMP Lab Ansible Runtime

Minimal Ansible scaffold for bootstrapping and reconfiguring the OpAMP / fleet management logs POC hosts.

The playbooks are safe templates: they do not contain secrets and should be run only after replacing inventory examples with real hosts.

## Files

- `ansible.cfg`: Local Ansible defaults for this lab tree.
- `inventory/example.ini`: Example groups matching Terraform outputs.
- `group_vars/all.yml`: Non-secret defaults.
- `playbooks/bootstrap.yml`: Base package and OS bootstrap.
- `playbooks/opamp_server.yml`: OpAMP/evidence host preparation.
- `playbooks/synthetic_logs.yml`: Synthetic log generator host setup.
- `playbooks/collector_placeholders.yml`: Collector deployment placeholders.
- `playbooks/ocb_collector_host.yml`: Direct OCB Collector with OpAMP extension on host agents.
- `playbooks/opamp_supervisor_host.yml`: `opampsupervisor` managing the OCB Collector on host agents.
- `playbooks/k3s_notes.yml`: k3s/RKE2 notes and host preflight markers.
- `roles/*`: Minimal role implementations for each playbook.

## Secret Conventions

Do not commit:

- `inventory/hosts.ini`
- vault password files
- `*.vault.yml`
- kubeconfigs
- OpAMP tokens, enrollment keys, TLS private keys, or API keys

Use one of these patterns for secrets:

```sh
ansible-playbook -i inventory/hosts.ini playbooks/bootstrap.yml
ansible-playbook -i inventory/hosts.ini playbooks/opamp_server.yml --ask-vault-pass
```

or environment variables consumed by your future templates:

```sh
export OPAMP_ENROLLMENT_TOKEN="..."
```

## Expected Inventory Groups

- `opamp_server`: one host for the OpAMP server and evidence/log sink.
- `host_agents`: host VMs that generate logs and run host collectors.
- `k3s_servers`: one k3s server candidate.
- `k3s_workers`: one or more k3s worker candidates.
- `collectors`: union-style group for hosts that should eventually receive collectors.

## Dry Review Commands

These commands are local checks and do not contact the cloud:

```sh
ansible-inventory -i inventory/example.ini --list
ansible-playbook -i inventory/example.ini playbooks/bootstrap.yml --syntax-check
ansible-playbook -i inventory/example.ini playbooks/opamp_server.yml --syntax-check
ansible-playbook -i inventory/example.ini playbooks/synthetic_logs.yml --syntax-check
ansible-playbook -i inventory/example.ini playbooks/collector_placeholders.yml --syntax-check
ansible-playbook -i inventory/example.ini playbooks/ocb_collector_host.yml --syntax-check
ansible-playbook -i inventory/example.ini playbooks/opamp_supervisor_host.yml --syntax-check
ansible-playbook -i inventory/example.ini playbooks/k3s_notes.yml --syntax-check
```

The example inventory uses RFC 5737 documentation addresses and is not runnable against real machines.
