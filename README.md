# helpvibe

Help center (Articles) and support desk (Helpdesk). Rails 8 on PostgreSQL 17.

## Deploy on Porter

Porter → **Create a new app** → GitHub → `PrimaryDotHealth/help-vibe`, branch
`main`. Porter reads `porter.yaml`, which builds the `Dockerfile` and defines:

- **predeploy:** `bin/rails db:prepare`. It creates the databases on the first deploy and migrates on every deploy.
- **web:** port 8080, with a health check on `/up`. Add your domain to it in Porter.
- **jobs:** background jobs and the recurring schedule.

Porter's containers have no persistent disk, so uploaded files go to S3.

### Environment variables (set in Porter, secrets marked)

| variable | required | value |
| --- | --- | --- |
| `RAILS_MASTER_KEY` | yes, secret | contents of `config/master.key` |
| `DB_HOST` | yes | your Postgres host |
| `HELPVIBE_DATABASE_PASSWORD` | yes, secret | its password |
| `DB_USER` | if not `helpvibe` | must be allowed to `CREATE DATABASE` |
| `DB_NAME` | if not `helpvibe_production` | `_cache`, `_queue` and `_cable` are created beside it |
| `DB_PORT` | if not `5432` | |
| `DB_SSLMODE` | recommended | `require` for RDS |
| `HELPVIBE_DOMAIN` | yes | `help.ourcompany.com` (links in emails and embed snippets) |
| `ACTIVE_STORAGE_SERVICE` | yes | `amazon` |
| `HELPVIBE_S3_BUCKET` | yes | bucket for uploads (private, encrypted) |
| `AWS_REGION` | yes | the bucket's region |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | yes, secret, unless the pods have an IAM role | a user limited to that bucket |
| `HELPVIBE_WIDGET_SECRET` | for signed-in widget users, secret | `openssl rand -hex 32`, shared with our app's backend |
| `HELPVIBE_FRAME_ANCESTORS` | to embed on other sites | e.g. `https://app.ourcompany.com` (space-separated) |
| `HELPVIBE_MAIL_FROM` | for email | e.g. `help@ourcompany.com` |
| `SENDGRID_API_KEY` | for email, secret | without it, no email is sent |
| `HELPVIBE_TIME_ZONE` | no | e.g. `America/New_York`; default UTC |
| `RAILS_INBOUND_EMAIL_PASSWORD`, `HELPVIBE_INBOUND_DOMAIN` | no | email replies into the inbox (see `replica/deploy.md`) |

Put the same variables on all three (web, jobs, predeploy): app-level env vars or an env group do this.

**S3 bucket CORS.** The article editor uploads images straight from the browser,
so the bucket must allow it:

```json
[{ "AllowedOrigins": ["https://help.ourcompany.com"], "AllowedMethods": ["PUT"],
   "AllowedHeaders": ["Content-Type", "Content-MD5", "Content-Disposition"], "MaxAgeSeconds": 3600 }]
```

**Backups.** Use your database's own automated backups (RDS snapshots). The
in-app nightly dump writes to local disk, so it is off unless `HELPVIBE_BACKUP_KEY` is set.

**First staff account.** In Porter, open a shell on the web service and run
`bin/rails 'helpvibe:user[you@company.com,superadmin]'` (it prints a password).

## Deploy with Helm

The chart in `chart/helpvibe` runs the app (the image built from `Dockerfile`)
against your own Postgres, or a bundled Postgres 17 StatefulSet for trying it out.

```sh
# 1. Install (the image comes from GitHub Actions; see .github/workflows/image.yml)
helm repo add helpvibe https://primarydothealth.github.io/help-vibe
helm upgrade --install helpvibe helpvibe/helpvibe -n helpvibe --create-namespace \
  --set domain=help.ourcompany.com \
  --set ingress.className=nginx \
  --set externalDatabase.host=your-db.example.com \
  --set-string ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt \
  --set secrets.railsMasterKey="$(cat config/master.key)" \
  --set secrets.databasePassword="$HELPVIBE_DATABASE_PASSWORD" \
  --set secrets.widgetSecret="$HELPVIBE_WIDGET_SECRET" \
  --set secrets.backupKey="$HELPVIBE_BACKUP_KEY" \
  --set config.frameAncestors="https://app.ourcompany.com"

# 2. First staff account (prints a password)
kubectl -n helpvibe exec deploy/helpvibe -- bin/rails 'helpvibe:user[you@company.com,superadmin]'
```

- **Migrations** run when the pod starts (`bin/docker-entrypoint` runs `db:prepare`).
- **Secrets:** instead of `--set secrets.*`, create a Secret yourself and pass
  `--set existingSecret=<name>`. Its keys are listed in `values.yaml`.
- **Database:** set `externalDatabase.host` (and user, name, sslMode), or try it
  with the bundled Postgres: `--set postgresql.enabled=true`.
- **One replica only.** Uploads, emailed-as-file messages and nightly backups sit
  on a ReadWriteOnce volume, and background jobs run inside Puma. Use an
  encrypted storage class for both volumes once there is patient data.
- **Local cluster over plain http** (kind, k3d, Docker Desktop): add
  `--set config.ssl=false --set ingress.enabled=false`, then
  `kubectl -n helpvibe port-forward svc/helpvibe 3000:80`.

## Run it without Kubernetes

```sh
bin/setup          # installs gems, prepares the database, starts the server
bin/rails test test:system
```

The full runbook (SendGrid, inbound email, Helpjuice import, backups, BAA items)
is in `replica/deploy.md`.
