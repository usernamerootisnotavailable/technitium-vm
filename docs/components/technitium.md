# Technitium DNS Server

## Role

`roles/technitium`

## Image

- Repository: `docker.io/technitium/dns-server`
- Tag: `15.6.2`
- Digest: `sha256:eb48ac5c135f4ab936b536f74f853d53e15ab39ef37fdbc9598a089b90d9f245`

The image is pinned by tag and digest. Never use `latest`.

## Runtime

- Rootless Podman
- User-scoped Quadlet under `~technitium/.config/containers/systemd/`
- `Network=host`
- read-only root filesystem
- no capabilities
- no-new-privileges
- Podman secret for the bootstrap admin password

Container UID 0 is mapped to the unprivileged `technitium` host user.

## Ports

| Port | Protocol | Bind | Purpose |
| --- | --- | --- | --- |
| 53 | TCP/UDP | host | DNS |
| 67 | UDP | host, when configured | DHCP |
| 5380 | TCP | loopback | Web console and API |

DNS-over-TLS, DNS-over-HTTPS, and DNS-over-QUIC are not enabled by this role.

## Data and logs

| Host path | Container path |
| --- | --- |
| `/var/lib/technitium/config` | `/etc/dns` |
| `/var/log/technitium/dns` | `/var/log/technitium/dns` |

The config directory contains zone files, DNSSEC private keys, TSIG keys, DHCP
scopes, auth configuration, and app data. Mode is `0700` owned by the service
user.

## Application ownership

Ansible sets only the bootstrap values needed for a safe first install:

- initial admin password
- loopback web binding
- web HTTP port
- Technitium HTTPS disabled
- log directory

Everything else is configured in the web UI:

- server domain
- forwarders and recursion ACLs
- DNSSEC and blocklists
- zones, records, reverse zones
- DHCP scopes, reservations, and leases
- users, groups, API tokens, 2FA
- query logging and stats retention

## Low-port exception

Rootless containers cannot bind 53 and 67 in the host network namespace without
lowering the unprivileged port floor. The role writes:

```text
net.ipv4.ip_unprivileged_port_start=53
```

This is a host-wide change. It is required for DHCP. The host is a dedicated
appliance. The policy script confines this variable to the technitium role.

## DHCP

- DHCP is configured in the UI.
- Ansible only opens UDP 67 when `technitium_firewall_allow_dhcp` is true.
- Technitium requires a static IPv4 address on the matching interface.
- The host must have a single LAN interface with the default route.
- DHCP cannot be clustered. Do not run two active servers on one L2 segment.

## Firewall

- DNS is allowed as a service on the LAN default zone.
- DHCP is allowed only when explicitly enabled.
- HTTPS is handled by the NGINX role and restricted to console administrator CIDRs.

## SELinux

- Container runs as `container_t`.
- Bind mounts use `:Z`.
- Real-host verification must confirm no AVC denials on 53/67 binding and volume
  access.

## Verification

- user service active
- API status healthy
- 53 listening
- 5380 loopback-only
- Podman rootless
- low-port sysctl active
- DNS firewall service enabled
- DHCP firewall state matches inventory

## Known gaps

- The container harness cannot prove physical switch, VLAN, or firewalld
  broadcast behavior.
- The pinned image runs as root inside the container; rootless Podman maps that
  to the unprivileged host user.
- Application settings are not version-controlled by Ansible.
