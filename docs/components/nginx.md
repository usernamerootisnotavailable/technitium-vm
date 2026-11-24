# NGINX console proxy and Certbot

## Role

`roles/nginx`

## Purpose

Publishes the loopback-only Technitium web console over HTTPS to explicit
administrator CIDRs, and manages Let's Encrypt certificates through Cloudflare
DNS-01.

## Listener

| Port | Protocol | Source | Backend |
| --- | --- | --- | --- |
| 443 | TCP | `nginx_allowed_cidrs` | `http://127.0.0.1:5380` |

No port 80 listener exists. No inbound HTTP challenge is required.

## TLS modes

- `selfsigned` — development and CI
- `provided` — PEM certificate and key from SOPS
- `letsencrypt` — production, Certbot with Cloudflare DNS-01

The private key is mode `0600` owned by root. The certificate is mode `0644`.

## Certbot

- Certbot 5.10.0 and `certbot-dns-cloudflare` 5.10.0 in `/opt/certbot`
- Cloudflare credentials at `/etc/letsencrypt/cloudflare.ini`, mode `0600`
- certificate name `technitium-console`
- deploy hook copies the certificate to `/etc/pki/tls` and reloads NGINX
- `certbot-renew.timer` runs twice daily
- renewal test: `certbot renew --dry-run`

The public FQDN must be in a Cloudflare-managed public zone. It can resolve to a
private address; Let's Encrypt only validates the TXT challenge. Use a DNS-only
record if clients must reach the private address.

## Access control

- `allow` entries for `nginx_allowed_cidrs` plus loopback
- `deny all` as the final rule
- firewalld also restricts 443 to the same CIDRs
- NGINX continues to enforce its allowlist if the firewall rule is bypassed

## Proxy behavior

- HTTP/1.1 to the backend
- `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`
- 300-second read/send timeouts
- configurable `client_max_body_size` for console uploads
- security headers
- no WebSocket requirement

Technitium application-level reverse-proxy ACLs are configured in the UI if
desired.

## SELinux

NGINX runs in `httpd_t` on AlmaLinux. The role labels the loopback console port
as `http_port_t` so `httpd_t` may connect to it. Certificates use the standard
`/etc/pki/tls` locations.

Real-host verification must confirm:

- no AVC denials
- `httpd_t` connects to 5380
- TLS files are readable by the nginx master process

## Verification

- nginx service running
- pinned major version installed
- certificate and key present with safe modes
- HTTPS request through the private listener returns 200 when Technitium is up;
  502 is allowed only in the isolated role test where the backend is absent
- Certbot timer active in Let's Encrypt mode
