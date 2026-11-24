# Variables

## Naming

- Role variables use the role name as a prefix: `technitium_*`, `nginx_*`, `common_*`, `podman_*`.
- Secret variables use `secret_*` and live only in SOPS files.
- Production values live only in the external private inventory.
- Variable names are identical in development and production.

## Precedence

| Value | Location |
| --- | --- |
| Safe role default | `roles/<role>/defaults/main.yml` |
| Role interface validation | `roles/<role>/meta/argument_specs.yml` |
| Development non-secret data | `inventories/dev/group_vars/` |
| Development secrets | `inventories/dev/group_vars/dns/secrets.sops.yml` |
| Production inventory | External private directory |
| Production secrets | External private SOPS file |
| Component versions | Dev and `inventories/prod.example` |

Do not duplicate a value across layers.

## Server-level production values

```yaml
# group_vars/all/main.yml
deployment_environment: prod
common_manage_time: true
common_firewall_enabled: true
common_require_selinux: true
common_firewall_zone: public
common_firewall_allowed_ssh_cidrs:
  - 10.20.10.0/24
common_ssh_allow_users:
  - ansible
common_admin_users: []

# group_vars/dns/network.yml
technitium_lan_interface: ens18
technitium_server_address: 10.20.0.5
technitium_firewall_lan_cidrs:
  - 10.20.0.0/24
technitium_firewall_zone: public
technitium_manage_firewall: true
technitium_firewall_allow_dhcp: false
nginx_allowed_cidrs:
  - 10.20.10.0/24

# group_vars/dns/tls.yml
nginx_server_name: dns01.example.com
nginx_tls_mode: letsencrypt
nginx_letsencrypt_email: admin@example.com
nginx_cloudflare_api_token: "{{ secret_cloudflare_dns_api_token | mandatory }}"
nginx_manage_firewall: true
```

The values above are examples only. Real values belong outside the public repository.

## Role variables

### technitium

| Variable | Default | Notes |
| --- | --- | --- |
| `technitium_version` | `15.6.2` | Inventory-owned |
| `technitium_image_digest` | required | Inventory-owned |
| `technitium_admin_password` | required | Bootstrap only |
| `technitium_web_local_addresses` | `[127.0.0.1]` | Must remain loopback |
| `technitium_manage_firewall` | `true` | DNS/DHCP services |
| `technitium_firewall_allow_dhcp` | `false` | Opens UDP 67 |
| `technitium_lan_interface` | required with firewall | Single LAN interface |
| `technitium_server_address` | required with firewall | Private static address |
| `technitium_firewall_lan_cidrs` | `[]` | Validation only |

### nginx

| Variable | Default | Notes |
| --- | --- | --- |
| `nginx_server_name` | required | Public FQDN for Let's Encrypt |
| `nginx_allowed_cidrs` | `[]` | Console administrators |
| `nginx_tls_mode` | `selfsigned` | `selfsigned`, `provided`, or `letsencrypt` |
| `nginx_letsencrypt_email` | `""` | Required for Let's Encrypt |
| `nginx_cloudflare_api_token` | `""` | Scoped token from SOPS |
| `nginx_certbot_version` | `5.10.0` | Pinned |
| `nginx_certbot_dns_cloudflare_version` | `5.10.0` | Pinned |
| `nginx_backend_url` | `http://127.0.0.1:5380` | Must stay loopback |

### podman

| Variable | Default | Notes |
| --- | --- | --- |
| `podman_version` | `6` | Major version assertion |
| `podman_dns_bind_port` | `20053` | Aardvark DNS port |

## Removed variables

These are intentionally not managed by Ansible:

- zones, records, reverse zones
- DHCP scopes, reservations, leases, options
- forwarders and recursion ACLs
- blocklists and apps
- Technitium users, groups, and API tokens
- application log/stat retention
- backups

Configure them in the Technitium web UI.

## Validation

- CIDRs, private addresses, and interface membership are validated by `roles/technitium/filter_plugins/network.py`.
- The Technitium role asserts a single private LAN interface with the default route.
- NGINX asserts Let's Encrypt inputs and rejects internal-only names.
- Roles have `meta/argument_specs.yml`.

## Check mode

Check mode is meaningful after the first convergence. On a blank host, user creation, package installation, container start, and certificates cannot be fully simulated.
