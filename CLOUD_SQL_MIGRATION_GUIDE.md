# Cloud SQL Migration Guide

Complete guide for migrating from self-managed PostgreSQL StatefulSet to Google Cloud SQL.

## Overview

**Goal:** Migrate from PostgreSQL StatefulSet in GKE to Cloud SQL with zero data loss and minimal downtime.

**Estimated Downtime:** 5-15 minutes (depending on database size)

**Rollback Plan:** Keep StatefulSet for 7 days as backup

## Prerequisites

- [x] Terraform configured and working
- [x] `kubectl` access to GKE cluster
- [x] `gcloud` CLI authenticated
- [x] Database password ready (will be stored in terraform.tfvars)

## Phase 1: Provision Cloud SQL (No Downtime)

### Step 1.1: Generate Database Password

```bash
# Generate a strong password
openssl rand -base64 32 > cloud_sql_password.txt

# Or use the same password as StatefulSet
kubectl get secret -n postgres postgres-credentials -o jsonpath='{.data.DB_PASSWORD}' | base64 -d > cloud_sql_password.txt
```

### Step 1.2: Configure Terraform Variables

Create or update `terraform.tfvars`:

```hcl
# Enable Cloud SQL
enable_cloud_sql = true

# Cloud SQL Configuration
cloud_sql_instance_name   = "ev-tracker-postgres"
cloud_sql_instance_tier   = "db-f1-micro"  # $13.29/month
cloud_sql_disk_size_gb    = 20
cloud_sql_database_name   = "evcost"
cloud_sql_database_user   = "evcost"
cloud_sql_database_password = "YOUR_PASSWORD_HERE"  # Use password from cloud_sql_password.txt

# Optional: Enable HA (adds ~100% cost)
# cloud_sql_availability_type = "REGIONAL"

# Optional: Increase backup retention
# cloud_sql_backup_retention_days = 14
```

**Security Note:** Never commit `terraform.tfvars` to git. It's already in `.gitignore`.

### Step 1.3: Apply Terraform

```bash
cd /path/to/ev-cost-tracker-terraform

# Initialize Cloud SQL module
terraform init

# Plan the changes
terraform plan

# Review the plan - should show:
# - google_compute_global_address.private_ip_address: Creating
# - google_service_networking_connection.private_vpc_connection: Creating
# - google_sql_database_instance.postgres: Creating
# - google_sql_database.database: Creating
# - google_sql_user.user: Creating

# Apply (takes ~10 minutes)
terraform apply
```

### Step 1.4: Verify Cloud SQL Instance

```bash
# Get instance name
gcloud sql instances list --project=ev-cost-tracker

# Check instance status
gcloud sql instances describe $(terraform output -raw cloud_sql_instance_name) --project=ev-cost-tracker

# Get connection name
terraform output cloud_sql_connection_name

# Get private IP
terraform output cloud_sql_private_ip
```

Expected output:
```
Instance: ev-tracker-postgres-abc123
Status: RUNNABLE
Private IP: 10.x.x.x
```

## Phase 2: Data Migration (Zero Downtime Test)

### Step 2.1: Install Cloud SQL Proxy Locally

```bash
# macOS
brew install cloud-sql-proxy

# Or download directly
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.0/cloud-sql-proxy.darwin.arm64
chmod +x cloud-sql-proxy
```

### Step 2.2: Start Cloud SQL Proxy

```bash
# Get connection name from Terraform
CONNECTION_NAME=$(cd /path/to/ev-cost-tracker-terraform && terraform output -raw cloud_sql_connection_name)

# Start proxy (in separate terminal)
cloud-sql-proxy --private-ip $CONNECTION_NAME --port 5433

# Leave this running
```

### Step 2.3: Export Data from StatefulSet

```bash
# Port-forward to StatefulSet
kubectl port-forward -n postgres statefulset/postgres 5432:5432

# In another terminal, export database
export PGPASSWORD=$(kubectl get secret -n postgres postgres-credentials -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)

pg_dump -h localhost -p 5432 -U evcost -d evcost \
  --format=custom \
  --no-owner \
  --no-acl \
  --verbose \
  --file=evcost_backup_$(date +%Y%m%d_%H%M%S).dump

# Check backup size
ls -lh evcost_backup_*.dump
```

### Step 2.4: Import Data to Cloud SQL

```bash
# Cloud SQL Proxy should be running on port 5433

# Import database
export PGPASSWORD="YOUR_CLOUD_SQL_PASSWORD"

pg_restore -h localhost -p 5433 -U evcost -d evcost \
  --verbose \
  --no-owner \
  --no-acl \
  evcost_backup_*.dump

# Verify import
psql -h localhost -p 5433 -U evcost -d evcost -c "\dt"
psql -h localhost -p 5433 -U evcost -d evcost -c "SELECT COUNT(*) FROM charging_sessions;"
```

### Step 2.5: Test Cloud SQL Connection from GKE

```bash
# Create test pod with psql client
kubectl run -n api psql-test --image=postgres:16-alpine --rm -it --restart=Never -- bash

# Inside the pod, install curl
apk add curl

# Download Cloud SQL Proxy
curl -o /tmp/cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.0/cloud-sql-proxy.linux.amd64
chmod +x /tmp/cloud-sql-proxy

# Start proxy (get connection name from Terraform output)
/tmp/cloud-sql-proxy --private-ip PROJECT:REGION:INSTANCE &

# Test connection
PGPASSWORD="YOUR_CLOUD_SQL_PASSWORD" psql -h localhost -U evcost -d evcost -c "SELECT COUNT(*) FROM charging_sessions;"

# Exit pod
exit
```

## Phase 3: Update Application Configuration (Minimal Downtime)

### Step 3.1: Prepare GitOps Configuration

We need to:
1. Add Cloud SQL Proxy sidecar to Gateway and Session Service
2. Update connection strings
3. Keep StatefulSet running as fallback

#### Option A: Cloud SQL Proxy Sidecar (Recommended)

Create `apps/api/gateway/ev-tracker-gke-prod/cloud-sql-proxy-patch.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gateway
  namespace: api
spec:
  template:
    spec:
      serviceAccountName: api-sa  # Needs Cloud SQL Client role
      containers:
        - name: gateway
          # ... existing config ...
          env:
            - name: DB_HOST
              value: "localhost"  # Cloud SQL Proxy sidecar
            - name: DB_PORT
              value: "5432"
        # Add Cloud SQL Proxy sidecar
        - name: cloud-sql-proxy
          image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.8.0
          args:
            - "--private-ip"
            - "PROJECT:REGION:INSTANCE"  # Replace with actual connection name
            - "--port=5432"
          securityContext:
            runAsNonRoot: true
            allowPrivilegeEscalation: false
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              memory: 128Mi
```

Apply the same for Session Service.

#### Option B: Private IP Connection (No Proxy)

Update DB_HOST to use Cloud SQL private IP:

```yaml
env:
  - name: DB_HOST
    value: "10.x.x.x"  # Cloud SQL private IP from Terraform output
```

**Pros:** No sidecar overhead, direct connection
**Cons:** Requires SSL configuration, less secure than proxy

### Step 3.2: Update Secrets

```bash
# Update postgres-credentials secret with Cloud SQL password
kubectl create secret generic postgres-credentials \
  --from-literal=DB_HOST=localhost \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=evcost \
  --from-literal=DB_USER=evcost \
  --from-literal=DB_PASSWORD="YOUR_CLOUD_SQL_PASSWORD" \
  --namespace=api \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Step 3.3: Planned Cutover (5-15 minutes downtime)

**Schedule:** Pick a low-traffic time (e.g., 2am CET Sunday)

```bash
# 1. Final sync: Export fresh backup from StatefulSet
kubectl port-forward -n postgres statefulset/postgres 5432:5432 &
pg_dump -h localhost -p 5432 -U evcost -d evcost --format=custom --file=final_backup.dump

# 2. Stop write traffic (scale down to 0)
kubectl scale deployment/gateway -n api --replicas=0
kubectl scale deployment/session-service -n api --replicas=0

# 3. Import final backup to Cloud SQL
pg_restore -h localhost -p 5433 -U evcost -d evcost --clean final_backup.dump

# 4. Apply GitOps changes (add Cloud SQL Proxy sidecar)
git push  # Flux will apply changes

# 5. Scale back up
kubectl scale deployment/gateway -n api --replicas=1
kubectl scale deployment/session-service -n api --replicas=1

# 6. Monitor logs
kubectl logs -n api deployment/gateway -f
kubectl logs -n api deployment/session-service -f

# 7. Test application
curl https://api.evtracker.cz/api/version
# Open browser: https://evtracker.cz
```

### Step 3.4: Verify Migration Success

```bash
# Check pod status
kubectl get pods -n api

# Check database connections
kubectl logs -n api deployment/gateway | grep -i "database\|connection"
kubectl logs -n api deployment/session-service | grep -i "database\|connection"

# Test API endpoints
curl -H "Authorization: Bearer $TOKEN" https://api.evtracker.cz/api/charging-sessions

# Monitor for errors
kubectl logs -n api deployment/gateway --tail=100
kubectl logs -n api deployment/session-service --tail=100
```

## Phase 4: Cleanup (After 7 Days)

**Wait 7 days** to ensure Cloud SQL is stable and no issues arise.

### Step 4.1: Final Backup from StatefulSet

```bash
# One last backup for safety
kubectl port-forward -n postgres statefulset/postgres 5432:5432 &
pg_dump -h localhost -p 5432 -U evcost -d evcost --format=custom --file=statefulset_final_backup.dump

# Store in GCS for long-term retention
gsutil cp statefulset_final_backup.dump gs://YOUR_BACKUP_BUCKET/postgres/statefulset_final_backup.dump
```

### Step 4.2: Delete StatefulSet

```bash
# Delete StatefulSet (keeps PVC)
kubectl delete statefulset -n postgres postgres

# After another 7 days, delete PVC
kubectl delete pvc -n postgres postgres-data-postgres-0

# Remove from GitOps
cd /path/to/ev-cost-tracker-gitops
git rm -r infrastructure/postgres/
git rm clusters/ev-tracker-gke-prod/postgres.yaml
git commit -m "chore: remove PostgreSQL StatefulSet (migrated to Cloud SQL)"
git push
```

## Rollback Plan

If issues arise during migration:

### Immediate Rollback (During Cutover)

```bash
# 1. Scale down Cloud SQL-connected pods
kubectl scale deployment/gateway -n api --replicas=0
kubectl scale deployment/session-service -n api --replicas=0

# 2. Revert connection strings to StatefulSet
kubectl create secret generic postgres-credentials \
  --from-literal=DB_HOST=postgres.postgres.svc.cluster.local \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=evcost \
  --from-literal=DB_USER=evcost \
  --from-literal=DB_PASSWORD="ORIGINAL_PASSWORD" \
  --namespace=api \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Revert GitOps changes
git revert HEAD
git push

# 4. Scale back up
kubectl scale deployment/gateway -n api --replicas=1
kubectl scale deployment/session-service -n api --replicas=1
```

### Rollback After Migration (Within 7 Days)

```bash
# 1. Scale down applications
kubectl scale deployment/gateway -n api --replicas=0
kubectl scale deployment/session-service -n api --replicas=0

# 2. Export fresh data from Cloud SQL
pg_dump -h localhost -p 5433 -U evcost -d evcost --format=custom --file=cloud_sql_rollback.dump

# 3. Import to StatefulSet
kubectl port-forward -n postgres statefulset/postgres 5432:5432 &
pg_restore -h localhost -p 5432 -U evcost -d evcost --clean cloud_sql_rollback.dump

# 4. Revert connection strings (same as above)

# 5. Scale back up
```

## Monitoring Post-Migration

### Cloud SQL Metrics to Watch

```bash
# Cloud Console
https://console.cloud.google.com/sql/instances/ev-tracker-postgres-xxx/overview?project=ev-cost-tracker

# Key metrics:
# - CPU utilization (should be <80%)
# - Memory utilization (should be <80%)
# - Active connections (should be <20)
# - Disk utilization
# - Read/write operations per second
```

### GKE Application Metrics

```bash
# Check database connection pool
kubectl logs -n api deployment/session-service | grep -i "HikariPool"

# Monitor query performance
# Cloud Console → SQL → Query Insights
```

## Cost Monitoring

### Before Migration (StatefulSet)
- GKE Pod: ~$19.40/month
- Total: **$19.40/month**

### After Migration (Cloud SQL db-f1-micro)
- Cloud SQL: ~$13.29/month
- Total: **$13.29/month**

**Monthly Savings: $6.11**
**Annual Savings: $73.32**

### Enable Billing Alerts

```bash
# Already configured in monitoring module
# Alert at $50/month total spend
```

## Troubleshooting

### Issue: Connection Refused

```bash
# Check Cloud SQL Proxy logs
kubectl logs -n api deployment/gateway -c cloud-sql-proxy

# Common causes:
# - Wrong connection name
# - Missing IAM permission (Cloud SQL Client role)
# - Private IP not configured
```

### Issue: Authentication Failed

```bash
# Verify password
kubectl get secret -n api postgres-credentials -o jsonpath='{.data.DB_PASSWORD}' | base64 -d

# Check Cloud SQL user
gcloud sql users list --instance=ev-tracker-postgres-xxx --project=ev-cost-tracker
```

### Issue: SSL/TLS Errors

Cloud SQL Proxy handles SSL automatically. If using direct private IP connection:

```yaml
env:
  - name: DB_SSL_MODE
    value: "require"
```

### Issue: Performance Degradation

db-f1-micro is a shared-core instance. If you see throttling:

```bash
# Upgrade to db-g1-small ($30.93/month)
cd /path/to/ev-cost-tracker-terraform
vim terraform.tfvars  # Set cloud_sql_instance_tier = "db-g1-small"
terraform apply
```

## Next Steps

After successful migration:

1. ✅ Monitor for 7 days
2. ✅ Delete StatefulSet and PVC
3. ✅ Update documentation
4. ✅ Consider enabling HA (REGIONAL availability)
5. ✅ Review backup retention (7-30 days)
6. ✅ Set up monitoring alerts

## Support

If you encounter issues:
- Check Cloud SQL logs: `gcloud sql operations list --instance=INSTANCE_NAME`
- Review GKE logs: `kubectl logs -n api deployment/gateway`
- Check Terraform state: `terraform show`
- GCP Support: https://cloud.google.com/support

## Summary

| Phase | Duration | Downtime | Risk |
|-------|----------|----------|------|
| 1. Provision Cloud SQL | ~15 min | None | Low |
| 2. Data Migration Test | ~30 min | None | Low |
| 3. Cutover | ~10 min | **5-15 min** | Medium |
| 4. Monitoring | 7 days | None | Low |
| 5. Cleanup | ~10 min | None | Low |

**Total Effort:** 3-4 hours
**Total Downtime:** 5-15 minutes
**Rollback Time:** <5 minutes
