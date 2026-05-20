## Kubernetes cluster

* This infrastructure is deployed in a Kubernetes cluster managed by SURF.
* Changes can only be deployed through GitOps (Flux); we do not have access to `kubectl` except for `kubectl exec`.
* To kill a stuck process, we can use `kill 1` from inside the pod.
* ExternalDNS automatically creates DNS entries.


## Ingress

* Ingresses typically use hostnames <app>.netwerkdigitaalerfgoed.nl.

## When migrating to the new Helm release setup:

- don't carry over the cluster issuer
- always enable Flux.
- always include serviceAccountName: nde in the helmrelease.yaml file
- don't carry over the do-block-storage annotation. 
- always run Helm template to compare the new Helm release.yaml file against the old manual Kubernetes YAML manifest files.
- remove ingressClassName nginx

## When editing the nde-app Helm Chart

- Verify each change by running `helm template` to verify only intended changes end up in the generated manifest.
  Report any and all unintended changes.

## When writing `helmrelease.yaml` files:

- remove everything that comes down to the defaults from the nde-app Helm chart.

## Unsticking a stuck rollout

When a HelmRelease upgrade is stuck (e.g. `helm upgrade` failing repeatedly because a pod is in `CrashLoopBackOff` and never becomes `Ready`), the common temptation is to add `spec.upgrade.force: true`. **Don't.**

### Why `force: true` is the wrong tool

- helm's `--force` switches the upgrade strategy from `Patch` (3-way merge — preserves fields outside the template) to `Replace` (PUT semantics — overwrites the object with exactly what the chart renders).
- `Replace` **wipes any fields not in the chart template**, including fields set by cluster admission webhooks (e.g. `Ingress.spec.ingressClassName` injected by the default IngressClass webhook on Create).
- In practice (helm 3 on this cluster) `--force` does NOT delete-and-recreate StatefulSets for typical spec changes — so it doesn't actually unstick `OrderedReady` rollouts the way one might hope.
- Net effect: it rarely solves the rollout problem and frequently introduces new bugs by silently removing admission-injected configuration.

### What actually unsticks a CrashLoopBackOff + OrderedReady deadlock

Scale to 0, then scale back up, both via GitOps:

1. Push a commit setting `workload.replicas: 0` in the helmrelease values.
2. Wait for Flux + kustomize-controller + helm-controller to reconcile (a few minutes). The StatefulSet controller terminates the failing pod cleanly.
3. Push a follow-up commit restoring `workload.replicas: 1` (or removing the override).
4. The StatefulSet controller creates a fresh pod against the *current* (intended) spec — no OrderedReady wait on the previous unhealthy pod.

This works because scaling to 0 lets the SS controller terminate the pod without needing it to first reach `Ready`, which is what `OrderedReady` would otherwise require for an in-place update.

### Companion change: `spec.upgrade.disableWait: true`

Independent of force, `disableWait: true` is genuinely useful when an upgrade gets stuck waiting on Ready. It tells helm to return successfully as soon as the spec is applied, instead of blocking up to 5 minutes for pods to become ready and failing the upgrade. Avoids retry storms while you do the scale-0/scale-1 dance.

## Data migration

  So when any data needs to be migrated, for instance a MySQL database, create a one-off job that imports the data from an S3 URL.
- Make sure the job has cURL installed for downloading from the presigned S3 URL.
- Document the export for the migration from the current cluster, which uses the default Kubernetes namespace.

## Secrets

* See @k8s/secrets/README.md on how to encrypt secrets.
* Add secrets to the k8s/secrets directory.
