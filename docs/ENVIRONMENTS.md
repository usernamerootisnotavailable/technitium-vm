# Environments

## Principles

- Development and production use the same roles, playbooks, variable names, and
  task order.
- Only inventory data, credentials, endpoints, and documented capability flags
  differ.
- Roles never branch on environment name, hostname, IP, or inventory path.
- Production inventory and secrets live outside the public repository.

## Development

`inventories/dev/` targets the disposable AlmaLinux 10 systemd container:

- SSH on `127.0.0.1:2222`
- time management, firewalld, and SELinux enforcement disabled
- self-signed NGINX TLS
- no Technitium application configuration
- test-only DHCP proof creates and removes a temporary scope through the API

## Production

Production inventory is external, for example:

```text
~/.config/technitium-ansible/prod/
├── hosts.yml
├── host_vars/dns01/main.yml
├── group_vars/all/main.yml
├── group_vars/dns/network.yml
├── group_vars/dns/tls.yml
├── group_vars/dns/versions.yml
├── .sops.yaml
└── group_vars/dns/secrets.sops.yml
```

Create it with:

```bash
make init-prod
```

Production characteristics:

- real AlmaLinux 10 host
- single LAN interface with the default route
- private static address
- SELinux enforcing
- firewalld enabled
- SSH restricted to explicit source CIDRs
- DNS and DHCP on the LAN default zone
- HTTPS restricted to console administrator CIDRs
- Certbot with Cloudflare DNS-01 and Let's Encrypt
- application settings configured in the web UI

`inventories/prod.example/` is a public template using `example.com` and RFC1918
addresses. It is not a deployment inventory.

## Capability flags

| Flag | Dev | Prod | Purpose |
| --- | --- | --- | --- |
| `common_manage_time` | false | true | Chrony management |
| `common_firewall_enabled` | false | true | firewalld |
| `common_require_selinux` | false | true | SELinux assertion |
| `technitium_manage_firewall` | false | true | DNS/DHCP services |
| `technitium_firewall_allow_dhcp` | false | operator | Open UDP 67 |
| `nginx_tls_mode` | selfsigned | letsencrypt | Certificate source |

## Running production

```bash
export PROD_INVENTORY=~/.config/technitium-ansible/prod/hosts.yml
make check-prod PROD_INVENTORY="${PROD_INVENTORY}"
make deploy-prod PROD_INVENTORY="${PROD_INVENTORY}"
make verify-prod PROD_INVENTORY="${PROD_INVENTORY}"
```

The controller needs the production age private key and SSH access. No
production value is written to the public repository.

## Promotion

1. Run `make lint`, `make syntax`, and the affected Molecule scenario.
2. Run full integration on the development container.
3. Review the production diff and verify the private inventory.
4. Run `make check-prod`.
5. Apply during an approved window.
6. Run `make verify-prod`.
7. Configure or adjust application settings in the Technitium UI.
