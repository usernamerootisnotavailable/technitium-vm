# technitium

Installs Technitium DNS Server in rootless Podman. It does **not** manage
Technitium application settings. Zones, records, DHCP scopes, forwarding,
recursion, blocklists, users, and tokens are configured in the Technitium web
UI.

The role:

- creates the unprivileged `technitium` service account and subordinate IDs
- applies the documented low-port sysctl needed for DNS 53 and DHCP 67
- stores the bootstrap admin password in a Podman secret
- installs a user-scoped Quadlet unit with host networking and a read-only root filesystem
- starts the service through the service user's systemd manager
- keeps the web console on loopback for the NGINX role
- opens DNS and, when requested, DHCP on the single LAN firewalld zone
- verifies the container, API health, DNS port, loopback console, rootless
  runtime, sysctl, and firewall exposure

## Requirements

- AlmaLinux 10
- the `podman` role
- a single LAN interface with the default route and a static private address
- `net.ipv4.ip_unprivileged_port_start=53` accepted as a host-wide exception

## Key variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `technitium_version` | `15.6.2` | Pinned image tag |
| `technitium_image_digest` | required | Pinned image digest |
| `technitium_admin_password` | required | Bootstrap-only admin password |
| `technitium_web_local_addresses` | `[127.0.0.1]` | Must remain loopback |
| `technitium_manage_firewall` | `true` | Manage DNS/DHCP services |
| `technitium_firewall_allow_dhcp` | `false` | Open UDP 67 on the LAN zone |
| `technitium_lan_interface` | required with firewall | LAN interface |
| `technitium_server_address` | required with firewall | Static LAN address |

See `meta/argument_specs.yml` for the complete interface.

## Data layout

| Host path | Container path | Purpose |
| --- | --- | --- |
| `/var/lib/technitium/config` | `/etc/dns` | Config, zones, scopes, keys |
| `/var/log/technitium/dns` | `/var/log/technitium/dns` | Logs |

Backups and migration are external to this repository.

## Rootless low-port exception

Rootless containers cannot bind ports 53 and 67 in the host network namespace
without lowering `net.ipv4.ip_unprivileged_port_start`. The role writes
`/etc/sysctl.d/90-technitium-rootless.conf` with value `53`.

This means any local unprivileged process can bind ports 53 through 1023. The
host must remain a dedicated appliance.

## DHCP

Ansible only opens firewall port 67 when `technitium_firewall_allow_dhcp` is
true. Enabling DHCP and configuring scopes is done in the Technitium web UI.
Technitium requires the matching interface to have a static IPv4 address.

## First login

The container starts with the bootstrap admin password from the Podman secret.
Set the server domain and all other application settings in the web UI. Ansible
will not reconcile them afterward.

## Testing

Molecule runs the role in a privileged AlmaLinux 10 systemd container with
nested rootless Podman. It verifies container startup, API health, DNS port,
loopback console, rootless runtime, and the low-port sysctl. It does not
configure zones or DHCP scopes.

A separate test-only playbook under `playbooks/tests/` uses the API to prove DHCP
on a veth pair. It is never imported into `site.yml`.
