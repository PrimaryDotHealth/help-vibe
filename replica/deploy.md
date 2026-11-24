# Deploying helpvibe

A Kubernetes cluster (we use Porter), with the Helm chart in `chart/helpvibe`,
published at `https://primarydothealth.github.io/help-vibe`. It runs the app
(one pod) against your own Postgres (`externalDatabase`), or a bundled
Postgres 17 for trying it out. GitHub Actions builds the image
(`ghcr.io/primarydothealth/help-vibe`). The README has the Porter values.

> **Before any patient data exists (Part 1, the help center only),** you can
> skip the BAA steps. **Before Part 2 (support desk) goes live,** every box
> below marked BAA is required.

## Once: AWS and the cluster

1. **BAA.** In the AWS console, open AWS Artifact → Agreements and accept the AWS Business Associate Addendum for the account. Free.
2. **Cluster.** Any Kubernetes works. Either:
   - **EKS:** about $73/month for the control plane, plus the nodes. Use an arm64 (Graviton) node group if you build arm64 images.
   - **k3s on one EC2 box:** keeps the cost near the single-server plan (`t4g.small`, 20 GB **encrypted** gp3).
3. **Encrypted storage class.** Both volumes (Postgres and uploads) hold patient data in Part 2. On EKS, use a gp3 class with `encrypted: "true"`.
4. **Ingress and TLS.** An ingress controller (ingress-nginx, Traefik on k3s, or the AWS Load Balancer Controller) and cert-manager with a Let's Encrypt issuer.
5. **Registry.** ECR, or GitHub's registry (`ghcr.io/primarydothealth/help-vibe`). The cluster needs pull access.
6. **DNS.** Point `help.ourcompany.com` at the ingress's load balancer.

## Once: your Mac

- Docker (Docker Desktop, OrbStack or colima) for building the image, plus `kubectl` and `helm`.
- Secrets. Generate them once and keep them in a password manager:

```bash
export HELPVIBE_DATABASE_PASSWORD="$(openssl rand -hex 24)"
export HELPVIBE_WIDGET_SECRET="$(openssl rand -hex 32)"   # also given to our app's backend (signs widget tokens)
export HELPVIBE_BACKUP_KEY="$(openssl rand -hex 32)"      # encrypts nightly backups; keep a copy outside AWS
```

`config/master.key` must exist (it's created by `rails new` and is never committed).

Put them in the cluster as a Secret, so they never sit in a values file:

```bash
kubectl create namespace helpvibe
kubectl -n helpvibe create secret generic helpvibe-secrets \
  --from-file=RAILS_MASTER_KEY=config/master.key \
  --from-literal=HELPVIBE_DATABASE_PASSWORD="$HELPVIBE_DATABASE_PASSWORD" \
  --from-literal=HELPVIBE_WIDGET_SECRET="$HELPVIBE_WIDGET_SECRET" \
  --from-literal=HELPVIBE_BACKUP_KEY="$HELPVIBE_BACKUP_KEY"
```

To add a key later (SendGrid, inbound email, Helpjuice), patch the Secret and restart:

```bash
kubectl -n helpvibe patch secret helpvibe-secrets --type merge -p '{"stringData":{"SENDGRID_API_KEY":"SG.…"}}'
kubectl -n helpvibe rollout restart deploy/helpvibe
```

And the plain settings in `values.prod.yaml` (safe to commit, no secrets):

```yaml
domain: help.ourcompany.com
existingSecret: helpvibe-secrets
externalDatabase:
  host: your-db.xxxx.us-east-1.rds.amazonaws.com
  sslMode: require
ingress:
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
config:
  timeZone: America/New_York                    # scheduled publishing and backups run in this zone
  frameAncestors: "https://app.ourcompany.com"  # where the widget and help center may be embedded
  mailFrom: help@ourcompany.com
storage:
  storageClass: gp3-encrypted
```

## Every deploy

```bash
# push to main; GitHub Actions builds ghcr.io/primarydothealth/help-vibe:sha-<commit>
helm upgrade --install helpvibe chart/helpvibe -n helpvibe -f values.prod.yaml --set image.tag=sha-$(git rev-parse --short=7 HEAD)
```

The pod migrates the database as it starts (`bin/docker-entrypoint` runs `db:prepare`), then `/up` turns ready. With one pod and a ReadWriteOnce volume, the old pod stops before the new one starts, so expect a few seconds of downtime per deploy.

The first time, create a staff account (it prints a password), then open https://help.ourcompany.com/session/new:

```bash
kubectl -n helpvibe exec deploy/helpvibe -- bin/rails 'helpvibe:user[you@ourcompany.com,superadmin]'
```

Day to day:

```bash
kubectl -n helpvibe logs -f deploy/helpvibe                  # tail the logs
kubectl -n helpvibe exec -it deploy/helpvibe -- bin/rails console
```

## Importing from Helpjuice

Set `HELPJUICE_SUBDOMAIN=yourcompany` under `config.extraEnv` in `values.prod.yaml`, add `HELPJUICE_API_KEY` (Helpjuice → Settings → API credentials) to the Secret, and deploy.

Then Admin → Import → Start import, or from a terminal:

```bash
kubectl -n helpvibe exec deploy/helpvibe -- bin/rails helpvibe:import:helpjuice
```

It's safe to run again. Private articles come across visible to superadmins only, and the run lists them so you can share each with the right people or groups.

## Email (SendGrid)

All email (invitations, password resets, and later support notifications) goes through Action Mailer over SendGrid's SMTP relay.

1. In SendGrid:
   - Authenticate your sending domain (Settings → Sender Authentication), so mail passes SPF and DKIM.
   - Create an API key with "Mail Send" permission only.
2. Add `SENDGRID_API_KEY` to the Secret, and set `config.mailFrom` in `values.prod.yaml` to an address on the authenticated domain. Then deploy.

Without `SENDGRID_API_KEY`, emails are saved as files in `storage/mails` in the storage volume instead of being sent. Click and open tracking are switched off on every message, so SendGrid never rewrites the sign-in links.

> **HIPAA:** check with Twilio whether your SendGrid plan is covered by a BAA before any patient data goes into email. Part 2's notification emails default to "link only" (no message text), which keeps patient details out of email either way.

## Support email in (SendGrid Inbound Parse)

Replies to support emails, and new emails to the support address, come back into the inbox through Action Mailbox.

1. Pick a subdomain for inbound mail, for example `reply.ourcompany.com`. Add an MX record for it: `mx.sendgrid.net`, priority 10.
2. Generate a password:

```bash
export RAILS_INBOUND_EMAIL_PASSWORD="$(openssl rand -hex 24)"   # add to the Secret
```

   and set `config.inboundDomain: reply.ourcompany.com` in `values.prod.yaml`.

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
- The dump is encrypted with AES-256-GCM using `HELPVIBE_BACKUP_KEY`. Create it with `openssl rand -hex 32`, put it in the Secret, and **keep a copy outside AWS**: without it, backups can't be read.
- Backups sit on the storage volume next to the uploads, so that volume must use an encrypted storage class.

```bash
kubectl -n helpvibe exec deploy/helpvibe -- bin/rails helpvibe:backup:now                                # take one now
kubectl -n helpvibe exec deploy/helpvibe -- bin/rails 'helpvibe:backup:decrypt[storage/backups/<file>]' > restore.dump
kubectl -n helpvibe scale deploy/helpvibe --replicas=0                                         # stop the app
kubectl -n helpvibe exec -i helpvibe-postgresql-0 -- pg_restore --clean --no-owner -U helpvibe -d helpvibe_production < restore.dump
kubectl -n helpvibe scale deploy/helpvibe --replicas=1
```

Uploaded files live in the `helpvibe-storage` volume. On EKS, a daily EBS snapshot schedule (Data Lifecycle Manager, keep 14, matched on the volumes' tags) covers both volumes at the disk level. Both volumes outlive `helm uninstall`.

## Sizing

- **RAM.** One Puma process with 3 threads (YJIT and jemalloc), jobs in-process, and Postgres with 256 MB of shared buffers. Expect about 500–700 MB for the app pod and 300 MB for Postgres. The chart's limits are 1 GiB and 768 MiB.
- **When to scale up.** Watch `kubectl -n helpvibe top pods`. If the app creeps toward its limit, raise `resources.limits.memory`.
- **More than one app pod** needs S3 for uploads (Active Storage) and a separate jobs Deployment, since jobs run inside Puma today.
