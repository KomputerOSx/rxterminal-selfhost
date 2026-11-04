# RxTerminal

Queue and appointment management for a pharmacy, clinic or any walk-in service business. Staff
see who is waiting and call the next person. Customers join the queue from an in-store kiosk or
their phone, or book an appointment on your public page. You run it yourself, on your own server,
and your customers' data stays with you.

- Walk-in queue with a kiosk, a waiting-room display and QR check-in
- Online appointment booking with calendars, opening hours and blocked dates
- Upsell suggestions, notifications, analytics and an audit log
- Roles and permissions, optional two-factor sign-in, patient identifiers encrypted at rest
- One business per install, with optional extra branches
- Open source under the [AGPL-3.0](LICENSE)

## Quick start (Docker)

You need a server with [Docker](https://docs.docker.com/engine/install/) and Docker Compose.

```bash
git clone https://github.com/KomputerOSx/rxterminal-selfhost.git
cd rxterminal-selfhost
cp .env.example .env
```

Edit `.env` and set at least:

```
APP_HOST=pharmacy.example.com     # your domain, or "localhost" to try it out
APP_PROTOCOL=https                # use "http" only when testing without a certificate
```

Then start it:

```bash
docker compose up -d --build
```

Open the address in your browser. The first visit goes to a setup page where you enter your
organization's name, your email and a password. You become the owner. After that the setup page
closes, and everyone else joins by invitation.

> **Whoever reaches a new server first becomes its owner.** Do the setup yourself straight after
> starting it, and do not expose a fresh install to the internet and walk away.

### HTTPS with automatic certificates

Point your domain's DNS at the server, open ports 80 and 443, and add to `.env`:

```
COMPOSE_PROFILES=https
APP_BIND=127.0.0.1
```

`docker compose up -d` then also starts Caddy, which gets and renews a Let's Encrypt certificate
for `APP_HOST`. Already running nginx or another proxy? Skip this profile and proxy to the app's
port (3000 by default), passing the `Host` and `X-Forwarded-Proto` headers.

### Other options

| Profile | What it does |
|---|---|
| `https` | Caddy reverse proxy with automatic Let's Encrypt certificates |
| `backup` | Litestream copies the SQLite database to S3-compatible storage (set `LITESTREAM_*`) |
| `postgres` | Bundled PostgreSQL instead of SQLite (set `POSTGRES_PASSWORD` and `DATABASE_URL`) |

Combine them with `COMPOSE_PROFILES=https,backup`. SQLite is the default and is fine for a single
pharmacy or clinic.

## Back up your keys

**Patient names, dates of birth and postcodes are encrypted in the database. The keys that unlock
them are generated on first start and saved in `storage/secrets.env` inside the data volume. If you
lose them, that data cannot be recovered by anyone.**

1. As soon as the server is running, print them: `docker compose exec app ./bin/rails selfhost:show_secrets`
2. Save them in a password manager or another safe place, **separate from your database backups**.
3. Never change them on a database that already contains data.

Back up the whole data volume (`docker volume ls`, look for `rxterminal_storage`). It holds the
database, uploaded logos and the keys. The `backup` profile only covers the SQLite database file.

## Configuration

Everything is set with environment variables in `.env`. See [`.env.example`](.env.example) for the
full list. The main ones:

| Variable | Purpose |
|---|---|
| `APP_HOST`, `APP_PROTOCOL` | Your address. Required. |
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `MAIL_FROM` | Email. Needed for staff invitations, sign-in codes and appointment confirmations. Without it, emails are only written to the log. |
| `APP_NAME`, `SUPPORT_EMAIL`, `LOGO_URL` | Branding shown in titles, emails and the footer |
| `DATABASE_URL` | Use PostgreSQL instead of SQLite |
| `AUDIT_LOG_RETENTION_DAYS` | Delete audit logs older than this. Unset keeps everything. |
| `SENTRY_DSN` | Optional error reporting |

### Legal pages

The Privacy Policy, Terms of Use, Cookies Policy and Data Protection Statement are templates that
fill in your organization's details. **They are not legal advice. Have them reviewed for your
country and business.** To edit them, run `docker compose exec app ./bin/rails selfhost:legal:export`
and change the files in `storage/legal/`. Changes apply immediately.

## Updating

```bash
git pull
docker compose up -d --build
```

Or, once release images are published, `docker compose pull && docker compose up -d`. The app
migrates its database on start. Take a backup first.

## Documentation

All guides are listed in [docs/README.md](docs/README.md).

- [Operator guide](docs/operator-guide.md): install, HTTPS and nginx, email, backup and restore, upgrading
- [User guide](docs/user-guide/README.md): setup, services, queues, appointments, kiosk, staff
- [Encryption](docs/encryption.md): what is encrypted and how the keys work
- [Roles and permissions](docs/rbac.md)

## Development

You need Ruby 4.0.5 (see `.ruby-version`) and libvips.

```bash
bin/setup --skip-server      # install gems, prepare the database
bin/dev                      # run the app on http://localhost:3000
bin/rails test               # run the test suite
bin/rubocop                  # lint
bin/brakeman                 # security scan
```

`bin/setup` seeds a demo account in development: `admin@mail.com` / `SuperKey99!` (so the setup page
is skipped). Use an empty database without seeds to try the first-run setup. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## Security

Report vulnerabilities privately. See [SECURITY.md](SECURITY.md).

## License

[GNU Affero General Public License v3.0](LICENSE). If you run a modified version for others over a
network, you must offer them the source of your changes.
