# Security policy

RxTerminal handles patient and customer personal data, so security reports are taken seriously.

## Reporting a vulnerability

**Do not open a public issue.** Use GitHub's private reporting instead:
[Report a vulnerability](https://github.com/KomputerOSx/rxterminal-selfhost/security/advisories/new)
(Security tab, "Report a vulnerability").

Please include what you found, how to reproduce it, the version or commit, and the impact you
expect. We aim to acknowledge reports within 5 working days and will tell you when a fix is
released. Please give us reasonable time to fix an issue before you disclose it.

## Supported versions

Only the latest release receives security fixes.

## Running a secure install

- Serve the site over HTTPS (`APP_PROTOCOL=https`; the `https` Docker profile does this for you).
- Set up the server yourself immediately after first start: the first visitor becomes the owner.
- Back up `storage/secrets.env` (the encryption keys) separately from the database.
- Turn on two-factor authentication for owners and admins, and configure email (SMTP).
- Keep the image and host updated. Take backups before upgrading.
