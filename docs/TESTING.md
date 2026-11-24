# Testing

## Test layers

| Layer | Tool | What it proves |
| --- | --- | --- |
| Formatting | `yamllint` | YAML is valid and consistently formatted |
| Static analysis | `ansible-lint` production profile | Ansible best practices and common failure modes |
| Policy | `scripts/check-policy.sh` | No production inventory, app config, unpinned versions, or plaintext keys |
| Syntax | `ansible-playbook --syntax-check` | Playbooks, roles, modules, and inventory parse |
| Role behavior | Molecule with Docker | Converge, service health, idempotence |
| Full stack | `site.yml` on the dev container | Roles compose correctly |
| DHCP | `playbooks/tests/dhcp.yml` | Broadcast DISCOVER and lease allocation with a temporary scope |
| Security | `gitleaks`, policy checks | No plaintext credentials or private keys |
| Real host | Manual smoke test | SELinux, firewalld, physical DHCP, Certbot DNS-01 |

CI is the authoritative test environment. A local pass is necessary but not
sufficient.

## Commands

```bash
make lint          # yamllint, ansible-lint, policy checks
make syntax        # syntax-check every playbook
make test-image    # build the AlmaLinux 10 systemd test image
make molecule      # Molecule for common, podman, technitium, nginx
make integration   # site.yml, verify, DHCP proof, idempotence
make test          # lint + syntax + molecule
```

## Development container

`docker/dev/` builds a privileged AlmaLinux 10 systemd container with:

- systemd as PID 1
- Python 3 and sudo
- an `ansible` automation user
- OpenSSH
- `dhcpcd` for the DHCP proof
- `bind-utils`

It is a test harness only. Production uses Podman, not Docker.

Nested rootless Podman requires the container to be privileged with host cgroups.
If the CI runner cannot support that, run integration on a self-hosted AL10
runner or a disposable VM and record the gap.

## Test-only DHCP proof

`playbooks/tests/dhcp.yml` is an explicit exception to the no-app-config rule.
It:

1. logs in to the Technitium API with the development admin password
2. creates a veth pair and a DHCP client network namespace
3. creates and enables a temporary scope on `10.53.0.0/24`
4. runs `dhcpcd` in the namespace
5. asserts a lease in the test pool
6. always deletes the scope and removes the interfaces

It must never be imported by `site.yml` and must never run against production.

## Molecule

Each role has `molecule/default/` with:

- pinned test image
- privileged systemd container
- converge, idempotence, and verify

The scenarios disable only container-incompatible capabilities:

```yaml
common_manage_time: false
common_firewall_enabled: false
common_require_selinux: false
```

The Technitium scenario verifies container startup, API health, DNS port,
loopback console, rootless runtime, and the low-port sysctl. It does not
configure application data.

## Real-host acceptance

Before production:

1. Confirm SELinux is enforcing and `ausearch -m avc -ts recent` is clean.
2. Confirm SSH, DNS, DHCP, and HTTPS exposure from allowed and denied sources.
3. Confirm DNS resolves from a LAN client.
4. Confirm DHCP broadcast works on the physical LAN after configuring a scope in the UI.
5. Confirm Technitium survives reboot and starts before clients depend on it.
6. Confirm the console is unreachable except through NGINX from admin CIDRs.
7. Confirm `certbot renew --dry-run` succeeds.
8. Confirm the low-port sysctl is present.
9. Record the application configuration in the external operational system.
