# nde-app Helm Chart

Generic Helm chart for deploying NDE applications. It supports:

- Deployments and StatefulSets
- Multi-container pods
- Ingress with automatic TLS certificates
- Persistent volumes
- [ConfigMaps](#configmap)
- CronJobs
- [CNAME DNS records](#cname-dns-records)

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

## CNAME DNS Records

Create CNAME records via ExternalDNS without deploying any application:

```yaml
cnames:
  - hostname: alias.netwerkdigitaalerfgoed.nl
    target: target.example.com
```

This creates an Ingress with `external-dns.alpha.kubernetes.io/target` annotation.

## ConfigMap

Kubernetes does not automatically restart pods when a ConfigMap changes. 
This chart adds a checksum of the ConfigMap contents as a pod annotation (`checksum/config`),
ensuring pods restart when the configuration changes.
