# NDE App Helm Chart

A Helm chart for deploying NDE applications as Deployments or StatefulSets, with built-in support for Flux image automation.

## Features

- Deployment or StatefulSet workloads
- Multi-container pod support
- Flux image automation (ImageRepository + ImagePolicy)
- Multiple ingresses with automatic TLS
- CronJob support
- Persistent storage (StatefulSet)

## Usage with Flux

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: my-app
spec:
  interval: 30m
  chart:
    spec:
      chart: helm/nde-app
      sourceRef:
        kind: GitRepository
        name: nde
  values:
    containers:
      - name: app
        image:
          repository: ghcr.io/my-org/my-app
          tag: latest # {"$imagepolicy": "nde:my-app:tag"}
        port: 8080
        livenessProbe:
          httpGet: {}
        readinessProbe:
          httpGet: {}
        flux:
          enabled: true

    ingresses:
      - hosts:
          - my-app.example.com
```

## Values

### Workload

| Value | Description | Default |
|-------|-------------|---------|
| `workload.type` | `deployment` or `statefulset` | `deployment` |
| `workload.replicas` | Number of replicas | `1` |

### Containers

| Value | Description | Default |
|-------|-------------|---------|
| `containers[].name` | Container name | `app` |
| `containers[].image.repository` | Image repository (required) | `""` |
| `containers[].image.tag` | Image tag | `latest` |
| `containers[].port` | Container port | `80` |
| `containers[].env` | Environment variables | `[]` |
| `containers[].volumeMounts` | Volume mounts | `[]` |
| `containers[].resources` | Resource requests/limits | See values.yaml |
| `containers[].livenessProbe` | Liveness probe config | httpGet on `/` |
| `containers[].readinessProbe` | Readiness probe config | httpGet on `/` |

#### Probes

Probe ports default to the container's `port`. Specify `httpGet: {}` for defaults:

```yaml
livenessProbe:
  httpGet: {}        # path: /, port: <container port>
readinessProbe:
  httpGet:
    path: /health    # custom path, port defaults to container port
```

Supported probe type: `httpGet`.

### Flux Image Automation

| Value | Description | Default |
|-------|-------------|---------|
| `containers[].flux.enabled` | Enable Flux image automation | `false` |
| `containers[].flux.interval` | Image scan interval | `1m` |
| `containers[].flux.policy.type` | `numerical` or `semver` | `numerical` |
| `containers[].flux.policy.range` | Semver range (required for semver) | `""` |

### Service

| Value | Description | Default |
|-------|-------------|---------|
| `service.port` | Service port | `80` |
| `service.targetPort` | Target port | First container's port |

### Ingress

| Value | Description | Default |
|-------|-------------|---------|
| `ingress.annotations` | Shared annotations for first ingress | cert-manager config |
| `ingresses` | List of ingress definitions | `[]` |
| `ingresses[].hosts` | List of hostnames | Required |
| `ingresses[].name` | Ingress name | Release name (first), required (others) |
| `ingresses[].className` | Ingress class | Not set |
| `ingresses[].annotations` | Additional annotations | `{}` |
| `ingresses[].paths` | Path definitions | `[{path: /, pathType: Prefix}]` |
| `ingresses[].tls.secretName` | TLS secret name | `{name}-tls` |

### Persistence (StatefulSet only)

| Value | Description | Default |
|-------|-------------|---------|
| `persistence.enabled` | Enable persistent storage | `false` |
| `persistence.storageClass` | Storage class | `hdd` |
| `persistence.size` | Volume size | `1Gi` |
| `persistence.name` | Volume name | `data` |
| `persistence.mountPath` | Mount path | `/data` |

### CronJobs

| Value | Description | Default |
|-------|-------------|---------|
| `cronjobs` | List of cronjob definitions | `[]` |
| `cronjobs[].name` | CronJob name suffix (required) | - |
| `cronjobs[].schedule` | Cron schedule (required) | - |
| `cronjobs[].image` | Container image (required) | - |
| `cronjobs[].imagePullPolicy` | Pull policy | Not set |
| `cronjobs[].command` | Command | `[]` |
| `cronjobs[].args` | Arguments | `[]` |
| `cronjobs[].env` | Environment variables | `[]` |
| `cronjobs[].restartPolicy` | Restart policy | `OnFailure` |

Note: Images starting with `ghcr.io` automatically use the `ghcr` imagePullSecret.

### Other

| Value | Description | Default |
|-------|-------------|---------|
| `imagePullSecrets` | Image pull secrets (ghcr.io auto-detected) | `[]` |
| `securityContext` | Pod security context | `{}` |

## Examples

### Simple Deployment

```yaml
containers:
  - name: app
    image:
      repository: nginx
      tag: latest
    port: 80
    livenessProbe:
      httpGet: {}
    readinessProbe:
      httpGet: {}

ingresses:
  - hosts:
      - my-app.example.com
```

### StatefulSet with Persistence

```yaml
workload:
  type: statefulset

containers:
  - name: app
    image:
      repository: postgres
      tag: "15"
    port: 5432
    volumeMounts:
      - name: data
        mountPath: /var/lib/postgresql/data

persistence:
  enabled: true
  size: 10Gi
```

### Multi-container Pod

```yaml
containers:
  - name: nginx
    image:
      repository: nginx
      tag: latest
    port: 80

  - name: php
    image:
      repository: php
      tag: fpm
    port: 9000
```

### Semver Image Policy

```yaml
containers:
  - name: app
    image:
      repository: my-app
      tag: v1.0.0
    flux:
      enabled: true
      policy:
        type: semver
        range: ">=1.0.0 <2.0.0"
```
