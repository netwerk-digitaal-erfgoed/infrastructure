# nde-app Helm Chart

Generic Helm chart for deploying NDE applications. It supports:

- Deployments and StatefulSets
- Multi-container pods
- Ingress with automatic TLS certificates and HTTP-to-HTTPS redirects
- Persistent volumes
- [ConfigMaps](#configmap)
- CronJobs
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

## StatefulSets

Set `workload.type: statefulset` to get a StatefulSet instead of a Deployment.

The chart always renders `podManagementPolicy` (default `Parallel`), because Kubernetes forbids changing it on an existing StatefulSet and Helm’s three-way patch removes any field that disappears from the rendered manifest. `Parallel` lets the controller replace a pod that never became Ready, which `OrderedReady` refuses to do; that deadlock blocked two fixes to geonames-sparql in May 2026. Ordering only matters with several replicas, and every StatefulSet here runs a single one, so `Parallel` costs nothing.

StatefulSets created before this default exist with `OrderedReady`. Their releases must pin that value until the StatefulSet is recreated:

```yaml
workload:
  type: statefulset
  podManagementPolicy: OrderedReady
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

- `persistence.name` (StatefulSet single volume)
- `persistentVolumes[].name` (StatefulSet multiple volumeClaimTemplates)
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

SURF runs Velero on the cluster. Once a day it copies every annotated volume to the SURF object store, which is replicated across datacentres. NDE cannot see Velero’s state or run it: ask SURF whether a backup succeeded, and for every restore.

Velero selects whole volumes by name. It cannot include or exclude paths inside a volume ([velero#4129](https://github.com/vmware-tanzu/velero/issues/4129)), so everything on a named volume is uploaded. To back up only part of an application’s data, give that part its own volume and list only that volume:

```yaml
backup:
  enabled: true
  volumes:
    - backup

persistentVolumes:
  - name: data
    size: 10Gi
  - name: backup
    size: 5Gi
```

### When a file-level backup is safe

This is a file-system backup, not a volume snapshot. Velero reads the volume file by file while the application keeps writing, so a file can change while it is being read and the copy mixes moments.

That is safe for volumes whose files are written once and then left alone, such as uploads or a search index that is rebuilt as a whole. The Dataset Register’s QLever volume is an example: its index files only change during the nightly rebuild.

It is not safe for the data directory of a running database. Postgres and MariaDB rewrite many files continuously, and a copy that mixes moments may fail to start or be silently inconsistent. Do not enable `backup` on such a volume as it is.

### Databases: back up a dump

Back up a dump instead of the data directory:

1. Add a second volume, as in the example above, and list only that volume under `backup.volumes`.
2. Have Velero write a dump to that volume just before it copies it, with a [pre-backup hook](https://velero.io/docs/v1.17/backup-hooks/) on the pod:

   ```yaml
   pre.hook.backup.velero.io/container: app
   pre.hook.backup.velero.io/command: '["/bin/sh", "-c", "pg_dump -Fc -f /backup/db.dump.tmp mydb && mv /backup/db.dump.tmp /backup/db.dump"]'
   pre.hook.backup.velero.io/on-error: Fail
   ```

   Writing to a temporary file and renaming it keeps a failed dump from replacing the previous good one.

The chart cannot set these hook annotations yet.

### Restoring

A dump is imported into the running database, so no Kubernetes object changes and Flux is not involved. Stop the application from writing first, then run the import in the database container:

```shell
pg_restore --clean --if-exists -d mydb /backup/db.dump
```

As long as the dump you need is still on the `backup` volume, this needs neither Velero nor SURF. That covers a bad migration or an accidental delete.

Restoring a volume itself is different: Velero recreates the pod and its claim, which Flux also manages. Only a lost volume, or a dump older than the one on the volume, needs that, and SURF has to run it.
