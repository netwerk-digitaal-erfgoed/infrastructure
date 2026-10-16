# nde-app Helm Chart

Generic Helm chart for deploying NDE applications. It supports:

- Deployments and StatefulSets
- Multi-container pods
- Ingress with automatic TLS certificates and HTTP-to-HTTPS redirects
- Persistent volumes
- [ConfigMaps](#configmap)
- [CronJobs](#cronjobs), with init containers and sidecars
- [CNAME DNS records](#cname-dns-records)
- [Volume backups](#velero-volume-backups)

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

## CronJobs

`cronjobs[].initContainers` is passed to the pod as is, so it takes init containers and [native sidecars](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/) (an init container with `restartPolicy: Always`, which runs beside the job’s container and stops when it ends). Native sidecars need Kubernetes 1.29 or newer: before that, an init container with `restartPolicy: Always` is rejected or runs as an ordinary init container that never exits, so the job never starts. The dataset-knowledge-graph runs QLever in such a sidecar; see `k8s/dataset-knowledge-graph/helmrelease.yaml`.

Two related settings:

- `cronjobs[].restartPolicy` defaults to `OnFailure`, which restarts a failed container in the same pod. Set `Never` when the job controls a sidecar: a restarted job container would find the sidecar still running what the failed one started.
- `cronjobs[].automountServiceAccountToken: false` leaves the pod without a Kubernetes API token, for jobs that never call the API.

## StatefulSets

Set `workload.type: statefulset` to get a StatefulSet instead of a Deployment.

The chart always renders `podManagementPolicy` (default `Parallel`), because Kubernetes forbids changing it on an existing StatefulSet and Helm’s three-way patch removes any field that disappears from the rendered manifest. `Parallel` lets the controller replace a pod that never became Ready, which `OrderedReady` refuses to do; that deadlock blocked two fixes to geonames-sparql in May 2026. Ordering only matters with several replicas, and every StatefulSet here runs a single one, so `Parallel` costs nothing.

StatefulSets created before this default exist with `OrderedReady`. Their releases must pin that value until the StatefulSet is recreated:

```yaml
workload:
  type: statefulset
  podManagementPolicy: OrderedReady
```

## Deployment strategy

A Deployment rolls out with Kubernetes’ `RollingUpdate`: the new pod starts before the old one stops, so for a moment the release needs its resources twice. Where the namespace’s resource quota has no room for that, the new pod is never created, and the old one keeps serving the previous image without any error showing. Set `Recreate` to stop the old pod first, at the cost of a few seconds of downtime per rollout:

```yaml
workload:
  strategy: Recreate
```

## CNAME DNS Records

Create CNAME records via ExternalDNS without deploying any application:

```yaml
cnames:
  - hostname: alias.netwerkdigitaalerfgoed.nl
    target: target.example.com
```

This creates an Ingress with `external-dns.alpha.kubernetes.io/target` annotation.
An IP address as target yields an A record instead of a CNAME.

## ConfigMap

Kubernetes does not automatically restart pods when a ConfigMap changes. 
This chart adds a checksum of the ConfigMap contents as a pod annotation (`checksum/config`),
ensuring pods restart when the configuration changes.

## Velero Volume Backups

Velero backup annotation support is opt-in.

Default behavior (no HelmRelease changes needed):

```yaml
backup:
  enabled: false
```

Enable Velero backup annotation on pod templates:

```yaml
backup:
  enabled: true
```

When enabled, the chart sets `backup.velero.io/backup-volumes` automatically using PVC-backed volume names from:

- `persistentVolumes[].name` (StatefulSet volumeClaimTemplates)
- `volumes[].name` where `volumes[].persistentVolumeClaim` is set

You can override auto-detection with explicit names:

```yaml
backup:
  enabled: true
  volumes:
    - data
    - fuseki
```

For CronJobs, you can also set `cronjobs[].backupVolumes` to override per job.

### What gets backed up

SURF runs Velero on the cluster. Once a day, at 02:00 UTC, it copies every annotated volume to the SURF object store, which is replicated across datacentres, and keeps each backup for 30 days. NDE cannot run Velero: ask SURF for every restore. To see whether a backup succeeded, read the [`velero-status` ConfigMap](#checking-backups).

Velero selects whole volumes by name. It cannot include or exclude paths inside a volume ([velero#4129](https://github.com/vmware-tanzu/velero/issues/4129)), so everything on a named volume is uploaded. To back up only part of an application’s data, give that part its own volume and list only that volume:

```yaml
backup:
  enabled: true
  volumes:
    - uploads

persistentVolumes:
  - name: cache
    size: 10Gi
  - name: uploads
    size: 5Gi
```

Plan this when you create a StatefulSet: Kubernetes does not allow adding a volume to `persistentVolumes` afterwards.

### Checking backups

Every hour SURF writes the state of Velero’s backups for our namespace to the `velero-status` ConfigMap in `nde`. Open it in the [Kubernetes dashboard](https://nde-dashboard.ms4.surfsara.nl/c/main/configmaps/nde/velero-status). Its keys:

| Key | Contents |
|---|---|
| `summary` | One line on the latest backup, e.g. `OK, all 12 volume(s) backed up (3.4 GiB)` or `FAILED, 1 of 12 volume(s) not backed up`. |
| `last-backup` | The latest backup’s name, start and end time and expiry, with status and size per volume. A volume Velero skipped is listed as `NOT BACKED UP`. |
| `restore-points` | One line per backup still kept, `OK` or `FAILED`, with how many volumes it holds, e.g. `11/12`. |
| `restores` | Restores SURF has run in our namespace, or `none`. |
| `updated` | When the ConfigMap was last written. |

A volume marked `NOT BACKED UP` was skipped, usually because its [dump](#databases-back-up-a-dump) failed or timed out; SURF can tell you which. The previous backup of that volume is still kept. SURF is alerted when a backup fails, but check the ConfigMap after adding `backup` to a release.

### When a file-level backup is safe

This is a file-system backup, not a volume snapshot. Velero reads the volume file by file while the application keeps writing, so a file can change while it is being read and the copy mixes moments.

That is safe for volumes whose files are written once and then left alone, such as uploads or a search index that is rebuilt as a whole. The Dataset Register’s QLever volume is an example: its index files only change during the nightly rebuild.

It is not safe for the data directory of a running database. Postgres and MariaDB rewrite many files continuously, and a copy that mixes moments may fail to start or be silently inconsistent. Do not enable `backup` on such a volume as it is.

### Databases: back up a dump

Back up a dump instead of the data directory. Give the release a command that writes a consistent dump to standard output:

```yaml
backup:
  enabled: true
  dump:
    command: PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h 127.0.0.1 -U "${POSTGRES_USER:-postgres}" -Fc "${POSTGRES_DB:-${POSTGRES_USER:-postgres}}"
    size: 1Gi
```

The chart then:

- adds a `dump` container to the pod, with the image and environment of the first container. The dump runs there, so its memory does not count against the database’s limit; the command reaches the database at `127.0.0.1`.
- has Velero run the command in that container just before each backup, with a [pre-backup hook](https://velero.io/docs/v1.17/backup-hooks/). The output goes to a temporary file that replaces `/backup/dump` only when the command succeeds, so a failed dump leaves the previous one in place and fails the backup. The hook times out after 30 minutes. A database that is short on CPU can slowly creep past that limit, so a dump that keeps getting slower calls for a higher CPU limit on the database container.
- stores the dump on a volume of its own, `<release>-dump`, and backs up only that volume. `size` must fit two dumps.

The other dump commands in use are `mariadb-dump -h 127.0.0.1 -u "$MARIADB_USER" -p"$MARIADB_PASSWORD" --single-transaction "$MARIADB_DATABASE"` and `mongodump --archive --gzip --quiet`.

Do not pipe the command into another program, such as `gzip`: the shell would report the last program’s success, and a failed dump would replace the good one. Use the dump tool’s own compression option.

### Restoring

A dump is imported into the running database, so no Kubernetes object changes and Flux is not involved. Stop the application from writing first, then run the import in the `dump` container:

```shell
kubectl -n nde exec <release>-0 -c dump -- sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" pg_restore -h 127.0.0.1 -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-${POSTGRES_USER:-postgres}}" --clean --if-exists /backup/dump'
```

For MariaDB, pipe `/backup/dump` into `mariadb` with the same connection options; for MongoDB, run `mongorestore --gzip --archive=/backup/dump --drop`, where `--drop` makes it replace the collections that exist.

As long as the dump you need is still on the dump volume, this needs neither Velero nor SURF. That covers a bad migration or an accidental delete.

Restoring a volume itself is different: Velero recreates the pod and its claim, which Flux also manages. Only a lost volume, or a dump older than the one on the volume, needs that, and SURF has to run it.
