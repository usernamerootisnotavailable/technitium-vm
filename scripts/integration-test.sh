#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${root}"

export ANSIBLE_CONFIG="${root}/ansible.cfg"
export ANSIBLE_COLLECTIONS_PATH="${root}/collections"
ansible_playbook="${ANSIBLE_PLAYBOOK:-ansible-playbook}"
secret_file="${TMPDIR:-/tmp}/technitium-host-dev-test-secrets.yml"

generate_secrets() {
  umask 077
  {
    echo "---"
    printf 'secret_technitium_admin_password: "%s"\n' "$(openssl rand -hex 32)"
  } > "${secret_file}"
}

if [[ ! -f "${secret_file}" ]] ||
  ! grep -q '^secret_technitium_admin_password:' "${secret_file}"; then
  generate_secrets
fi
chmod 0600 "${secret_file}"

if [[ "${INTEGRATION_RESET:-true}" == "true" ]]; then
  ./scripts/dev-down.sh
fi
./scripts/dev-up.sh

echo "Applying site.yml with ephemeral test secrets"
"${ansible_playbook}" \
  -i inventories/dev/hosts.yml \
  site.yml \
  --extra-vars "@${secret_file}"

echo "Verifying the host"
"${ansible_playbook}" \
  -i inventories/dev/hosts.yml \
  playbooks/verify.yml \
  --extra-vars "@${secret_file}"

echo "Proving DHCP with a test-only temporary scope"
"${ansible_playbook}" \
  -i inventories/dev/hosts.yml \
  playbooks/tests/dhcp.yml \
  --extra-vars "@${secret_file}"

echo "Checking idempotence"
second_run="$("${ansible_playbook}" \
  -i inventories/dev/hosts.yml \
  site.yml \
  --extra-vars "@${secret_file}")"
printf '%s\n' "${second_run}"

if grep -Eq 'changed=[1-9][0-9]*' <<< "${second_run}"; then
  echo "The second run was not idempotent." >&2
  exit 1
fi

echo "Integration test passed."
