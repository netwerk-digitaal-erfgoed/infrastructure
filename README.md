# NDE Infrastructure

This repository contains generic infrastructure configuration for running NDE applications in a Kubernetes cluster.

This configuration follows the [CLARIAH Infrastructure Requirements](https://github.com/CLARIAH/clariah-plus/blob/main/requirements/infrastructure-requirements.md).
It is based on existing documentation, in particular
[How to Set Up an Nginx Ingress with Cert-Manager on DigitalOcean Kubernetes](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-nginx-ingress-with-cert-manager-on-digitalocean-kubernetes)
and [How To Set Up an Nginx Ingress on DigitalOcean Kubernetes Using Helm](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-nginx-ingress-on-digitalocean-kubernetes-using-helm), with as few modifications as possible.

We apply this configuration to a
[DigitalOcean managed Kubernetes cluster](https://www.digitalocean.com/products/kubernetes/).

For running software in the NDE infrastructure, it must meet the [NDE Software Requirements](doc/software-requirements.md).

## Included

While each application should take care of deploying itself, this repository contains the generic configuration for
making each application available on the web.

This generic infrastructure includes:

- ingress configuration for routing hostnames to applications
- auto-provisioning and renewal of a Let’s Encrypt TLS certificate for each hostname.

## Making changes

We make changes to the infrastructure through declarative configuration files. So to change the infrastructure, just
follow your regular Git workflow:

1. clone this repository;
2. make changes to any of the Kubernetes manifests, which you can find in the `k8s/` directory;
3. push your changes pack to GitHub.

A [GitHub action](.github/workflows/deploy.yml) then automatically applies the changes to our Kubernetes cluster.

## Set up a DigitalOcean cluster from scratch

Start by creating a Kubernetes cluster in the DigitalOcean web interface.

Then set up requirements:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/do/deploy.yaml
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.yaml
kubectl annotate -n ingress-nginx service ingress-nginx-controller service.beta.kubernetes.io/do-loadbalancer-hostname="kubernetes.netwerkdigitaalerfgoed.nl"
```

Create secrets so Kubernetes can pull from the GitHub container registry:

```bash
kubectl create secret docker-registry regcred --docker-server=docker.pkg.github.com --docker-username=YOUR_GITHUB_USERNAME --docker-password=ACCESS_TOKEN_FROM_GITHUB_WITH_READ_PACKAGES_PERMISSION --docker-email=YOUR_GITHUB_EMAIL
kubectl create secret docker-registry ghcr --docker-server=ghcr.io --docker-username=YOUR_GITHUB_USERNAME --docker-password=ACCESS_TOKEN_FROM_GITHUB_WITH_READ_PACKAGES_PERMISSION --docker-email=YOUR_GITHUB_EMAIL
```

Apply the OpenTelemetry Operator:

```bash
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
```

Finally, apply the configuration from this repository by cloning it and then running:

```bash
kubectl apply -R -f k8s
```

### Telemetry

Our applications push [OpenTelemetry](https://opentelemetry.io) metrics to an
OpenTelemetry collector, which is deployed through the [OpenTelemetry Kubernetes Operator](https://opentelemetry.io/docs/platforms/kubernetes/operator/).

A [VictoriaMetrics](https://victoriametrics.com) agent scrapes
the OpenTelemetry collector for metrics and stores them in a VictoriaMetrics database.

Logs are collected through [Loki](https://grafana.com/oss/loki/).

Both metrics and logs are available in our [Grafana dashboard](https://statistieken.netwerkdigitaalerfgoed.nl) (behind login).

### Backups

We back up cluster data using [Velero](https://velero.io).
Our configuration is based on the [DigitalOcean tutorial](https://www.digitalocean.com/community/tutorials/how-to-back-up-and-restore-a-kubernetes-cluster-on-digitalocean-using-velero)
but uses the [Velero Helm Chart](https://github.com/vmware-tanzu/helm-charts) for installation.

To install Velero into the cluster, open the [helm/velero/values.yaml file](helm/velero/values.yaml) and:

- change `bucket` to your DigitalOcean Space’s name;
- enter your DigitalOcean access token for `DIGITALOCEAN_TOKEN`;
- enter your S3 credentials under `secretContents` (do not commit these credentials to source control).

Then run:

```
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm install velero vmware-tanzu/velero --namespace velero --create-namespace -f helm/velero/values.yaml
```

We use [CSI Volume Snapshots](https://velero.io/blog/csi-integration/), which will we be listed
at https://cloud.digitalocean.com/images/snapshots/volumes.

For more information, see [How To Back Up and Restore a Kubernetes Cluster on DigitalOcean Using Velero](https://www.digitalocean.com/community/tutorials/how-to-back-up-and-restore-a-kubernetes-cluster-on-digitalocean-using-velero)
but note that we’re using Helm instead.

### DNS

Configure an A record for each application hostname and for `kubernetes.netwerkdigitaalerfgoed.nl`
pointing to your load balancer’s public IP address. Our current settings are (`kubectl get ingress`):

Load balancer public IP address: `178.128.138.52`.

Hostnames:

- demo.netwerkdigitaalerfgoed.nl
- ldwizard.netwerkdigitaalerfgoed.nl
- termennetwerk.netwerkdigitaalerfgoed.nl
- termennetwerk-api.netwerkdigitaalerfgoed.nl


test write access
