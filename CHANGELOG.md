# Changelog

All notable changes are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/),
and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Optional image for each service, shown to customers on the booking portal and the kiosk.

## [1.0.0] - 2026-11-04

First self-hosted release. RxTerminal began as a hosted multi-customer service; this version is a
single-business app you run on your own server.

### Added
- First-run setup page that creates the owner, organization and system administrator.
- `docker-compose.yml` with optional `https` (Caddy), `backup` (Litestream) and `postgres` profiles,
  and a workflow that publishes multi-architecture images to GHCR.
- Configuration through environment variables, with encryption keys and other secrets generated on
  first boot into `storage/secrets.env`.
- `APP_NAME`, `SUPPORT_EMAIL` and `LOGO_URL` branding settings.
- Legal pages (privacy, terms, cookies, data protection) as editable templates.
- The public portal of the main organization is served at the site root.

### Changed
- SQLite is the default database, PostgreSQL is optional.
- Sign-up is closed: new staff join by invitation only. Email and password is the only sign-in method.
- Logos upload directly with no review step. The 30-day limit on changing a slug is gone.
- The database history is squashed into one baseline migration. Existing hosted databases cannot be
  upgraded in place.

Patient payments are not part of 1.0.
