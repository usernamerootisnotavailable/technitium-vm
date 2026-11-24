# podman

Installs and configures the rootless Podman runtime used by Technitium.

The role:

- installs the pinned Podman major version
- installs rootless networking and storage helpers
- writes `/etc/containers/containers.conf.d/99-technitium.conf`
- moves Aardvark DNS off port 53 so it cannot conflict with Technitium
- verifies the installed major version

## Requirements

- AlmaLinux 10
- dnf repositories enabled

## Key variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `podman_version` | `6` | Pinned major version |
| `podman_packages` | rootless helpers | Additional runtime packages |
| `podman_dns_bind_port` | `20053` | Aardvark DNS port |
| `podman_manage_containers_conf` | `true` | Manage the containers.conf drop-in |

## Notes

Rootless Podman still requires the service user to have `subuid` and `subgid`
ranges. The `technitium` role owns that account configuration.

The development container is privileged so it can run nested rootless Podman.
The production host must keep SELinux enforcing.
