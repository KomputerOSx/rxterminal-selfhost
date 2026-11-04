# Operator guide

For the person who installs and runs the server. Staff should read the [user guide](user-guide/README.md) instead.

Commands assume you cloned the repo and run them in its folder. Anything marked **untested** was written
from the configuration but has not been run end to end; try it on a spare server before you depend on it.

## 1. Requirements

- A Linux server (Ubuntu 22.04 or later is a good choice), 1 CPU and 1 GB of RAM or more.
- [Docker Engine and the Compose plugin](https://docs.docker.com/engine/install/).
- A domain name pointing at the server, if you want HTTPS (recommended for anything real).
- An email (SMTP) account, so invitations, sign-in codes and appointment confirmations can be sent.

## 2. Install

```bash
git clone https://github.com/KomputerOSx/rxterminal-selfhost.git
cd rxterminal-selfhost
cp .env.example .env
```

Edit `.env`. At minimum:

```
APP_HOST=pharmacy.example.com
APP_PROTOCOL=https
```

Start it:

```bash
docker compose up -d --build        # or: docker compose pull && docker compose up -d
docker compose ps                   # wait until "healthy"
```

To use the published image instead of building, set the image in `.env` and skip `--build`:
`RXTERMINAL_IMAGE=ghcr.io/komputerosx/rxterminal-selfhost:1.1.0`.

Open your address and complete the setup page right away. **The first person to finish it becomes the
owner**, so do not leave a fresh server reachable from the internet unattended.

Then save your encryption keys (see [Backups](#5-backups-and-restore)):

```bash
docker compose exec app ./bin/rails selfhost:show_secrets
```

## 3. Domain and HTTPS

The app itself speaks plain HTTP on port 3000 (`APP_PORT`). Put HTTPS in front of it using one of these.

### Option A: bundled Caddy (easiest)

Point your domain's DNS at the server and open ports 80 and 443. In `.env`:

```
APP_HOST=pharmacy.example.com
APP_PROTOCOL=https
COMPOSE_PROFILES=https
APP_BIND=127.0.0.1
```

Run `docker compose up -d`. Caddy requests and renews a Let's Encrypt certificate for `APP_HOST` by
itself. `APP_BIND=127.0.0.1` keeps port 3000 closed to the outside. For a trial on your own computer
set `APP_HOST=localhost`: Caddy then uses its own local certificate and your browser will show a warning.

### Option B: nginx you already run (untested)

Leave `COMPOSE_PROFILES` empty, set `APP_BIND=127.0.0.1` and keep `APP_PROTOCOL=https`. Get a
certificate (for example with `certbot`), then proxy to the app. Live updates (the queue screens) use
WebSockets, so keep the `Upgrade` headers:

```nginx
server {
    listen 443 ssl http2;
    server_name pharmacy.example.com;

    ssl_certificate     /etc/letsencrypt/live/pharmacy.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/pharmacy.example.com/privkey.pem;

    client_max_body_size 10m;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade           $http_upgrade;
        proxy_set_header Connection        "upgrade";
        proxy_read_timeout 300s;
    }
}

server {
    listen 80;
    server_name pharmacy.example.com;
    return 301 https://$host$request_uri;
}
```

The `Host` and `X-Forwarded-Proto` headers matter: the app only answers to `APP_HOST`, and it uses the
forwarded scheme to know the connection is secure.

### Testing without HTTPS

Set `APP_PROTOCOL=http` and open `http://<server>:3000`. Cookies are then not marked secure so login works
over plain HTTP. Do not do this on the internet: passwords and patient data would travel unencrypted.

## 4. Email (SMTP)

Without email, nobody can accept a staff invitation or receive a sign-in code, and the emails are only
written to the log. Set these in `.env`, then run `docker compose up -d`:

```
SMTP_ADDRESS=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=your-smtp-user
SMTP_PASSWORD=your-smtp-password
SMTP_AUTHENTICATION=login
SMTP_ENABLE_STARTTLS=true
MAIL_FROM="High Street Pharmacy <no-reply@pharmacy.example.com>"
```

Use an address on a domain you control for `MAIL_FROM`, and set up SPF and DKIM for it with your email
provider, otherwise messages often land in spam. Port 465 (implicit TLS) is not supported; use 587 with
STARTTLS.

**Check that it works:** log out, choose "Forgot your password?" on the login page and enter your own
address, then see whether the email arrives. If it does not, look at the log:

```bash
docker compose logs app | grep -iE "mailer|smtp|deliver" | tail -20
```

Delivery errors are deliberately not shown to users, so the log is where problems appear.

## 5. Backups and restore

You need to back up **two separate things**. Keep them in different places.

### 5.1 The encryption keys (most important)

Patient names, dates of birth and postcodes are encrypted. The keys live in `storage/secrets.env` inside
the data volume. **If you lose them, that data is gone for good, and a database backup without the keys is
useless.**

```bash
docker compose exec app ./bin/rails selfhost:show_secrets
```

Copy the three `ACTIVE_RECORD_ENCRYPTION_*` values into a password manager or other safe place, not on the
same server and not next to your database backups. Do this once after install. They do not change unless
you change them, and you should never change them on a database that already holds data.

### 5.2 The data volume

The volume `rxterminal_storage` holds the database, uploaded logos and `secrets.env`.

A consistent copy of a running SQLite database needs SQLite's own backup command, not a plain file copy.
This makes one and then archives the whole volume:

```bash
STAMP=$(date +%F-%H%M)
docker compose exec app sqlite3 /rails/storage/production.sqlite3 ".backup '/rails/storage/backup-$STAMP.sqlite3'"
docker run --rm -v rxterminal_storage:/data -v "$PWD":/backup alpine \
  tar czf "/backup/rxterminal-storage-$STAMP.tgz" -C /data .
docker compose exec app rm "/rails/storage/backup-$STAMP.sqlite3"
```

Copy the `.tgz` off the server. Run it from cron every night, for example. The archive contains
`secrets.env`, so treat the file as sensitive and store it encrypted; it should still not be your only copy
of the keys.

The volume name starts with the Compose project name. If `docker volume ls` shows a different name, use that.

### 5.3 Continuous backup with Litestream (`backup` profile, untested)

In `.env`, add `backup` to `COMPOSE_PROFILES` and set an S3-compatible bucket:

```
LITESTREAM_REPLICA_URL=s3://my-bucket/rxterminal
LITESTREAM_ACCESS_KEY_ID=...
LITESTREAM_SECRET_ACCESS_KEY=...
```

It replicates only the main database file. It does not copy uploaded logos or `secrets.env`, so you still
need 5.1 and, for logos, 5.2.

### 5.4 Restore

1. Stop the app: `docker compose down`.
2. Restore the volume from an archive made in 5.2 into an empty volume (this replaces everything in it):

   ```bash
   docker volume rm rxterminal_storage
   docker volume create rxterminal_storage
   docker run --rm -v rxterminal_storage:/data -v "$PWD":/backup alpine \
     tar xzf /backup/rxterminal-storage-YYYY-MM-DD-HHMM.tgz -C /data
   ```

3. If you only have the database from the backup file, restore it in place of `production.sqlite3` and put
   the same `ACTIVE_RECORD_ENCRYPTION_*` values back, either in `.env` or in `storage/secrets.env`. Without
   the original keys the encrypted fields stay unreadable.
4. Start again: `docker compose up -d`.

To restore from Litestream (**untested**), with the app stopped:

```bash
docker compose --profile backup run --rm --no-deps --entrypoint litestream litestream \
  restore -config /etc/litestream.yml -o /rails/storage/production.sqlite3 /rails/storage/production.sqlite3
```

**Practise a restore on a spare machine before you need one.**

## 6. Upgrading

1. Read [CHANGELOG.md](../CHANGELOG.md) for the new version.
2. Take a backup (5.2).
3. Update:

   ```bash
   git pull
   docker compose up -d --build
   ```

   With a published image: set `RXTERMINAL_IMAGE` to the new version tag and run
   `docker compose pull && docker compose up -d`.

The app updates its database when it starts. Watch it with `docker compose logs -f app` and wait for
`healthy` in `docker compose ps`.

**Rolling back:** database changes are not reversible. To go back, set the previous image tag and restore
the backup from step 2 (5.4).

Pin a version tag (such as `1.1.0`) instead of `latest` if you want upgrades to happen only when you choose.
Note that 1.0.0 cannot upgrade a database from the old hosted service; it is a fresh start.

## 7. Using PostgreSQL instead of SQLite

SQLite is the default and is enough for one pharmacy or clinic. To use the bundled PostgreSQL:

```
COMPOSE_PROFILES=postgres
POSTGRES_PASSWORD=choose-a-long-random-password
DATABASE_URL=postgres://rxterminal:choose-a-long-random-password@postgres:5432/rxterminal
```

Back it up with `docker compose exec postgres pg_dump -U rxterminal rxterminal > backup.sql`. You still
need 5.1. Uploaded logos and `secrets.env` stay in the data volume. Do not use the Litestream profile with
PostgreSQL. You cannot switch an existing SQLite install to PostgreSQL by changing this setting; data is
not migrated.

## 8. Staff accounts and security

- Add staff from Members in the app (invitations are emailed). There is no public sign-up.
- Turn on two-factor authentication for owners and admins (Profile).
- Keep the server and Docker up to date, and the host firewall closed except for 80 and 443 (and SSH).
- Set `AUDIT_LOG_RETENTION_DAYS` only if you want old audit logs deleted. Unset keeps everything.
- Customer details are anonymized automatically after 90 days.
- Review and edit the legal pages: see the chapter "Branding and Legal Pages" in the user guide.

## 9. Troubleshooting

| Symptom | Check |
|---|---|
| Page does not load | `docker compose ps` (is `app` healthy?) and `docker compose logs app` |
| "Blocked host" or a blank error page | `APP_HOST` must match the address in the browser exactly (no `https://`, no port) |
| Login or setup form fails with a 422 | Using `http://` while `APP_PROTOCOL=https` (or the reverse). Make them match the real address, then clear the site's cookies |
| Redirect loop behind nginx | The proxy is not sending `X-Forwarded-Proto`, or `APP_PROTOCOL` does not match |
| Invitation emails never arrive | Section 4. Look in the log |
| Queue screens do not update | The proxy must forward WebSockets (the `Upgrade` headers in 3B) |
| Fresh install keeps asking for setup | A different data volume is being used. `docker volume ls` and check you started from the same folder |
| Encrypted fields show errors after a restore | The `ACTIVE_RECORD_ENCRYPTION_*` keys differ from the ones that wrote the data |

When asking for help, include `docker compose logs --tail 100 app` and your `.env` with passwords removed.

## 10. Removing everything

`docker compose down -v` stops the app and **deletes the data volume**, including the database and the
encryption keys. There is no undo.
