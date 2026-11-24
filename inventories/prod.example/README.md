# Production inventory template

This directory is a **template**, not a usable production inventory. It uses
`example.com`, `10.20.0.0/24`, and `192.0.2.10` so the public repository never
contains a real FQDN, public address, or internal network.

Do not place production values under `inventories/prod/` in this repository.
`inventories/prod/` is ignored and policy-checked.

Recommended workflow:

```bash
./scripts/init-prod-inventory.sh ~/.config/technitium-ansible/prod
```

The helper copies this template outside the repo, asks for the server, LAN,
admin, DNS, and Let's Encrypt values, and creates the SOPS-encrypted secrets
file.

Then run:

```bash
make check-prod PROD_INVENTORY=~/.config/technitium-ansible/prod/hosts.yml
make deploy-prod PROD_INVENTORY=~/.config/technitium-ansible/prod/hosts.yml
```

## Files

| File | Purpose |
| --- | --- |
| `hosts.yml` | SSH connection |
| `host_vars/dns01/main.yml` | Host-specific overrides |
| `group_vars/all/main.yml` | Baseline and SSH policy |
| `group_vars/dns/network.yml` | LAN interface, server address, firewall |
| `group_vars/dns/tls.yml` | NGINX, Certbot, Cloudflare, Let's Encrypt |
| `group_vars/dns/versions.yml` | Pinned component versions |
| `.sops.yaml` | Age recipient for this inventory |
| `group_vars/dns/secrets.sops.yml` | Encrypted admin and Cloudflare secrets |

Application settings — zones, DHCP scopes, forwarders, recursion, users, and
blocklists — are configured in the Technitium web UI, not here.
