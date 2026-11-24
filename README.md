# Technitium DNS and DHCP Host

Ansible configuration for a single AlmaLinux 10 host running Technitium DNS Server in rootless Podman. The host provides DNS and DHCP to a LAN, and the Technitium web console is published through NGINX over HTTPS with a Let's Encrypt certificate.

Ansible owns installation, server hardening, network exposure, certificate lifecycle, and maintenance updates. **Technitium application settings are managed in the web UI**, not in Ansible.

## Current status

| Area | Status |
| --- | --- |
| Repository scaffolding, lint, policy, and documentation | Implemented |
| `common` AlmaLinux 10 baseline | Implemented |
| `podman` rootless runtime | Implemented |
| `technitium` container install and hardening | Implemented |
| `nginx` private HTTPS console proxy | Implemented |
| Certbot with Cloudflare DNS-01 and Let's Encrypt | Implemented |
| External production inventory workflow | Implemented |
| Test-only DHCP proof | Implemented |
| Molecule and full-stack integration tests | Implemented for the container harness |

`site.yml` applies `common`, Podman, Technitium, NGINX, and verification in dependency order.

## Ownership boundary

Ansible manages:

- AlmaLinux baseline, packages, SSH, chrony, journald
- SELinux and firewalld
- rootless Podman and the low-port sysctl
- the pinned Technitium container, bootstrap admin password, and loopback console
- NGINX TLS and Certbot/Cloudflare/Let's Encrypt
- OS security updates and pinned image updates
- health checks and deployment verification

Configured in the Technitium web UI:

- server domain, forwarders, recursion, DNSSEC
- zones, records, reverse zones
- DHCP scopes, options, reservations, leases
- blocklists, apps, users, groups, API tokens
- query logging and stats retention
- migration restore from an existing instance

## Security model

- Technitium runs rootless with `Network=host`.
- DHCP requires broadcast access, so host networking is mandatory.
- Rootless containers cannot bind 53 and 67 without `net.ipv4.ip_unprivileged_port_start=53`. This is a documented, host-wide exception.
- The web console binds to `127.0.0.1:5380`; NGINX terminates TLS on 443.
- The host is supported as a single LAN-only interface with a private static address. DNS and DHCP are opened on the LAN firewalld zone. HTTPS is restricted to `nginx_allowed_cidrs`.
- SELinux remains enforcing.
- Backup and disaster recovery are outside this project.

## Supported platform

- AlmaLinux 10 x86_64
- Ansible core 2.22+
- Python 3.12+ on managed hosts
- systemd, SELinux, and firewalld
- Podman 6.x
- Technitium DNS Server 15.6.2, pinned by image digest

## Public repository and private production inventory

Production inventory is **not committed here**. Real FQDNs, public addresses, internal CIDRs, and hostnames live outside the repository.

Generate a private inventory:

```bash
make init-prod
```

The helper writes to `~/.config/technitium-ansible/prod` by default and creates
SOPS-encrypted secrets. See
[`inventories/prod.example/README.md`](inventories/prod.example/README.md).

## Quick start

On the controller:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements-dev.txt
ansible-galaxy collection install -r requirements.yml -p ./collections

make lint
make syntax

# Development container
make dev-up
make secrets-dev
make deploy-dev
make verify
```

Development uses self-signed TLS. Production uses Certbot/Cloudflare/Let's
Encrypt.

## Development

```bash
make dev-up
make deploy-dev
make verify
make integration
```

`make integration` applies the host, verifies it, runs a temporary test-only DHCP scope, and confirms the second run is idempotent.

## Production

```bash
make check-prod PROD_INVENTORY=~/.config/technitium-ansible/prod/hosts.yml
make deploy-prod PROD_INVENTORY=~/.config/technitium-ansible/prod/hosts.yml
make verify-prod PROD_INVENTORY=~/.config/technitium-ansible/prod/hosts.yml
```

The controller needs the production age private key, SSH access, and the
private inventory. No production values or secrets enter this repository or
CI.

## Maintenance and updates

OS security updates:

```bash
make update-prod PROD_INVENTORY=~/.config/technitium-ansible/prod/hosts.yml
# Allow a reboot when needed:
make update-prod PROD_INVENTORY=... REBOOT=true
```

Technitium image updates are explicit: change `technitium_version` and
`technitium_image_digest` in the private inventory, then reconcile. Take an
application-level backup through the UI or external platform before an app
version change.

## Documentation

| Document | Purpose |
| --- | --- |
| [`AGENTS.md`](AGENTS.md) | Hard rules for all future work |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Topology, decisions, repository layout, security baseline |
| [`docs/VARIABLES.md`](docs/VARIABLES.md) | Server-level variables and external inventory |
| [`docs/SECRETS.md`](docs/SECRETS.md) | SOPS/age workflow, Cloudflare token, key custody |
| [`docs/ENVIRONMENTS.md`](docs/ENVIRONMENTS.md) | dev/private-prod workflow and promotion |
| [`docs/TESTING.md`](docs/TESTING.md) | Test layers, test-only DHCP proof, real-host gaps |
| [`docs/MIGRATION.md`](docs/MIGRATION.md) | UI-only migration and cutover |
| [`docs/OPERATIONS.md`](docs/OPERATIONS.md) | Updates, certificates, logs, emergency stop |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | Change workflow and review checklist |
| [`docs/COMPONENTS.md`](docs/COMPONENTS.md) | Component contracts and verified platform data |
| [`docs/components/technitium.md`](docs/components/technitium.md) | Technitium role reference |
| [`docs/components/nginx.md`](docs/components/nginx.md) | NGINX, Certbot, Cloudflare, and Let's Encrypt |

## Non-negotiables

1. No plaintext secrets, private keys, or production inventory in the repository.
2. No real FQDN, public IP, internal CIDR, or hostname in the public repo.
3. Application configuration is done in the Technitium web UI, not in Ansible.
4. Pin the Technitium image by tag and digest. Pin collections and Python tools.
5. Keep SELinux enforcing and firewalld enabled in production.
6. Keep the Technitium console on loopback; only NGINX exposes HTTPS to admin CIDRs.
7. Keep the host on a single LAN interface. DHCP and DNS are exposed on the LAN firewalld zone.
8. `technitium_firewall_allow_dhcp` opens UDP 67; leave it false until DHCP is intended.
9. Every change must be idempotent, linted, tested, and documented.

## License

MIT. See [`LICENSE`](LICENSE).
