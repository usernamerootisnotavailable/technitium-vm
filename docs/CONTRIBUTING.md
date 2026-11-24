# Contributing

## Workflow

1. Read `AGENTS.md` and the relevant component document.
2. Create a branch.
3. Make the smallest coherent change.
4. Update defaults, argument specs, README, and docs together.
5. Run the required checks.
6. Open a pull request with verification evidence.

## Required checks

```bash
make lint
make syntax
make molecule   # affected roles
make integration
```

Do not report a check as passing if it was not run. Real-host-only gaps must be
recorded with a verification plan.

## Review checklist

- No plaintext secrets, backup archives, or production inventory
- No real FQDN, public IP, internal CIDR, or hostname in the public repo
- No Technitium application configuration in roles or `site.yml`
- No environment branching
- Pinned image digest and collections
- Idempotent second run
- Check mode safe or documented
- SELinux and firewalld remain enforcing
- Console remains loopback-only
- Single LAN interface assumption preserved
- DHCP firewall remains opt-in
- Test-only DHCP playbook is not in `site.yml`
- Documentation updated

## Commit scope

Do not combine:

- a Technitium version bump
- an unrelated firewall change
- a certificate lifecycle change
- a test-harness change

Each should be reviewable and reversible on its own.

## Destructive changes

For anything that can take DNS or DHCP down:

- document the external backup/restore dependency
- document the rollback
- state the maintenance window impact
