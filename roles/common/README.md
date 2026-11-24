# common

AlmaLinux 10 baseline for the Technitium DNS and DHCP host.

The role configures:

- platform assertion
- baseline packages
- timezone and chrony
- optional administrator accounts and SSH keys
- SSH hardening through `/etc/ssh/sshd_config.d/99-technitium-host.conf`
- firewalld with source-CIDR SSH rules and no broad SSH service
- persistent systemd journal
- SELinux enforcement when the platform reports SELinux enabled

## Requirements

- AlmaLinux 10
- systemd
- a bootstrap automation account with sudo

## Key variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `common_timezone` | `UTC` | System timezone |
| `common_manage_time` | `true` | Manage chrony |
| `common_firewall_enabled` | `true` | Manage firewalld |
| `common_firewall_allowed_ssh_cidrs` | `[]` | Required source CIDRs when firewalld is managed |
| `common_admin_users` | `[]` | Optional human administrators |
| `common_ssh_allow_users` | `[ansible]` | SSH allow-list |
| `common_require_selinux` | `true` | Fail when SELinux is disabled |

See `meta/argument_specs.yml` for the complete interface.

## Testing

Molecule disables time, firewall, and SELinux enforcement because the Docker
harness cannot faithfully exercise them. The real-host verification checklist
in `docs/TESTING.md` covers those paths.

## Known limitations

The development container does not enforce SELinux or nftables behavior.
Firewall and SELinux changes require a real AlmaLinux 10 host.
