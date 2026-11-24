#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Compose interpolates the full file for down as well. The SSH key mount is
# only needed for up, so use a harmless source when no container was started.
export DEV_SSH_PUBKEY="${DEV_SSH_PUBKEY:-/dev/null}"

docker compose -f "${root}/docker/dev/compose.yml" down --remove-orphans
