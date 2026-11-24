# Components

| Component | Role | Purpose | Source | Version policy |
| --- | --- | --- | --- | --- |
| AlmaLinux baseline | `common` | OS baseline, SSH, firewalld, SELinux, time, journald | AlmaLinux 10 repositories | Distribution |
| Podman | `podman` | Rootless container runtime and Quadlet | AlmaLinux 10 AppStream | Major version pinned |
| Technitium DNS Server | `technitium` | DNS, DHCP, web API | Official container image | Tag + digest |
| NGINX | `nginx` | Private TLS console proxy | AlmaLinux 10 AppStream | Major version pinned |
| Certbot | `nginx` | Let's Encrypt DNS-01 | PyPI virtualenv | Exact version pinned |

## Verified platform data

| Item | Value |
| --- | --- |
| OS | AlmaLinux 10 x86_64 |
| Technitium image | `docker.io/technitium/dns-server:15.6.2` |
| Technitium digest | `sha256:eb48ac5c135f4ab936b536f74f853d53e15ab39ef37fdbc9598a089b90d9f245` |
| Podman | 6.x |
| NGINX | 1.26.x |
| Certbot | 5.10.0 |
| certbot-dns-cloudflare | 5.10.0 |

## Component contracts

Every component:

- has a role with defaults, handlers, metadata, argument specs, tasks, and README
- is independently runnable where practical
- installs its own target-side dependencies
- supports check mode where practical
- is idempotent on a second run
- keeps environment data out of role logic
- documents SELinux, firewall, and verification requirements

## Network exposure

| Port | Protocol | Source | Purpose |
| --- | --- | --- | --- |
| 53 | TCP/UDP | LAN zone | DNS |
| 67 | UDP | LAN zone, only when enabled | DHCP |
| 443 | TCP | Console administrator CIDRs | NGINX console TLS |
| 22 | TCP | SSH CIDRs | Administration |
| 5380 | TCP | Loopback only | Technitium console and API |

## Data ownership

| Path | Owner | Purpose |
| --- | --- | --- |
| `/var/lib/technitium` | `technitium` | Service home and Podman state |
| `/var/lib/technitium/config` | `technitium` | Technitium `/etc/dns` |
| `/var/log/technitium` | `technitium` | Logs |
| `/etc/letsencrypt` | `root` | Certbot state and Cloudflare credentials |

Application data backup and disaster recovery are external to this project.

## Adding a component

See `docs/ARCHITECTURE.md#adding-a-service`. Do not add a new network exposure
without a component entry and security review.
