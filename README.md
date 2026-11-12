# helpvibe

Help center (Articles) and support desk (Helpdesk). Rails 8 on PostgreSQL 17.

## Deploy on Porter

Porter → Add-ons → Helm chart:

| field | value |
| --- | --- |
| Helm Repository URL | `https://primarydothealth.github.io/help-vibe` |
| Chart Name | `helpvibe` |
| Chart Version | `0.1.0` (see `chart/helpvibe/Chart.yaml`) |

Values YAML (fill in the blanks; secrets come from your password manager):

```yaml
domain: help.ourcompany.com          # point DNS at the cluster's load balancer
ingress:
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
externalDatabase:
  host: your-db.xxxx.us-east-1.rds.amazonaws.com
  user: helpvibe                     # must be allowed to CREATE DATABASE
  name: helpvibe_production          # plus _cache, _queue and _cable, created on first boot
  sslMode: require
secrets:
  railsMasterKey: ""                 # contents of config/master.key
  databasePassword: ""
  widgetSecret: ""                   # openssl rand -hex 32
  backupKey: ""                      # openssl rand -hex 32; keep a copy elsewhere
  sendgridApiKey: ""                 # optional
config:
  timeZone: America/New_York
  frameAncestors: "https://app.ourcompany.com"
  mailFrom: help@ourcompany.com
```

Instead of `secrets:`, you can create a Kubernetes Secret yourself and set
`existingSecret: <its name>` (keys are listed in `values.yaml`).

- **Image:** `ghcr.io/primarydothealth/help-vibe:main`, rebuilt on every push to
  `main` for amd64 and arm64. Restart the add-on to pick up a new build, or pin
  `image.tag: sha-<commit>`.
- **Chart changes** are published only when `version` in `Chart.yaml` goes up.
- **First staff account:** `kubectl -n <namespace> exec deploy/<add-on name>-helpvibe -- bin/rails 'helpvibe:user[you@company.com,superadmin]'`
  (it prints a password).

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
