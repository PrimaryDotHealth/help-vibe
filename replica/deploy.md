# Deploying helpvibe

One AWS server running the app and Postgres, about $15/month. Kamal builds the
image on your Mac and ships it over SSH.

> **Before any patient data exists (Part 1, the help center only),** you can
> skip the BAA steps. **Before Part 2 (support desk) goes live,** every box
> below marked BAA is required.

## Once: AWS

1. **BAA.** In the AWS console, open AWS Artifact → Agreements and accept the AWS Business Associate Addendum for the account. Free.
2. **Server.** Launch an EC2 instance:
   - **type:** `t4g.small` (2 GB, arm64), or `t4g.micro` while it's just the help center
   - **image:** Ubuntu 24.04 LTS (arm64)
   - **disk:** 20 GB gp3, **encrypted** (KMS default key). This holds Postgres and uploaded files.
   - **security group:** inbound 22 (your IP only), 80 and 443 (anywhere)
   - **key pair:** your SSH key. Kamal connects as `root` by default, so either allow root over SSH with your key, or set `ssh: user: ubuntu` in `config/deploy.yml` and give that user passwordless sudo plus docker.
3. **Address.** Attach an Elastic IP, then point DNS for `help.ourcompany.com` (an A record) at it.

## Once: your Mac

- Docker (Docker Desktop, OrbStack or colima) for building the image. Apple Silicon builds arm64 natively.
- Secrets in your shell. Generate them once and keep them in a password manager:

```bash
export HELPVIBE_DATABASE_PASSWORD="$(openssl rand -hex 24)"
export HELPVIBE_WIDGET_SECRET="$(openssl rand -hex 32)"   # also given to our app's backend (signs widget tokens)
export HELPVIBE_BACKUP_KEY="$(openssl rand -hex 32)"      # encrypts nightly backups; keep a copy outside AWS
export HELPVIBE_TIME_ZONE="America/New_York"              # scheduled publishing and backups run in this zone
export HELPVIBE_HOST=<elastic ip>
export HELPVIBE_DOMAIN=help.ourcompany.com
export HELPVIBE_FRAME_ANCESTORS="https://app.ourcompany.com"   # where the widget may be embedded
```

`config/master.key` must exist (it's created by `rails new` and is never committed).

## First deploy

```bash
bin/kamal setup          # installs Docker on the server, starts Postgres, builds, migrates, starts the app
bin/kamal app exec 'bin/rails "helpvibe:user[you@ourcompany.com,superadmin]"'   # prints a password
```

Then open https://help.ourcompany.com/session/new.

## Every deploy after that

```bash
bin/kamal deploy         # zero-downtime: new container, health check on /up, switch, migrate on boot
bin/kamal logs           # tail the logs
bin/kamal console        # rails console on the server
```

## Importing from Helpjuice

On the server's environment (add to `env.clear` and `.kamal/secrets`, then `bin/kamal deploy`):

```
HELPJUICE_SUBDOMAIN=yourcompany
HELPJUICE_API_KEY=…            # Helpjuice → Settings → API credentials
```

Then Admin → Import → Start import, or from a terminal:

```bash
bin/kamal app exec 'bin/rails helpvibe:import:helpjuice'
```

It's safe to run again. Private articles come across visible to superadmins only, and the run lists them so you can share each with the right people or groups.

## Email (SendGrid)

All email (invitations, password resets, and later support notifications) goes through Action Mailer over SendGrid's SMTP relay.

1. In SendGrid:
   - Authenticate your sending domain (Settings → Sender Authentication), so mail passes SPF and DKIM.
   - Create an API key with "Mail Send" permission only.
2. Add to your shell secrets, then `bin/kamal deploy`:

```bash
export SENDGRID_API_KEY=SG.…
export HELPVIBE_MAIL_FROM=help@ourcompany.com   # must be on the authenticated domain
```

Without `SENDGRID_API_KEY`, emails are saved as files in `storage/mails` on the server instead of being sent. Click and open tracking are switched off on every message, so SendGrid never rewrites the sign-in links.

> **HIPAA:** check with Twilio whether your SendGrid plan is covered by a BAA before any patient data goes into email. Part 2's notification emails default to "link only" (no message text), which keeps patient details out of email either way.

## Support email in (SendGrid Inbound Parse)

Replies to support emails, and new emails to the support address, come back into the inbox through Action Mailbox.

1. Pick a subdomain for inbound mail, for example `reply.ourcompany.com`. Add an MX record for it: `mx.sendgrid.net`, priority 10.
2. Generate a password:

```bash
export RAILS_INBOUND_EMAIL_PASSWORD="$(openssl rand -hex 24)"
export HELPVIBE_INBOUND_DOMAIN=reply.ourcompany.com
```

3. In SendGrid, open Settings → Inbound Parse → Add Host & URL and fill it in:
   - **Receiving domain:** `reply.ourcompany.com`
   - **Destination URL:** `https://actionmailbox:<RAILS_INBOUND_EMAIL_PASSWORD>@help.ourcompany.com/rails/action_mailbox/sendgrid/inbound_emails`
   - Tick **"POST the raw, full MIME message"**.
4. To accept new conversations by email, forward `support@ourcompany.com` to `support@reply.ourcompany.com`.

How it fits together:
- **Threading:** our notification emails carry a Reply-To like `support+<token>@reply.ourcompany.com`, and replies are matched by that token, then by In-Reply-To.
- **Filtering:** auto-replies, loops and duplicates are dropped.
- **Unknown senders:** someone who isn't the conversation's contact starts a new conversation rather than joining it.
- **What emails say:** notification emails are link-only by default, with no message text. `HELPVIBE_EMAIL_MODE=full` includes the text.

## Before patient data goes live (open items)

- **Row-level security.** The policies exist and are tested, but the app still connects to Postgres as the table owner, so Postgres doesn't enforce them yet. To enforce them:
  1. Create a separate login role, e.g. `helpvibe_app`, that owns nothing.
  2. Grant it select, insert, update and delete, but not update or delete on `audit_events`.
  3. Point `HELPVIBE_DATABASE_PASSWORD` and the username at that role.
  4. Keep the owner role for migrations.

  Until then, the app's own permission checks are what keep each team's conversations apart.
- **BAA coverage.** The host (AWS) and email (SendGrid) both need a BAA. Check SendGrid's with Twilio.
- **Still to build:** 2FA and SSO for agents, and a retention policy.

## Embedding in our app

```html
<script src="https://help.ourcompany.com/embed.js" async></script>
<script>
  // optional, for signed-in staff: a token from our backend (HS256 with HELPVIBE_WIDGET_SECRET,
  // claims: sub, kind: "staff" | "patient", name, iat, exp <= 10 minutes)
  HelpVibe.identify(tokenFromOurBackend)
</script>
```

Our app's Content-Security-Policy must allow `script-src` and `frame-src` for `https://help.ourcompany.com`.

## Backups (BAA)

A nightly job (3am, in `HELPVIBE_TIME_ZONE`) writes an encrypted `pg_dump` to `storage/backups/` and keeps the newest 14:
- The dump is encrypted with AES-256-GCM using `HELPVIBE_BACKUP_KEY`. Create it with `openssl rand -hex 32`, add it to your shell secrets, and **keep a copy outside AWS**: without it, backups can't be read.
- Backups sit on the server's encrypted disk next to the uploads.

```bash
bin/kamal app exec 'bin/rails helpvibe:backup:now'                                   # take one now
bin/kamal app exec "bin/rails 'helpvibe:backup:decrypt[storage/backups/<file>]'" > restore.dump
pg_restore --clean --no-owner -d helpvibe_production restore.dump                    # restore (stop the app first)
```

Uploaded files live in the `helpvibe_storage` Docker volume on the encrypted disk. An EBS snapshot schedule (Data Lifecycle Manager, daily, keep 14) covers both the database and the files at the disk level.

## Sizing

- **RAM.** One Puma process with 3 threads (YJIT and jemalloc), jobs in-process, and Postgres with 256 MB of shared buffers. Expect about 500–700 MB in use on the 2 GB box.
- **When to scale up.** If `bin/kamal app exec 'ps -o rss= -p 1'` creeps past about 700 MB, move to `t4g.medium`.
