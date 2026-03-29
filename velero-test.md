Generated 3 helm charts:
16:10:20 ~/code/github/nde/infrastructure (backups*) $ helm template geonames-sparql helm/nde-app -f <(yq e '.spec.values' k8s/geonames-sparql/helmrelease.yaml) > test1.yaml
16:10:54 ~/code/github/nde/infrastructure (backups*) $ helm template geonames-sparql helm/nde-app -f <(yq e '.spec.values' k8s/geonames-sparql/helmrelease.yaml) --set backup.enabled=true > test2.yaml
16:11:54 ~/code/github/nde/infrastructure (backups*) $ helm template geonames-sparql helm/nde-app -f <(yq e '.spec.values' k8s/geonames-sparql/helmrelease.yaml) --set backup.enabled=true --set backup.volumes[0]=fuseki > test3.yaml

The first one doesn't change the helmrelease, this doesn't change the helm chart either. 
The second one adds a "backup.enabled=true", this adds the annotation for velero. It picks all volumes mentioned in the helmrelease.
The third one overwrites the volumes to be backed up to a single one, so you can select specifically.

To add it in a helmrelease, add this backup block.
```
....
  values:
    workload:
      type: statefulset

    backup:
      enabled: true

    containers:
      - name: app
....
```

Optionally, mention the volumes if you want to be specific, or want to only include certain volumes.
```
....
  values:
    workload:
      type: statefulset

    backup:
      enabled: true
      volumes:
        - data
        - fuseki

    containers:
      - name: app
....
```
