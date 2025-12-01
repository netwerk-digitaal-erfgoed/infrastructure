## Encrypting the secret

Flux is configured with [sops-age](https://fluxcd.io/flux/guides/mozilla-sops/#encrypting-secrets-using-age).

### How it works

This uses asymmetric encryption (like SSH or GPG):

- **encryption** (done locally): uses only the **public key** — anyone can encrypt
- **decryption** (done by Flux in the cluster): uses the **private key** — only the cluster can decrypt.

The public key (`age1qnj...`) is safe to share and is embedded in the commands below. 
The private key is stored as a secret in the cluster (`sops-age` in the `flux-system` namespace) and never leaves there.

### Encrypt a secret

Create a new secrets manifest, save it as a YAML file:

```shell
kubectl create secret {type} {name} {options} -n nde --dry-run=client -o yaml > secret.yaml
```

Then encrypt the values like so:

sops --age=age1qnjmyern7zmm5wpsclrpexu327xuqalpcthuk32hj8xn5ssts96s5hhhu8 \
--encrypt --encrypted-regex '^(data|stringData)$' --in-place [name].yaml

Upload it to git, and flux will apply it in the cluster.

If you have an existing secret in a cluster, you can do the following:
- kubectl get secret [name] -o yaml > [name].yaml
- remove all metadata except name and namespace
- encrypt it using the above
