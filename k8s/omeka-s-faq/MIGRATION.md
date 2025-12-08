# Migration instructions for omeka-s-faq

## Export data from the old cluster (k8s-do)

The old cluster uses the `default` namespace.

### 1. Export MySQL database

```bash
kubectl exec omeka-s-faq-mysql-0 -- mysqldump -u root -p"$(kubectl get secret omeka-s-faq-mysql -o jsonpath='{.data.root-password}' | base64 -d)" omeka_s_faq | gzip > omeka-s-faq.sql.gz
```

### 2. Export files

```bash
kubectl exec omeka-s-faq-0 -- tar -czf - -C /var/www/html config attachments data images > omeka-s-faq-files.tar.gz
```

### 3. Upload to S3

```bash
s3cmd put omeka-s-faq.sql.gz s3://YOUR-BUCKET/
s3cmd put omeka-s-faq-files.tar.gz s3://YOUR-BUCKET/
```

## Import data to the new cluster

### 1. Generate pre-signed URLs (valid for 1 hour)

```bash
s3cmd signurl s3://YOUR-BUCKET/omeka-s-faq.sql.gz +3600
s3cmd signurl s3://YOUR-BUCKET/omeka-s-faq-files.tar.gz +3600
```

### 2. Update import-job.yaml

Replace `PRESIGNED_URL_HERE` with the generated URLs.

### 3. Apply the import jobs

Apply via the Kubernetes Dashboard (Create from YAML).

### 4. Clean up

Delete the jobs after successful import.
