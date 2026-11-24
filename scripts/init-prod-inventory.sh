#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template="${root}/inventories/prod.example"
output="${1:-${XDG_CONFIG_HOME:-${HOME}/.config}/technitium-ansible/prod}"

usage() {
  echo "Usage: $0 [output-directory]" >&2
  exit 2
}

[[ $# -le 1 ]] || usage

for tool in sops openssl python3; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Required command not found: ${tool}" >&2
    exit 1
  fi
done

if [[ -e "${output}" ]] && [[ -n "$(find "${output}" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
  echo "${output} already exists and is not empty; refusing to overwrite." >&2
  exit 1
fi

umask 077
install -d -m 0700 "${output}" "${output}/group_vars" "${output}/group_vars/all" \
  "${output}/group_vars/dns" "${output}/host_vars" "${output}/host_vars/dns01"

ask() {
  local prompt="$1" default="$2" value
  if [[ -n "${default}" ]]; then
    read -r -p "${prompt} [${default}]: " value
    printf '%s' "${value:-${default}}"
  else
    read -r -p "${prompt}: " value
    printf '%s' "${value}"
  fi
}

ask_secret() {
  local prompt="$1" value
  read -r -s -p "${prompt}: " value
  echo >&2
  printf '%s' "${value}"
}

ask_yes_no() {
  local prompt="$1" default="$2" answer
  read -r -p "${prompt} [${default}]: " answer
  answer="${answer:-${default}}"
  case "${answer,,}" in
    y|yes) return 0 ;;
    n|no) return 1 ;;
    *) echo "Please answer yes or no." >&2; exit 1 ;;
  esac
}

validate_cidr() {
  python3 - "$1" <<'PY'
import ipaddress
import sys
try:
    ipaddress.ip_network(sys.argv[1], strict=False)
except ValueError:
    raise SystemExit(1)
PY
}

validate_ip_in_network() {
  python3 - "$1" "$2" <<'PY'
import ipaddress
import sys
try:
    address = ipaddress.ip_address(sys.argv[1])
    network = ipaddress.ip_network(sys.argv[2], strict=False)
except ValueError:
    raise SystemExit(1)
raise SystemExit(0 if address in network else 1)
PY
}

validate_fqdn() {
  [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]]
}

validate_cidr_list() {
  local csv="$1" item
  IFS=',' read -r -a items <<<"${csv}"
  for item in "${items[@]}"; do
    item="$(echo "${item}" | xargs)"
    [[ -n "${item}" ]] || continue
    validate_cidr "${item}" || {
      echo "Invalid CIDR: ${item}" >&2
      exit 1
    }
  done
}

yaml_list() {
  local csv="$1" item
  IFS=',' read -r -a items <<<"${csv}"
  for item in "${items[@]}"; do
    item="$(echo "${item}" | xargs)"
    [[ -n "${item}" ]] || continue
    printf '  - %s\n' "${item}"
  done
}

echo "Technitium production inventory setup"
echo "Output: ${output}"
echo

ssh_host="$(ask "SSH address of the DNS host" "203.0.113.10")"
ssh_port="$(ask "SSH port" "22")"
ssh_user="$(ask "SSH automation user" "ansible")"
ssh_key="$(ask "SSH private key path (blank uses agent/default)" "")"

lan_interface="$(ask "Single LAN interface name" "ens18")"
server_address="$(ask "Static server address on the LAN" "10.20.0.5")"
lan_cidr="$(ask "LAN CIDR" "10.20.0.0/24")"
ssh_admin_cidrs="$(ask "SSH administrator CIDRs (comma-separated)" "10.20.10.0/24")"
console_admin_cidrs="$(ask "Console administrator CIDRs (comma-separated)" "10.20.10.0/24")"
[[ -n "${ssh_admin_cidrs}" ]] || { echo "At least one SSH CIDR is required." >&2; exit 1; }
[[ -n "${console_admin_cidrs}" ]] || { echo "At least one console CIDR is required." >&2; exit 1; }

validate_cidr "${lan_cidr}" || { echo "Invalid LAN CIDR: ${lan_cidr}" >&2; exit 1; }
validate_ip_in_network "${server_address}" "${lan_cidr}" || {
  echo "Server address ${server_address} is not in ${lan_cidr}." >&2
  exit 1
}
validate_cidr_list "${ssh_admin_cidrs}"
validate_cidr_list "${console_admin_cidrs}"

allow_dhcp="false"
if ask_yes_no "Will this host serve DHCP" "n"; then
  allow_dhcp="true"
fi

public_fqdn="$(ask "Public console FQDN" "dns01.example.com")"
validate_fqdn "${public_fqdn}" || { echo "Invalid FQDN: ${public_fqdn}" >&2; exit 1; }

letsencrypt_answer="n"
letsencrypt_email=""
cloudflare_token=""
if ask_yes_no "Configure Let's Encrypt with Cloudflare DNS-01 now" "y"; then
  letsencrypt_answer="y"
  letsencrypt_email="$(ask "Let's Encrypt account email" "")"
  [[ "${letsencrypt_email}" == *@*.* ]] || { echo "A valid email is required." >&2; exit 1; }
  cloudflare_token="$(ask_secret "Cloudflare API token (Zone:DNS:Edit for the zone)")"
  [[ -n "${cloudflare_token}" ]] || { echo "The Cloudflare token is required for Let's Encrypt." >&2; exit 1; }
fi

age_recipient="${SOPS_AGE_RECIPIENT:-}"
if [[ -z "${age_recipient}" ]]; then
  age_recipient="$(ask "Age public recipient for SOPS encryption" "")"
fi
[[ "${age_recipient}" == age1* ]] || { echo "The age recipient must start with age1." >&2; exit 1; }

admin_password="$(openssl rand -hex 32)"

cat > "${output}/hosts.yml" <<EOF
---
all:
  children:
    dns:
      hosts:
        dns01:
          ansible_host: ${ssh_host}
          ansible_user: ${ssh_user}
          ansible_port: ${ssh_port}
EOF

if [[ -n "${ssh_key}" ]]; then
  cat >> "${output}/hosts.yml" <<EOF
          ansible_ssh_private_key_file: ${ssh_key}
EOF
fi

cat > "${output}/group_vars/all/main.yml" <<EOF
---
deployment_environment: prod

common_manage_time: true
common_firewall_enabled: true
common_require_selinux: true
common_firewall_zone: public

common_firewall_allowed_ssh_cidrs:
$(yaml_list "${ssh_admin_cidrs}")

common_ssh_allow_users:
  - ${ssh_user}

# Add human administrators and their public keys here.
common_admin_users: []
EOF

cat > "${output}/group_vars/dns/main.yml" <<EOF
---
technitium_admin_password: "{{ secret_technitium_admin_password | mandatory }}"
EOF

cat > "${output}/group_vars/dns/network.yml" <<EOF
---
technitium_lan_interface: ${lan_interface}
technitium_server_address: ${server_address}
technitium_firewall_lan_cidrs:
  - ${lan_cidr}
technitium_firewall_zone: public

technitium_manage_firewall: true
technitium_firewall_allow_dhcp: ${allow_dhcp}

nginx_allowed_cidrs:
$(yaml_list "${console_admin_cidrs}")
EOF

if [[ "${letsencrypt_answer}" == "y" ]]; then
  cat > "${output}/group_vars/dns/tls.yml" <<EOF
---
nginx_server_name: ${public_fqdn}
nginx_tls_mode: letsencrypt
nginx_letsencrypt_email: ${letsencrypt_email}
nginx_cloudflare_api_token: "{{ secret_cloudflare_dns_api_token | mandatory }}"
nginx_manage_firewall: true
EOF
else
  cat > "${output}/group_vars/dns/tls.yml" <<EOF
---
nginx_server_name: ${public_fqdn}
nginx_tls_mode: selfsigned
nginx_manage_firewall: true
EOF
fi

cp "${template}/group_vars/dns/versions.yml" "${output}/group_vars/dns/versions.yml"
cp "${template}/host_vars/dns01/main.yml" "${output}/host_vars/dns01/main.yml"

cat > "${output}/.sops.yaml" <<EOF
---
creation_rules:
  - path_regex: group_vars/dns/secrets\\.sops\\.yml\$
    age: ${age_recipient}
EOF

plaintext="$(mktemp)"
trap 'rm -f "${plaintext}"' EXIT
chmod 0600 "${plaintext}"
{
  echo "---"
  echo "secret_technitium_admin_password: \"${admin_password}\""
  if [[ "${letsencrypt_answer}" == "y" ]]; then
    echo "secret_cloudflare_dns_api_token: \"${cloudflare_token}\""
  fi
} > "${plaintext}"

(
  cd "${output}"
  sops --encrypt \
    --filename-override "${output}/group_vars/dns/secrets.sops.yml" \
    --input-type yaml --output-type yaml \
    --output "${output}/group_vars/dns/secrets.sops.yml" \
    "${plaintext}"
)

chmod 0600 "${output}/group_vars/dns/secrets.sops.yml"
chmod -R go-rwx "${output}"

trap - EXIT
rm -f "${plaintext}"

echo
echo "Created ${output}"
echo
echo "Next:"
echo "  make check-prod PROD_INVENTORY=${output}/hosts.yml"
echo "  make deploy-prod PROD_INVENTORY=${output}/hosts.yml"
echo
echo "After first boot, open the Technitium UI through NGINX and configure the"
echo "server domain, zones, forwarders, DHCP scopes, and users there."
echo "Ansible does not manage those settings."
