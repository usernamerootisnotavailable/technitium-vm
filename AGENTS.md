# Agent and Contributor Rules

This file is the short, enforceable rulebook for every change in this repository. Read it before editing any file.

## Required reading order

1. `README.md`
2. `AGENTS.md` (this file)
3. `docs/ARCHITECTURE.md`
4. `docs/VARIABLES.md`
5. `docs/SECRETS.md`
6. `docs/ENVIRONMENTS.md`
7. `docs/TESTING.md`
8. `docs/MIGRATION.md`
9. `docs/OPERATIONS.md`
10. `docs/CONTRIBUTING.md`
11. `docs/COMPONENTS.md`
12. The relevant file in `docs/components/`

If a rule is unclear, stop and ask. Do not invent a new convention silently.

## Hard rules

### Secrets and production data

- Never commit plaintext passwords, tokens, private keys, age identities, or decrypted SOPS output.
- Never commit a production inventory, real FQDN, public IP, internal CIDR, or hostname.
- Never place a production inventory under `inventories/prod/`.
- Never commit a Technitium backup zip. Migration archives contain DNSSEC keys, TSIG keys, DHCP data, and optionally authentication data.
- Never run `sops --decrypt` with output redirected to a file in the repository or a shared temporary directory.
- Never paste decrypted values into chat, issue trackers, pull requests, logs, or commit messages.
- Never add, remove, or change a recipient in a production SOPS file without a security review.
- Never place an age private key on a managed host. Decryption happens on the controller.
- Test secrets must be generated at runtime and must never be reused outside tests.
- Tasks that handle API tokens or passwords must use `no_log: true`.

### Scope boundary

- Ansible manages installation, server hardening, network exposure, TLS, updates, and health checks.
- Ansible does not manage Technitium settings, zones, records, DHCP scopes, forwarding, blocklists, users, or API tokens.
- The only app-adjacent bootstrap values are the initial admin password, loopback web binding, web HTTP port, HTTPS disabled inside Technitium, and the log directory.
- The test-only DHCP playbook under `playbooks/tests/` is the only allowed API configuration exception. It must never be imported by `site.yml`.
- Migration is performed through the Technitium web UI.

### Environment independence

- Roles and playbooks must not branch on environment name, hostname, IP address, domain, or inventory path.
- `deployment_environment` is metadata only. It must not appear in a `when:`, template conditional, or path.
- Use capability or sizing variables instead of environment names.
- Use the same variable names, group names, logical hostnames, paths, and task order in every environment.
- Do not use `extra_vars` for normal configuration. It is allowed only for ephemeral test secrets, update flags, and documented emergency overrides.
- Do not read environment-specific files from inside a role.

### Versions and dependencies

- Pin every collection in `requirements.yml`.
- Pin every Python tool in `requirements-dev.txt`.
- Pin container images by tag and digest. Never use `latest`.
- Pin component major versions in inventory; never use `state: latest` for packages outside the security update playbook.
- Do not silently upgrade a component as part of an unrelated change.
- Do not vendor GPL-licensed collection code into this MIT repository.

### Platform and security

- Target AlmaLinux 10 only.
- Never disable SELinux or set it permissive to make a task pass.
- Never disable firewalld or open a port to the world to make a test pass.
- Never set `host_key_checking = False`, `StrictHostKeyChecking=no`, or disable GPG signature checks.
- Never run the Technitium container privileged.
- Keep the Technitium web console bound to loopback. Expose it only through NGINX over HTTPS to explicit administrator CIDRs.
- The project supports one LAN interface with the default route. Do not add multi-homed or VLAN support without an architecture decision and a dedicated firewalld zone.
- `technitium_firewall_allow_dhcp` is the only switch that opens UDP 67. Do not open it implicitly.
- The rootless low-port sysctl is a documented exception. It may only be introduced by the `technitium` role.
- Use dedicated service users with no login shell.
- Configuration files containing secrets must be mode `0600` or `0640` with a restrictive group.
- Do not put secrets in process arguments. Use files or Podman secrets with restrictive permissions.

### Code quality

- Use fully qualified collection names (FQCN) for every module, role, and plugin.
- Use modules instead of `shell`/`command`. If a command is unavoidable, use `argv`, add `changed_when` or `creates`, and explain why.
- Do not add `ignore_errors: true` or `failed_when: false` to hide a failure.
- Handlers must restart services only after configuration changes.
- Every role must have `meta/argument_specs.yml`, `defaults/main.yml`, and a README.
- Every task must be idempotent. The second run must report `changed=0`.
- Check mode must not modify the target. Read-only commands may set `check_mode: false`; mutating commands may not.
- Keep role defaults safe and complete. Do not put environment data in role defaults.

## Where values belong

| Value | Location |
| --- | --- |
| Safe role default | `roles/<role>/defaults/main.yml` |
| Role interface validation | `roles/<role>/meta/argument_specs.yml` |
| Development non-secret data | `inventories/dev/group_vars/` |
| Development secrets | `inventories/dev/group_vars/dns/secrets.sops.yml` |
| Production inventory | External private directory, never the repo |
| Production secrets | External private inventory, SOPS-encrypted |
| Component versions | Development inventory and `inventories/prod.example` |
| Network and TLS values | External `group_vars/dns/network.yml` and `tls.yml` |

Never duplicate a value across layers. Set only what differs from the role default.

## Forbidden patterns

```yaml
# Production data in the public repo
ansible_host: 203.0.113.10
nginx_server_name: dns01.example.org
technitium_server_address: 10.0.0.5

# App configuration in Ansible
technitium_dhcp_scopes: []
technitium_zones: []
/api/settings/set
/api/dhcp/scopes/set

# Unpinned versions outside the security update playbook
state: latest
image: technitium/dns-server:latest

# Secret exposure
debug:
  var: technitium_admin_password
no_log: false

# Hidden failures
ignore_errors: true
failed_when: false

# Unsafe container or console exposure
privileged: true
SecurityOpt: label=disable
webServiceLocalAddresses: 0.0.0.0
```

## Required checks before finishing

Run the checks that apply to the change; do not report success for checks you did not run.

```bash
make lint          # yamllint, ansible-lint, policy checks
make syntax        # ansible-playbook --syntax-check
make molecule      # role converge, verify, idempotence (requires Docker)
make integration   # full playbook on the dev container (requires Docker)
```

At minimum, every change must pass `make lint` and `make syntax`. Changes to a role must also pass that role's Molecule scenario. Changes to `site.yml` or inventory must pass integration.

## Definition of done

A change is complete only when:

- The implementation follows every rule in this file.
- Variables are documented in `meta/argument_specs.yml` and the role README.
- No plaintext secret or production value is added; `gitleaks` passes.
- The second run is idempotent (`changed=0`).
- `--check --diff` is clean on the development environment.
- Molecule and integration tests pass for the affected roles.
- SELinux and firewall changes have a real-host verification plan.
- Production impact and rollback steps are documented for destructive changes.
- Documentation is updated in the same commit.

## Scope guardrails

- Do not add a new service, package repository, or network exposure without an approved component entry in `docs/COMPONENTS.md`.
- Do not change the single-host or single-LAN-interface topology without an architecture decision.
- Do not run a playbook against production without explicit human approval.
- Do not add application configuration to `site.yml`.
- Do not add `playbooks/tests/dhcp.yml` to `site.yml`.
- Do not commit generated files, caches, collections, virtual environments, backup archives, or test images.
