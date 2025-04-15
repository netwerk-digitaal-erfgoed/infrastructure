## Automating deployment with Flux

For each image being used, you create 3 flux resources.  
In all cases, make sure the namespace is set to "nde".

### ImageRepository

This configures where the image comes from. You can re-use the image container pull secret you use in the deployments.  

```
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: example
  namespace: nde
spec:
  image: ghcr.io/netwerk-digitaal-erfgoed/example
  interval: 5h
  secretRef:
    name: ghcr
```

### ImagePolicy

This configures how to select the correct image tag from the image repository.  
You can do it simply with selecting the patch version (as shown down here), or complex with regex.  
More info: https://fluxcd.io/flux/guides/image-update/#imagepolicy-examples

```
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: example-policy
  namespace: nde
spec:
  imageRepositoryRef:
    name: example
  policy:
    semver:
      range: ">=1.0.0"
```

### ImageUpdateAutomation

This configures where the update is being done (in our case, this repository), how often it should check, and what commit message / branch to use.  
You can also suspend the automation in case of an incident.  

```
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageUpdateAutomation
metadata:
  name: example-update
  namespace: nde
spec:
  suspend: false
  interval: 30m
  sourceRef:
    kind: GitRepository
    name: nde
  git:
    commit:
      author:
        email: fluxcdbot@users.noreply.github.com
        name: fluxcdbot
      messageTemplate: '{{range .Changed.Changes}}{{print .OldValue}} -> {{println .NewValue}}{{end}}'
    push:
      branch: example
  update:
    path: ./k8s
```

### The file to actually edit

Now all that remains is to set a marker at the image:tag so flux knows what to update.  
This works on every location where there is an image, like a deployment, cronjob or stateful set.  

The format is `# {"$imagepolicy": "<policy-namespace>:<policy-name>"}`, where the policy namespace should be nde, and the policy name depends on your own configuration.  

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example
spec:
  replicas: 2
  selector:
    matchLabels:
      app: example
  template:
    metadata:
      labels:
        app: example
    spec:
      containers:
        - name: app
          image: ghcr.io/netwerk-digitaal-erfgoed/example:latest  # {"$imagepolicy": "nde:example-policy:tag"}
```