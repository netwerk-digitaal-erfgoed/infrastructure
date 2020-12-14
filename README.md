# NDE Infrastructure

This repository contains generic infrastructure configuration
for running NDE applications in a Kubernetes cluster.

The configuration is based on existing documentation, in particular
[How to Set Up an Nginx Ingress with Cert-Manager on DigitalOcean Kubernetes](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-nginx-ingress-with-cert-manager-on-digitalocean-kubernetes)
and [How To Set Up an Nginx Ingress on DigitalOcean Kubernetes Using Helm](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-nginx-ingress-on-digitalocean-kubernetes-using-helm),
with as few modifications as possible.

We apply this configuration to a
[DigitalOcean managed Kubernetes cluster](https://www.digitalocean.com/products/kubernetes/).

## Included

While each application should take care of deploying itself,
this repository contains the generic configuration
for making each application available on the web.

This generic infrastructure includes:

- ingress configuration for routing hostnames to applications
- auto-provisioning and renewal of a Let’s Encrypt TLS certificate for each hostname.

## Making changes

We make changes to the infrastructure through declarative configuration files. 
So to change the infrastructure, just follow your regular Git workflow:

1. clone this repository;
2. make changes to any of the Kubernetes manifests, which you can find in the `k8s/` directory;
3. push your changes pack to GitHub.

A [GitHub action](.github/workflows/deploy.yml) then automatically applies the changes to our Kubernetes cluster.

## Set up a DigitalOcean cluster from scratch

Start by creating a Kubernetes cluster in the DigitalOcean web interface.

Then set up requirements:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.35.0/deploy/static/provider/do/deploy.yaml
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.yaml
kubectl annotate -n ingress-nginx service ingress-nginx-controller service.beta.kubernetes.io/do-loadbalancer-hostname="kubernetes.netwerkdigitaalerfgoed.nl"
```

Create secrets so Kubernetes can pull from the GitHub container registry:

```bash
kubectl create secret docker-registry regcred --docker-server=docker.pkg.github.com --docker-username=YOUR_GITHUB_USERNAME --docker-password=ACCESS_TOKEN_FROM_GITHUB_WITH_READ_PACKAGES_PERMISSION --docker-email=YOUR_GITHUB_EMAIL
kubectl create secret docker-registry ghcr --docker-server=ghcr.io --docker-username=YOUR_GITHUB_USERNAME --docker-password=ACCESS_TOKEN_FROM_GITHUB_WITH_READ_PACKAGES_PERMISSION --docker-email=YOUR_GITHUB_EMAIL
```

Finally, apply the configuration from this repository by cloning it and then running:

```bash
kubectl apply -R -f k8s
```

### DNS

Configure an A record for each application hostname and for `kubernetes.netwerkdigitaalerfgoed.nl`
pointing to your load balancer’s public IP address. Our current settings are (`kubectl get ingress`):

Load balancer public IP address: `178.128.138.52`.

Hostnames:

- demo.netwerkdigitaalerfgoed.nl
- ldwizard.netwerkdigitaalerfgoed.nl
- termennetwerk.netwerkdigitaalerfgoed.nl
- termennetwerk-api.netwerkdigitaalerfgoed.nl
