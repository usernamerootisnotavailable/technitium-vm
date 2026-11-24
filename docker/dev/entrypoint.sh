#!/usr/bin/env bash
set -euo pipefail

if [[ -f /tmp/authorized_keys ]]; then
  install -d -m 0700 -o ansible -g ansible /home/ansible/.ssh
  install -m 0600 -o ansible -g ansible /tmp/authorized_keys /home/ansible/.ssh/authorized_keys
fi

exec /usr/sbin/init
