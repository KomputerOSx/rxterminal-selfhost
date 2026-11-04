# 12. Branding and Legal Pages

This chapter is for the person who runs the server. Staff can skip it.

## App name, support email, and logo

These are set in the server's `.env` file. Restart the app after changing them.

- `APP_NAME`: the product name shown in page titles, emails, and the top-left wordmark. Default: RxTerminal.
- `SUPPORT_EMAIL`: the contact address shown in the page footer, emails, and legal pages. If unset, RxTerminal uses your main organization's contact email.
- `LOGO_URL`: the address of an image to show instead of the text wordmark.

Your organization's own logo is separate. Staff upload it in Settings. See Organization Setup.

## Email

RxTerminal sends invitations, sign-in codes, password resets, and appointment confirmations by email. Set `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, and `MAIL_FROM` in `.env`. Without `SMTP_ADDRESS`, emails are only written to the server log, and no one can accept an invitation.

## Legal pages

Customers can read four pages: Terms of Use, Privacy Policy, Cookies Policy, and Data Protection Statement. They are linked from the footer and are available at `/terms`, `/privacy-policy`, `/cookies`, and `/gdpr`.

The built-in text is a template. It fills in your organization's name, address, contact details, and data retention period automatically. It is not legal advice. Have it reviewed for your country and your business before you rely on it.

To change the text:

1. Run `docker compose exec app ./bin/rails selfhost:legal:export`. This copies the four templates into the `storage/legal` folder, which is part of your data volume.
2. Edit the files in `storage/legal`. They are plain HTML with placeholders such as `{{organization_name}}` and `{{contact_email}}`.
3. Save. Changes show up straight away. No restart is needed.

A file in `storage/legal` replaces the built-in version of the same name. Delete the file to go back to the default. Run `./bin/rails selfhost:legal:status` to see which pages are customized.

Placeholders you can use:

- `{{organization_name}}`, `{{organization_address}}`, `{{contact_email}}`, `{{contact_phone}}`
- `{{app_name}}`, `{{site_url}}`, `{{site_domain}}`
- `{{pii_retention_days}}`: how long customer details are kept before they are anonymized.

If you add analytics or other outside scripts to your site, update the Cookies Policy and Privacy Policy to match.
