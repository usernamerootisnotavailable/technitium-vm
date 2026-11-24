#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${root}"

failed=0

fail() {
  echo "POLICY FAILURE: $*" >&2
  failed=1
}

# Required documentation and role contract files.
for document in \
  README.md \
  AGENTS.md \
  docs/ARCHITECTURE.md \
  docs/VARIABLES.md \
  docs/SECRETS.md \
  docs/ENVIRONMENTS.md \
  docs/TESTING.md \
  docs/MIGRATION.md \
  docs/OPERATIONS.md \
  docs/CONTRIBUTING.md \
  docs/COMPONENTS.md \
  docs/components/technitium.md \
  docs/components/nginx.md; do
  [[ -f "${document}" ]] || fail "missing ${document}"
done

for role_dir in roles/*/; do
  role="${role_dir%/}"
  for required in \
    defaults/main.yml \
    handlers/main.yml \
    meta/main.yml \
    meta/argument_specs.yml \
    tasks/main.yml \
    README.md; do
    [[ -f "${role}/${required}" ]] || fail "missing ${role}/${required}"
  done
done

# Production inventory must remain outside the public repository.
if [[ -d inventories/prod ]]; then
  fail "inventories/prod must not exist in the public repository; use a private inventory directory"
fi

# Test-only app configuration must never enter normal convergence.
if grep -q 'tests/dhcp.yml' site.yml; then
  fail "the test-only DHCP playbook must not be imported by site.yml"
fi

# Application configuration must stay out of Ansible. The test-only DHCP
# playbook is the single explicit exception.
if grep -RInE '/api/(settings|dhcp|zones)|technitium_(dhcp_scopes|zones|records|dns_recursion|automation)' roles playbooks \
  --exclude-dir=tests 2>/dev/null | grep -q .; then
  fail "Technitium application configuration must not be managed by Ansible"
fi

if grep -q 'effectivelywild.technitium_dns' requirements.yml; then
  fail "the Technitium application collection must not be a normal dependency"
fi

# Environment identity must not appear in executable configuration.
if grep -RInE 'deployment_environment|inventory_dir|ansible_hostname' roles playbooks; then
  fail "environment or host identity is referenced in roles or playbooks"
fi

if grep -RInE '^[[:space:]]*when:.*\b(dev|prod)\b' roles playbooks; then
  fail "environment-name condition found in roles or playbooks"
fi

# No unpinned package or image state. The explicit security update playbook is
# the only allowed "latest" operation.
if grep -RInE --exclude=update.yml '^[[:space:]]*state:[[:space:]]*latest' roles playbooks; then
  fail "state: latest is forbidden outside playbooks/update.yml"
fi
if ! grep -q 'security: true' playbooks/update.yml; then
  fail "playbooks/update.yml must apply security updates only"
fi

if grep -RInE '(^|[[:space:]])image:.*:latest|^[[:space:]]*FROM[[:space:]]+[^[:space:]]+:latest' \
  docker roles .github inventories; then
  fail ":latest container images are forbidden"
fi

# No hidden failures.
if grep -RInE 'ignore_errors:[[:space:]]*true|failed_when:[[:space:]]*false' roles playbooks; then
  fail "ignore_errors/failed_when false hides failures"
fi

# No plaintext private keys.
if grep -RInE 'AGE-SECRET-KEY-1|BEGIN (OPENSSH|RSA|EC|DSA|PRIVATE) KEY' \
  --exclude-dir=.git \
  --exclude-dir=.venv \
  --exclude-dir=collections \
  --exclude-dir=.molecule \
  --exclude-dir=docs \
  --exclude=check-policy.sh \
  .; then
  fail "private key material found in the repository"
fi

# Technitium backup archives are secret material and must never be committed.
if find . -name '*.zip' -not -path './.git/*' -not -path './.venv/*' -not -path './collections/*' | grep -q .; then
  fail "backup zip files found in the repository"
fi

# Every SOPS file must be encrypted.
while IFS= read -r sops_file; do
  if ! grep -q '^sops:' "${sops_file}"; then
    fail "${sops_file} is not SOPS-encrypted"
  fi
done < <(find . -name '*.sops.yml' -not -path './.git/*' -not -path './collections/*' -not -path './.venv/*')

if find . -name '*.sops.yml' -not -path './.git/*' -not -path './collections/*' -not -path './.venv/*' | grep -q .; then
  if grep -q '^creation_rules: \[\]' .sops.yaml; then
    fail ".sops.yaml has no recipients while encrypted files exist"
  fi
fi

# Controller security settings.
grep -q '^host_key_checking = True' ansible.cfg || fail "host_key_checking must be True"
grep -q '^register_values_as_secrets = True' ansible.cfg || fail "SOPS secret masking must be enabled"
if grep -q '^log_path' ansible.cfg; then
  fail "log_path is forbidden because it can retain sensitive output"
fi

# The rootless low-port exception is confined to the technitium role.
if grep -RIn 'ip_unprivileged_port_start' roles | grep -v '^roles/technitium/' | grep -q .; then
  fail "the low-port sysctl must only be introduced by the technitium role"
fi

# Containers must not be privileged in roles or production templates.
if grep -RInE --exclude-dir=molecule '(^|[[:space:]])privileged:[[:space:]]*true|SecurityOpt.*label=disable' roles; then
  fail "privileged containers or disabled SELinux labels are forbidden in roles"
fi

# Inventory parity, dependency pinning, and version parity.
python_bin="${PYTHON:-python3}"
if [[ -x .venv/bin/python3 ]]; then
  python_bin=".venv/bin/python3"
fi
"${python_bin}" - <<'PY'
import sys
import yaml


def requirements(path):
    with open(path, encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def versions(path):
    with open(path, encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


dev_versions = versions("inventories/dev/group_vars/dns/versions.yml")
template_versions = versions("inventories/prod.example/group_vars/dns/versions.yml")
if dev_versions != template_versions:
    sys.exit("dev and prod.example component versions differ; keep the template aligned")

for collection in requirements("requirements.yml").get("collections", []):
    if not collection.get("version"):
        sys.exit(f"collection {collection.get('name', '<unnamed>')} is not pinned")
PY

if [[ "${failed}" -ne 0 ]]; then
  exit 1
fi

echo "Policy checks passed."
