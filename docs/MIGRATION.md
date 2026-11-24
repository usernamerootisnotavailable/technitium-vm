# Migration

Migration and application restore are performed through the Technitium web UI.
Ansible does not restore zones, records, DHCP scopes, users, or settings.

## Goal

Move an existing Technitium 15.x instance to the new AlmaLinux 10 host while
preserving DNS and DHCP data, then cut over the LAN address.

## Before migration

1. Record the old version.
2. Create a backup through the old Technitium console.
3. Store the archive outside the repository; it contains DNSSEC and TSIG keys.
4. Decide whether the new host will reuse the old IP. The supported plan is to
   build on a temporary static address and move to the old address at cutover.
5. Confirm the old DHCP server can be taken offline during the window.
6. Prepare the private production inventory with `make init-prod`.

## Build the new host

```bash
export PROD_INVENTORY=~/.config/technitium-ansible/prod/hosts.yml
make check-prod PROD_INVENTORY="${PROD_INVENTORY}"
make deploy-prod PROD_INVENTORY="${PROD_INVENTORY}"
```

Keep `technitium_firewall_allow_dhcp: false` until cutover. Do not configure
DHCP scopes in the UI yet.

## Restore through the UI

1. Open the console through NGINX from an administrator network.
2. Set the Technitium server domain.
3. Use the Technitium Restore Settings function with the backup archive.
4. Select the data you need: zones, DHCP scopes, apps, blocklists, and
   allowed/blocked zones.
5. Do not restore authentication or web service settings unless you have a
   specific reason; Ansible and the new host own the bootstrap credentials and
   the loopback web binding.
6. Keep every restored DHCP scope disabled.
7. Verify sample zones, records, DNSSEC state, scopes, and reservations.

## Cutover to the old IP

1. Take a final backup of the old instance.
2. Disable the old DHCP server.
3. Power off the old instance.
4. Assign the production static IP to the new host.
5. Run `site.yml` and verify DNS listen endpoints and the private LAN address.
6. In the Technitium UI, confirm the DHCP scope matches the new static interface.
7. Set `technitium_firewall_allow_dhcp: true` in the private inventory.
8. Run `make deploy-prod`.
9. Enable the DHCP scope in the UI.
10. Renew a real client lease and verify DNS.
11. Keep the old host and final archive as cold standby.

Changing the host IP may terminate the Ansible SSH connection. Use console or
IPMI access, a management interface, or reconnect using the new address.

## Rollback

1. Power off the new host.
2. Power on the old host.
3. Re-enable old DHCP.
4. Verify clients renew.
5. Keep the new host powered off until the failure is understood.

Do not run both DHCP servers on the same L2 segment.
