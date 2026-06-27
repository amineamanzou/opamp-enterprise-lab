#!/usr/bin/env bash
set -euo pipefail

export ANSIBLE_LOCAL_TEMP="${ANSIBLE_LOCAL_TEMP:-/tmp/opamp-poc-ansible-local}"
export ANSIBLE_REMOTE_TEMP="${ANSIBLE_REMOTE_TEMP:-/tmp/opamp-poc-ansible-remote}"
export ANSIBLE_HOME="${ANSIBLE_HOME:-/tmp/opamp-poc-ansible-home}"
mkdir -p "$ANSIBLE_LOCAL_TEMP" "$ANSIBLE_REMOTE_TEMP" "$ANSIBLE_HOME"

if command -v ansible-lint >/dev/null 2>&1; then
  ansible-lint .
else
  test -f inventory/example.ini
  test -f playbooks/bootstrap.yml
  grep -R "hosts:" -n playbooks
  echo "ansible-lint not installed; completed static Ansible scaffold checks"
fi
