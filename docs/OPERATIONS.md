# Operations

## Health

```bash
make verify-prod PROD_INVENTORY=~/.config/technitium-ansible/prod/hosts.yml
```

Checks:

- Technitium user service active
- API status healthy
- DNS listening on 53
- console loopback-only
- rootless Podman
- low-port sysctl
- DNS firewall service
- DHCP firewall state matching inventory
- NGINX service and certificate material
- HTTPS response through NGINX
- Certbot timer when Let's Encrypt is enabled

## Console access

The Technitium console is bound to `127.0.0.1:5380`. Use the NGINX HTTPS
endpoint from an administrator CIDR, or tunnel it over SSH:

```bash
ssh -L 5380:127.0.0.1:5380 <admin>@dns01
```

Then open `http://127.0.0.1:5380` locally. Do not expose port 5380 directly.

## Application administration

Configure in the Technitium web UI:

- server domain and DNS settings
- forwarders, recursion ACLs, DNSSEC
- zones, records, reverse zones
- DHCP scopes and reservations
- blocklists and apps
- users, groups, API tokens, 2FA

Ansible does not reconcile these settings.

## Certificates

Production uses Certbot with Cloudflare DNS-01 and Let's Encrypt.

- credentials: `/etc/letsencrypt/cloudflare.ini`, mode `0600`
- renewal: `certbot-renew.timer`, twice daily
- deploy hook copies the certificate to NGINX and reloads it
- test renewal: `sudo /opt/certbot/bin/certbot renew --dry-run`

No inbound port 80 is required.

## OS updates

```bash
make update-prod PROD_INVENTORY=~/.config/technitium-ansible/prod/hosts.yml
```

This applies security updates, re-converges the host, and verifies it. A reboot
is deferred unless `REBOOT=true` is passed:

```bash
make update-prod PROD_INVENTORY=... REBOOT=true
```

## Technitium image updates

1. Review the Technitium changelog.
2. Take an application backup through the UI or external platform.
3. Update `technitium_version` and `technitium_image_digest` in the private
   production inventory in a dedicated change.
4. Test in development.
5. Apply with `make deploy-prod`.
6. Verify DNS, DHCP, console, and certificates.
7. Keep the previous data directory for rollback.

The on-disk format may migrate on first start. Downgrades are not guaranteed.

## Logs

```bash
journalctl --user-unit technitium.service -n 100 --no-pager
podman logs technitium
ls -l /var/log/technitium/dns
journalctl -u nginx -n 100 --no-pager
journalctl -u certbot-renew.service -n 100 --no-pager
```

Application log and stats retention are configured in the Technitium UI.

## Disk

Watch `/var/lib/technitium` and `/var/log/technitium`. A full disk can break DNS
and DHCP.

## Emergency stop

```bash
sudo -u technitium XDG_RUNTIME_DIR=/run/user/$(id -u technitium) \
  systemctl --user stop technitium.service
```

Start it again with `systemctl --user start technitium.service`.
