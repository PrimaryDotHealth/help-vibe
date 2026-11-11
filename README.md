# helpvibe

Help center (Articles) and support desk (Helpdesk). Rails 8 on PostgreSQL 17.

## Deploy with Helm

The chart in `chart/helpvibe` runs the app (the image built from `Dockerfile`)
and, unless you turn it off, a Postgres 17 StatefulSet beside it.

```sh
# 1. Build and push the image (arm64 for Graviton nodes, amd64 otherwise)
docker buildx build --platform linux/arm64 -t ghcr.io/primarydothealth/help-vibe:0.1.0 --push .

# 2. Install
helm upgrade --install helpvibe chart/helpvibe -n helpvibe --create-namespace \
  --set domain=help.ourcompany.com \
  --set image.tag=0.1.0 \
  --set ingress.className=nginx \
  --set-string ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt \
  --set secrets.railsMasterKey="$(cat config/master.key)" \
  --set secrets.databasePassword="$HELPVIBE_DATABASE_PASSWORD" \
  --set secrets.widgetSecret="$HELPVIBE_WIDGET_SECRET" \
  --set secrets.backupKey="$HELPVIBE_BACKUP_KEY" \
  --set config.frameAncestors="https://app.ourcompany.com"

# 3. First staff account (prints a password)
kubectl -n helpvibe exec deploy/helpvibe -- bin/rails 'helpvibe:user[you@company.com,superadmin]'
```

- **Migrations** run when the pod starts (`bin/docker-entrypoint` runs `db:prepare`).
- **Secrets:** instead of `--set secrets.*`, create a Secret yourself and pass
  `--set existingSecret=<name>`. Its keys are listed in `values.yaml`.
- **Your own Postgres (RDS):** `--set postgresql.enabled=false --set externalDatabase.host=...`.
  The user must be allowed to create databases (the app uses `helpvibe_production`
  plus `_cache`, `_queue` and `_cable`).
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
