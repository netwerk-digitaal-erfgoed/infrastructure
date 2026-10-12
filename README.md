# NDE Infrastructure

This repository contains infrastructure configuration for running NDE applications in a Kubernetes cluster.

This configuration follows the [CLARIAH Infrastructure Requirements](https://github.com/CLARIAH/clariah-plus/blob/main/requirements/infrastructure-requirements.md).
Software running in this infrastructure must meet the [NDE Software Requirements](doc/software-requirements.md).

## Features

* GitOps using [Flux](https://fluxcd.io) to automatically roll out infrastructure and application changes.
* Declarative configuration using [Flux HelmRelease](https://fluxcd.io/flux/components/helm/helmreleases/). Everything is version-controlled, including [secrets](#secrets).
* DNS automation using [ExternalDNS](https://kubernetes-sigs.github.io/external-dns/latest/).
* Automatic TLS certificates via [cert-manager](https://cert-manager.io).
* A shared [Helm chart](helm/nde-app) for deploying applications consistently, supporting Deployments, StatefulSets,
  CronJobs, ConfigMaps, and multi-container pods.
* Daily off-site [backups](helm/nde-app/README.md#velero-volume-backups) of databases and file volumes.

## Repository structure

```
├─ helm/
│  └─ nde-app/       # Helm chart for NDE applications
├─ k8s/              # Application deployments
│  ├─ flux.yaml      # Flux image update automation
│  ├─ rbac/          # Service account and roles
│  ├─ secrets/       # Encrypted secrets
│  └─ */             # Application HelmReleases (one or more per app)
```

## Deploying applications

Applications are deployed using [HelmReleases](https://fluxcd.io/flux/components/helm/helmreleases/) with the shared [nde-app Helm chart](helm/nde-app/README.md).

### Example HelmRelease

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: my-app
  namespace: nde
spec:
  serviceAccountName: nde
  interval: 30m
  chart:
    spec:
      chart: helm/nde-app
      reconcileStrategy: Revision # To pick up changes in the Helm chart without having to version that.
      sourceRef:
        kind: GitRepository
        name: nde
  values:
    containers:
      - name: app
        image:
          repository: ghcr.io/netwerk-digitaal-erfgoed/my-app
          tag: latest # {"$imagepolicy": "nde:my-app:tag"}
        port: 8080

    ingresses:
      - hosts:
          - my-app.netwerkdigitaalerfgoed.nl
```

This creates:

- a Deployment running the `my-app` container on port 8080
- a Service that maps port 80 to 8080
- an HTTPS-enabled Ingress that routes traffic from `my-app.netwerkdigitaalerfgoed.nl` to the application
- a TLS Certificate for `my-app.netwerkdigitaalerfgoed.nl`
- a DNS entry for `my-app.netwerkdigitaalerfgoed.nl`.

### Resource limits

The cluster is managed by SURF, which applies a `LimitRange` to the namespace. Defaults per container, unless a HelmRelease sets its own `resources`:

- Memory limit: **256M**
- CPU: **250m**

### Image automation

Flux automatically updates image tags when new versions are pushed. The `# {"$imagepolicy": ...}` comment enables this.

- NDE images (`ghcr.io/netwerk-digitaal-erfgoed/*`): checked every **1 minute**
- External images: checked every **24 hours**.

See [helm/nde-app/README.md](helm/nde-app/README.md) for configuration options.

## Secrets

Secrets are encrypted using [SOPS with age](https://fluxcd.io/flux/guides/mozilla-sops/) and stored in `k8s/secrets/`.
See [k8s/secrets/README.md](k8s/secrets/README.md) for encryption instructions.

## Object storage

Files are stored in [SURF’s S3 object store](https://servicedesk.surf.nl/wiki/spaces/WIKI/pages/29557216/Object+Store) at `https://objectstore.surf.nl` (region `default`, path-style addressing).
Applications in the cluster read the credentials from the `s3` secret.

To use it from your own machine with the [AWS CLI](https://aws.amazon.com/cli/) (version 2.13 or later), add a profile to `~/.aws/config`:

```ini
[profile nde]
endpoint_url = https://objectstore.surf.nl
region = default
```

and the key to `~/.aws/credentials`:

```ini
[nde]
aws_access_key_id = …
aws_secret_access_key = …
```

There is no web interface; a desktop client such as [Cyberduck](https://servicedesk.surf.nl/wiki/spaces/WIKI/pages/112591465/Cyberduck) works with the same key.
We have one key for the whole account and cannot create more ourselves: SURF issues them.

### Public files

Everything is private by default: without the key, a download returns 403.

Public files get a stable address at `https://files.nde.nl/<bucket>/<key>` ([k8s/files](k8s/files/helmrelease.yaml)), which redirects to the object store.
Publish only `files.nde.nl` URLs, so the files can move without breaking links.
Clients must follow redirects (`curl -L`).

To make files public, set a bucket policy that allows anonymous reads, for the whole bucket or for one prefix:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-bucket/public/*"
    }
  ]
}
```

```shell
aws --profile nde s3api put-bucket-policy --bucket my-bucket --policy file://policy.json
```

Objects under that prefix are then readable by anyone, however they were uploaded; the rest of the bucket stays private.
Listing and writing always need the key.
A single object can also be made public by uploading it with `--acl public-read`, but a later upload without that flag makes it private again.

The object store’s own URL for a public object includes NDE’s tenant ID: `https://objectstore.surf.nl/8cb3d6bf7f53479183d9f64c6c80a82f:<bucket>/<key>`.
Without the tenant ID it returns 403, even for a public object.

For web applications that fetch files with JavaScript, give the bucket a CORS rule:

```shell
aws --profile nde s3api put-bucket-cors --bucket my-bucket --cors-configuration \
  '{"CORSRules": [{"AllowedOrigins": ["*"], "AllowedMethods": ["GET", "HEAD"], "AllowedHeaders": ["*"]}]}'
```

## Telemetry

- **Metrics**: Applications push [OpenTelemetry](https://opentelemetry.io) metrics to SURF’s shared collector at `OTEL_EXPORTER_OTLP_ENDPOINT=http://nde-otel.monitoring.svc.cluster.local:4318`, which feeds the Prometheus datasource in SURF’s Grafana.
  `service.name` becomes the `job` label and `service.instance.id` the `instance` label, so give every replica its own instance ID, or its series overwrite the others’.
  Keep attribute values bounded: the Prometheus is shared with other tenants.
  Metrics from before the move to SURF on 29 September 2026 are archived in the private `metrics-archive` bucket of the [object store](#object-storage), whose README explains how to restore them. Daily totals of the application metrics are public at https://files.nde.nl/metrics/README.md.
- **Logs**: Collected through [Loki](https://grafana.com/oss/loki/)
- **Dashboard**: [Grafana](https://nde.monitoring.k8s.ms4.surfsara.nl) (behind login)

## Additional services

* UptimeRobot monitors our services. The status page can be found at https://status.netwerkdigitaalerfgoed.nl.
  To configure the status page, log in at the [dashboard](https://dashboard.uptimerobot.com).
  Start an announcement’s title with the service it concerns, so that service’s website can show it as a banner:
  `[DR]` Dataset Register, `[TN]` Termennetwerk, `[DKG]` Dataset Knowledge Graph, `[GN]` GeoNames.
  For now only the Dataset Register shows banners. A banner appears once the announcement is published and its start
  date has passed, and disappears at its end date or when the announcement is archived.
* Lettermint.co sends our transactional e-mail.
