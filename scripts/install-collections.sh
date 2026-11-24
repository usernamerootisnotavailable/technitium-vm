#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${root}/collections"
galaxy="${ANSIBLE_GALAXY:-ansible-galaxy}"
attempts="${ANSIBLE_GALAXY_ATTEMPTS:-5}"

if [[ "${1:-}" == "--force" ]]; then
  rm -rf "${target}"
  shift
fi

for ((attempt = 1; attempt <= attempts; attempt++)); do
  if "${galaxy}" collection install \
    -r "${root}/requirements.yml" \
    -p "${target}" \
    "$@"; then
    exit 0
  fi

  if ((attempt < attempts)); then
    delay=$((attempt * 15))
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
      echo "::warning::Collection install failed (attempt ${attempt}); retrying in ${delay}s."
    else
      echo "Collection install failed (attempt ${attempt}); retrying in ${delay}s." >&2
    fi
    # A partial Galaxy install can leave an inconsistent directory.
    rm -rf "${target}"
    sleep "${delay}"
  fi
done

echo "Collection installation failed after ${attempts} attempts." >&2
exit 1
