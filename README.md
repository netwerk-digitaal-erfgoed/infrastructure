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

## Set up a DigitalOcean cluster from scratch

Start by creating a Kubernetes cluster in the DigitalOcean web interface.

Then set up requirements:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.35.0/deploy/static/provider/do/deploy.yaml
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v0.16.0/cert-manager.yaml
kubectl annotate -n ingress-nginx service ingress-nginx-controller service.beta.kubernetes.io/do-loadbalancer-hostname="kubernetes.netwerkdigitaalerfgoed.nl"
```

And apply the configuration from this repository by cloning it and then running:

```bash
kubectl apply -f .
```

### DNS

Configure an A record for each application hostname and for `kubernetes.netwerkdigitaalerfgoed.nl`
pointing to your load balancer’s public IP address. 
