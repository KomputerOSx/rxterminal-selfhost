# Contributing

Thanks for helping. Bug reports, fixes and documentation improvements are welcome.

## Before you start

- For anything bigger than a small fix, open an issue first so we can agree on the approach.
- Security issues go through [SECURITY.md](SECURITY.md), not public issues.
- By contributing you agree that your work is released under the [AGPL-3.0](LICENSE).

## Setup

You need Ruby 4.0.5 and libvips.

```bash
bin/setup --skip-server
bin/dev
```

## Before you open a pull request

```bash
bin/rails test
bin/rubocop
bin/brakeman -q --no-pager
```

All three must pass, and CI runs them too. Also run the booking concurrency check on its own when
you touch appointment booking: `bin/rails test test/concurrency/appointment_booking_check.rb`.

## Guidelines

- Keep pull requests small and focused, with tests for behaviour changes.
- Patient and customer personal data must stay encrypted. See [docs/encryption.md](docs/encryption.md).
- Do not add third-party scripts, analytics or trackers.
- Never call an external service inside a database transaction (SQLite has one writer).
- Follow the writing rules in [docs/user-guide/README.md](docs/user-guide/README.md) when editing the guide.
- Update `CHANGELOG.md` for user-visible changes.

## Pitfalls

- Code that commits data outside a test transaction can leave rows that break other tests. If the
  suite fails randomly: `rm -f storage/test*; RAILS_ENV=test bin/rails db:prepare`.
- Check `git status` after running Bundler commands. Some of them boot Rails and touch files.
