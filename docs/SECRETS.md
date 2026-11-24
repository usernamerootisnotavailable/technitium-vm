# Secrets

## Model

Secrets are encrypted with SOPS and age. Encrypted files are committed only for
development. Production secrets live in the external private inventory
directory and are encrypted with the production age recipient.

Required secret variables:

| Variable | Purpose |
| --- | --- |
| `secret_technitium_admin_password` | Bootstrap admin password |
| `secret_cloudflare_dns_api_token` | Let's Encrypt DNS-01 Cloudflare token |

There is no Ansible automation account, API token, or application credential.

## Development

1. Generate an age key outside the repository.
2. Add the public recipient to `.sops.yaml` for the development path.
3. Run:

```bash
make secrets-dev
```

This creates `inventories/dev/group_vars/dns/secrets.sops.yml` with a random
bootstrap password.

## Production

Production inventory and secrets live outside the public repository, for
example:

```text
~/.config/technitium-ansible/prod/
├── .sops.yaml
└── group_vars/dns/secrets.sops.yml
```

`make init-prod` creates the directory, writes `.sops.yaml` with the production
age recipient, and encrypts the initial secrets.

Never place the age private key in the inventory or repository. Decrypt on the
controller only.

## Cloudflare token

Create a scoped API token:

- permission: `Zone:DNS:Edit`
- zone: the specific public zone used for the console FQDN
- no global API key
- no additional account-wide permissions

The token is rendered to `/etc/letsencrypt/cloudflare.ini` with mode `0600` by
the NGINX/Certbot role. Never pass it on a command line.

## Rotation

### Bootstrap admin password

The Podman secret is used only when Technitium creates its configuration for
the first time. Changing the SOPS value later does not rotate the password
stored in the application.

Rotate the password in the Technitium web UI, then update the private SOPS
value if the bootstrap secret is still expected to match. The role does not
reconcile application passwords.

### Cloudflare token

1. Create a replacement scoped token in Cloudflare.
2. Update the production SOPS file.
3. Re-run the NGINX role or `site.yml`; the credentials file updates.
4. Revoke the old token.
5. Run `certbot renew --dry-run` on the host.

## CI

- CI uses generated ephemeral development passwords only.
- Production inventory and secrets never enter GitHub Actions.
- gitleaks scans full history.
- No task may print decrypted values.
