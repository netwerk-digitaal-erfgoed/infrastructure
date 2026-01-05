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

### Image automation

Flux automatically updates image tags when new versions are pushed. The `# {"$imagepolicy": ...}` comment enables this.

- NDE images (`ghcr.io/netwerk-digitaal-erfgoed/*`): checked every **1 minute**
- External images: checked every **24 hours**.

See [helm/nde-app/README.md](helm/nde-app/README.md) for configuration options.

## Secrets

Secrets are encrypted using [SOPS with age](https://fluxcd.io/flux/guides/mozilla-sops/) and stored in `k8s/secrets/`.
See [k8s/secrets/README.md](k8s/secrets/README.md) for encryption instructions.

## Telemetry

- **Metrics**: Applications push [OpenTelemetry](https://opentelemetry.io) metrics to a collector, scraped by [VictoriaMetrics](https://victoriametrics.com)
- **Logs**: Collected through [Loki](https://grafana.com/oss/loki/)
- **Dashboard**: [Grafana](https://statistieken.netwerkdigitaalerfgoed.nl) (behind login)

## Additional services

UptimeRobot monitors our services. The status page can be found at https://status.netwerkdigitaalerfgoed.nl.
To configure the status page, log in at the [dashboard](https://dashboard.uptimerobot.com).
