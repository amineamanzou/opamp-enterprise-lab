#!/usr/bin/env bash
set -euo pipefail

if command -v terraform >/dev/null 2>&1; then
  terraform fmt -check -recursive
  if [ "${TERRAFORM_VALIDATE_SCHEMAS:-0}" = "1" ]; then
    terraform validate
  else
    test -f main.tf
    test -f variables.tf
    test -f outputs.tf
    grep -R "resource \"hcloud_server\"" -n .
    echo "completed static Terraform checks; set TERRAFORM_VALIDATE_SCHEMAS=1 to run provider-backed terraform validate"
  fi
else
  test -f main.tf
  test -f variables.tf
  test -f outputs.tf
  grep -R "resource \"hcloud_server\"" -n .
  echo "terraform not installed; completed static Terraform scaffold checks"
fi
