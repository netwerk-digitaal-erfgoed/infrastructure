# nde-app Helm Chart

Generic Helm chart for deploying NDE applications. It supports:

- Deployments and StatefulSets
- Multi-container pods
- Ingress with automatic TLS certificates
- Persistent volumes
- ConfigMaps
- CronJobs

## Persistent Volumes

Use `persistentVolumes` for storage. It works with all workload types:

```yaml
persistentVolumes:
  - name: data
    size: 50Gi
    mountPath: /data          # Optional - only used for CronJob auto-wiring
    storageClass: hdd         # Optional, defaults to hdd
    accessMode: ReadWriteOnce # Optional, defaults to ReadWriteOnce
```

**Behavior by workload type:**

| Workload | What's created |
|----------|---------------|
| StatefulSet | volumeClaimTemplates (manual volumeMounts in container) |
| Deployment | PVC (manual volumes + volumeMounts in container) |
| CronJob | PVC + volume + volumeMount (auto-wired if mountPath set) |

**StatefulSet example** (manual volumeMounts):

```yaml
workload:
  type: statefulset
containers:
  - name: app
    image:
      repository: postgres
      tag: "16"
    volumeMounts:
      - name: data
        mountPath: /var/lib/postgresql/data
persistentVolumes:
  - name: data
    size: 50Gi
```

**CronJob example** (auto-wired):

```yaml
persistentVolumes:
  - name: imports
    size: 100Gi
    mountPath: /app/imports   # Auto-creates volume + volumeMount
cronjobs:
  - name: importer
    schedule: "0 4 * * *"
    image: my-image:latest
    # No volumes/volumeMounts needed - auto-wired from persistentVolumes
```

## Flux Image Automation

Flux image automation is **enabled by default** for all containers. This automatically updates image tags when new versions are pushed.

- For `ghcr.io/netwerk-digitaal-erfgoed/*` images: checks every **1 minute**
- For external images (mariadb, mongo, etc.): checks every **24 hours**

To disable for a specific container:

```yaml
containers:
  - name: app
    image:
      repository: some-image
      tag: "1.0.0"
    flux:
      enabled: false
```

To use semver for external images:

```yaml
containers:
  - name: mariadb
    image:
      repository: mariadb
      tag: "10.11.3"
    flux:
      policy:
        type: semver
        range: "~10.11"  # Only patch updates
```

## Ingresses

The first ingress gets TLS auto-configured. Additional ingresses need explicit `tls.enabled: true`:

```yaml
ingresses:
  - hosts:
      - app.example.com
    # First ingress: TLS enabled automatically
  - name: redirect
    hosts:
      - old.example.com
    tls:
      enabled: true  # Required for non-first ingresses
    annotations:
      nginx.ingress.kubernetes.io/permanent-redirect: https://app.example.com
```

For regex paths, use `pathType: ImplementationSpecific`:

```yaml
ingresses:
  - hosts:
      - app.example.com
    annotations:
      nginx.ingress.kubernetes.io/rewrite-target: /$1
      nginx.ingress.kubernetes.io/use-regex: "true"
    paths:
      - path: /api/(.*)
        pathType: ImplementationSpecific  # Required for regex
```
