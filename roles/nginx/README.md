# nginx

Private HTTPS reverse proxy and certificate lifecycle for the Technitium web
console.

The role:

- installs the pinned nginx major version
- installs a minimal main configuration with no default port-80 server
- supports self-signed, provided, or Let's Encrypt certificates
- installs Certbot with the Cloudflare DNS plugin for production
- renews certificates twice daily and reloads nginx
- proxies only to `http://127.0.0.1:5380`
- allows only explicit administrator CIDRs plus loopback
- labels the loopback console port for SELinux `httpd_t`
- opens HTTPS only to the administrator CIDRs

## Requirements

- AlmaLinux 10
- Technitium listening on loopback
- for production: a public FQDN in a Cloudflare-managed zone and a scoped API token

## Key variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `nginx_server_name` | required | Public TLS server name |
| `nginx_allowed_cidrs` | `[]` | Console administrator CIDRs |
| `nginx_tls_mode` | `selfsigned` | `selfsigned`, `provided`, or `letsencrypt` |
| `nginx_letsencrypt_email` | `""` | Let's Encrypt account email |
| `nginx_cloudflare_api_token` | `""` | Scoped token from SOPS |
| `nginx_certbot_version` | `5.10.0` | Pinned Certbot |
| `nginx_certbot_dns_cloudflare_version` | `5.10.0` | Pinned plugin |
| `nginx_backend_url` | `http://127.0.0.1:5380` | Loopback Technitium console |
| `nginx_manage_firewall` | `true` | Open 443 to administrator CIDRs |

## Security notes

- There is intentionally no port-80 listener and no HTTP-to-HTTPS redirect.
- The Technitium console must never be bound to a non-loopback address.
- A provided private key must come from SOPS, never from a plaintext file in
  the repository.
- Let's Encrypt mode fails closed without a public dotted FQDN, account email,
  and Cloudflare token.
- No inbound port 80 is required; DNS-01 uses outbound HTTPS only.
