# Architecture

## Purpose

This repository configures one AlmaLinux 10 host as a Technitium DNS and DHCP server. Technitium runs in rootless Podman with host networking because DHCP must receive layer-2 broadcast traffic.

Ansible owns installation, hardening, network exposure, TLS, and maintenance. Technitium application settings are managed in the web UI.

## Locked decisions

| Decision | Choice | Consequence |
| --- | --- | --- |
| Secret management | SOPS + age | Encrypted secrets live in dev or in the external production inventory |
| Production inventory | External private directory | No real production data in the public repository |
| Topology | One DNS/DHCP host per environment | No clustering or multi-host orchestration |
| Runtime | Rootless Podman + Quadlet | No Docker daemon; service user owns the container |
| DHCP networking | Host network | Container sees LAN broadcasts and real client addresses |
| Host network layout | Single LAN interface with default route | DNS and DHCP are safe on the default firewalld zone |
| Low ports | `net.ipv4.ip_unprivileged_port_start=53` | Documented host-wide security exception |
| Console exposure | NGINX HTTPS on administrator CIDRs | Technitium console stays loopback-only |
| TLS | Certbot + Cloudflare DNS-01 + Let's Encrypt | No inbound port 80; public DNS name required |
| Application configuration | Technitium web UI | Ansible does not manage zones, records, or DHCP scopes |
| Migration | UI restore | No import automation in this repository |
| Backups | Out of scope | Handled by the external platform |

These decisions require an explicit architecture review to change.

## Topology

```text
                   LAN clients
          DHCP 67/UDP     DNS 53/UDP+TCP
                    │
          ┌─────────▼─────────┐
          │   firewalld       │
          │  dns, dhcp, 443   │
          └─────────┬─────────┘
                    │
          ┌─────────▼──────────────────────────┐
          │        dns01 (AlmaLinux 10)        │
          │                                    │
          │  rootless Podman, host network     │
          │    Technitium                       │
          │      53/tcp,udp  DNS                │
          │      67/udp      DHCP               │
          │      127.0.0.1:5380 console         │
          │                                    │
          │  nginx + Certbot                   │
          │      443/tcp     console TLS        │
          │                                    │
          │  local disk                         │
          │    /var/lib/technitium              │
          │    /var/log/technitium              │
          └────────────────────────────────────┘
                    ▲
                    │ HTTPS + administrator CIDRs
                 admin browser
```

- Technitium binds DNS and DHCP on the host network namespace because DHCP needs broadcasts.
- NGINX listens on 443 and proxies only to `127.0.0.1:5380`.
- The Technitium console must never bind a non-loopback address.
- There is no high availability. A host loss takes DNS and DHCP down. The external platform owns backup and recovery.

## Ansible and application boundary

Ansible bootstraps the container with:

- the bootstrap admin password
- loopback web binding
- the HTTP port used by NGINX
- Technitium HTTPS disabled
- the persistent log directory

These environment variables are read by Technitium only when it creates its configuration for the first time. Ansible does not reconcile them afterward.

All other settings are made in the web UI:

- server domain
- forwarders, recursion ACLs, DNSSEC
- zones, records, reverse zones
- DHCP scopes, reservations, leases
- blocklists, apps, users, groups, API tokens
- query logging and stats retention

## Repository layout

```text
ansible.cfg                 Controller behavior and default development inventory
roles/technitium/filter_plugins/  CIDR and private-address validation
requirements.yml            Pinned Ansible collections
requirements-dev.txt        Pinned lint and test tooling
site.yml                    Full host convergence
playbooks/common.yml        Baseline
playbooks/podman.yml        Rootless runtime
playbooks/technitium.yml    Container install and hardening
playbooks/nginx.yml         Console proxy and certificates
playbooks/verify.yml        Health checks
playbooks/update.yml        Security updates and optional reboot
playbooks/tests/dhcp.yml    Test-only API-backed DHCP proof
roles/                      common, podman, technitium, nginx
inventories/dev/            Safe development values only
inventories/prod.example/   Public templates; no real production values
scripts/                    Setup, dev, integration, and policy tooling
docker/dev/                 AlmaLinux 10 systemd development image
docs/                       Normative project documentation
```

## Playbook flow

`site.yml` imports, in order:

1. `common` — baseline, access, time, firewall, journald, SELinux
2. `podman` — pinned major runtime and Aardvark DNS port
3. `technitium` — service account, sysctl, secret, Quadlet, firewall, health
4. `nginx` — HTTPS console proxy and certificate lifecycle
5. `verify` — observable health checks

The update playbook and test-only DHCP proof are separate.

## Rootless design

- Service account `technitium` has no login shell and owns the data directories.
- User Quadlet lives in `~/.config/containers/systemd/technitium.container`.
- The role starts `user@<uid>.service` explicitly, so the service manager exists even in a container without logind.
- The container uses `Network=host`, a read-only root filesystem, no capabilities, no-new-privileges, and a Podman secret for the bootstrap admin password.
- Container UID 0 is mapped to the unprivileged `technitium` host user by Podman. It is not host root.

### Low-port exception

Rootless containers cannot bind ports 53 and 67 in the host network namespace. `CAP_NET_BIND_SERVICE` inside the container does not help because capabilities are namespaced and the host network namespace belongs to the initial user namespace. The role therefore sets:

```text
net.ipv4.ip_unprivileged_port_start=53
```

This allows any local unprivileged process to bind ports 53 through 1023. The host must remain a dedicated appliance. The exception is implemented only in the technitium role and enforced by the policy script.

## Firewall model

- Single LAN interface with the default route.
- The default firewalld zone is the LAN zone.
- `dns` is allowed as a service.
- `dhcp` is allowed only when `technitium_firewall_allow_dhcp` is true.
- HTTPS is allowed only from `nginx_allowed_cidrs`.
- SSH is allowed only from `common_firewall_allowed_ssh_cidrs`.
- The role asserts that the server address is private and on the LAN interface with the default route. It does not support public or multi-homed exposure.

## TLS

- Production uses Certbot with the Cloudflare DNS plugin and Let's Encrypt.
- The public FQDN, account email, and scoped Cloudflare token are supplied by the private inventory.
- The certificate is issued only when missing and renewed twice daily.
- NGINX reloads through a deploy hook.
- Development and CI use self-signed certificates.

## Security baseline

- SELinux stays enforcing.
- firewalld default-denies inbound traffic.
- The Technitium console is loopback-only.
- Podman is rootless; the container has no capabilities and uses a read-only rootfs.
- Secrets are decrypted on the controller and masked in Ansible output.
- Production inventory never enters the public repository.
- API automation is limited to the test-only DHCP proof.

## Scope and risks

- **Single point of failure:** one host per environment. External backup and recovery are required.
- **Rootless sysctl:** host-wide low-port change. Acceptable only on a dedicated appliance.
- **Single LAN interface:** no support for public or multi-homed exposure without a dedicated-zone architecture change.
- **Application settings:** not version-controlled by Ansible. Change control for zones, scopes, and users is operational or external.
- **Real-host verification:** SELinux, firewalld, DHCP broadcast, and Certbot DNS-01 require a real AL10 host.
- **No HA:** DNS and DHCP stop when the host stops.

## Adding a service

1. Verify the vendor supports AlmaLinux 10 and add the source to `docs/COMPONENTS.md`.
2. Pin the version and checksum in the development and example inventories.
3. Create the role contract and argument specs.
4. Add the Molecule scenario and verification tasks.
5. Add the playbook and import it into `site.yml` before verification.
6. Add firewall, TLS, and health requirements to the component document.
7. Update `README.md` status and the component table.
