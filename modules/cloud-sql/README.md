# Cloud SQL Terraform Module

Google Cloud SQL PostgreSQL instance with best practices for production.

## Features

- ✅ PostgreSQL 16
- ✅ Private IP only (no public exposure)
- ✅ Automatic daily backups with configurable retention
- ✅ Point-in-time recovery (PITR)
- ✅ Auto storage resize (no disk full errors)
- ✅ SSL/TLS enforced
- ✅ Query insights enabled
- ✅ Maintenance windows configured
- ✅ Deletion protection
- ✅ IAM integration with GKE Workload Identity
- ✅ Optimized PostgreSQL flags for instance size

## Usage

```hcl
module "cloud_sql" {
  source = "./modules/cloud-sql"

  project_id        = "ev-cost-tracker"
  region            = "europe-west1"
  instance_name     = "my-postgres"
  database_name     = "mydb"
  database_user     = "myuser"
  database_password = var.db_password  # Sensitive!
  gke_sa_email      = module.gke.service_account_email

  # Optional overrides
  instance_tier              = "db-f1-micro"  # or db-g1-small, db-custom-1-3840
  availability_type          = "ZONAL"        # or REGIONAL for HA
  disk_size_gb               = 20
  backup_retention_days      = 7
  enable_point_in_time_recovery = true
  deletion_protection        = true
}
```

## Instance Tiers

| Tier | vCPUs | Memory | Monthly Cost | Use Case |
|------|-------|--------|--------------|----------|
| **db-f1-micro** | Shared | 614 MB | **$13.29** | Dev, small workloads |
| db-g1-small | Shared | 1.7 GB | $30.93 | Medium workloads |
| db-custom-1-3840 | 1 dedicated | 3.75 GB | $64.80 | Production |
| db-custom-2-7680 | 2 dedicated | 7.5 GB | $129.60 | Large workloads |

**High Availability (REGIONAL):** Adds ~100% to cost but provides automatic failover.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_id` | string | (required) | GCP project ID |
| `region` | string | (required) | GCP region |
| `instance_name` | string | `ev-tracker-postgres` | Instance name (random suffix added) |
| `database_version` | string | `POSTGRES_16` | PostgreSQL version |
| `instance_tier` | string | `db-f1-micro` | Machine type |
| `availability_type` | string | `ZONAL` | `ZONAL` or `REGIONAL` |
| `disk_size_gb` | number | `20` | Initial disk size |
| `disk_autoresize_limit_gb` | number | `100` | Max disk size (0=unlimited) |
| `database_name` | string | `evcost` | Database name |
| `database_user` | string | `evcost` | Database user |
| `database_password` | string | (required, sensitive) | Database password |
| `gke_sa_email` | string | (required) | GKE service account for Cloud SQL Client role |
| `backup_start_time` | string | `02:00` | Backup start time (UTC) |
| `backup_retention_days` | number | `7` | Number of backups to keep |
| `enable_point_in_time_recovery` | bool | `true` | Enable PITR |
| `maintenance_window_day` | number | `7` | Maintenance day (1=Mon, 7=Sun) |
| `maintenance_window_hour` | number | `3` | Maintenance hour (UTC) |
| `deletion_protection` | bool | `true` | Prevent accidental deletion |

### PostgreSQL Configuration

Optimized for db-f1-micro (614 MB RAM):

| Flag | Value | Description |
|------|-------|-------------|
| `max_connections` | 100 | Maximum connections |
| `shared_buffers` | 16384 (128MB) | ~25% of RAM |
| `work_mem` | 4096 (4MB) | Per-operation memory |
| `maintenance_work_mem` | 16384 (16MB) | Maintenance operations |
| `effective_cache_size` | 49152 (384MB) | ~75% of available memory |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Cloud SQL instance name |
| `instance_connection_name` | Full connection name (project:region:instance) |
| `instance_ip_address` | Private IP address |
| `database_name` | Database name |
| `database_user` | Database user |
| `connection_string` | Connection string (sensitive) |

## Connecting from GKE

### Option 1: Cloud SQL Proxy Sidecar (Recommended)

Add sidecar to your Deployment:

```yaml
spec:
  template:
    spec:
      serviceAccountName: api-sa  # Needs Cloud SQL Client role
      containers:
        - name: app
          env:
            - name: DB_HOST
              value: localhost
            - name: DB_PORT
              value: "5432"
        - name: cloud-sql-proxy
          image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.8.0
          args:
            - --private-ip
            - PROJECT:REGION:INSTANCE  # From module output
            - --port=5432
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
```

### Option 2: Private IP (Direct Connection)

```yaml
env:
  - name: DB_HOST
    value: "10.x.x.x"  # From module output: instance_ip_address
  - name: DB_SSL_MODE
    value: "require"
```

## Security

- ✅ Private IP only (no public internet access)
- ✅ SSL/TLS enforced for all connections
- ✅ IAM-based access control
- ✅ Encryption at rest (automatic)
- ✅ Encryption in transit (automatic with Cloud SQL Proxy)
- ✅ Regular security patches (automatic)
- ✅ Deletion protection enabled

## Backups

### Automatic Backups
- Daily backups at 2:00 UTC (3am CET / 4am CEST)
- 7-day retention (configurable up to 365 days)
- Transaction logs for point-in-time recovery

### Point-in-Time Recovery
- Restore to any second in last 7 days
- No data loss risk

### Manual Backups
```bash
gcloud sql backups create \
  --instance=INSTANCE_NAME \
  --project=ev-cost-tracker
```

## Maintenance

- Maintenance window: Sunday 3:00-4:00 UTC (4am-5am CET)
- Automatic updates: Stable channel
- Zero-downtime for minor updates
- Brief downtime for major version upgrades

## Monitoring

View metrics in Cloud Console:
```
https://console.cloud.google.com/sql/instances/INSTANCE_NAME/overview
```

Key metrics:
- CPU utilization
- Memory utilization
- Connections
- Disk utilization
- Query performance (Query Insights)

## Cost Optimization

1. **Start with db-f1-micro** ($13.29/month) - sufficient for most small apps
2. **Enable auto-resize** - pay only for storage you use
3. **Adjust backup retention** - 7 days is usually enough
4. **Disable HA if not needed** - ZONAL is 50% cheaper
5. **Monitor Query Insights** - optimize slow queries

## Disaster Recovery

### Backup Strategy
- Automatic daily backups
- Transaction logs for PITR
- Optional: Export to GCS for long-term retention

### Recovery Procedures

**Restore from backup:**
```bash
gcloud sql backups restore BACKUP_ID \
  --backup-instance=SOURCE_INSTANCE \
  --backup-project=ev-cost-tracker
```

**Point-in-time recovery:**
```bash
gcloud sql instances clone SOURCE_INSTANCE TARGET_INSTANCE \
  --point-in-time '2024-01-15T10:30:00.000Z' \
  --project=ev-cost-tracker
```

## High Availability (HA)

Enable Regional HA:

```hcl
availability_type = "REGIONAL"
```

**Benefits:**
- Automatic failover (<60 seconds)
- Synchronous replication
- 99.95% SLA (vs 99.50% for ZONAL)
- Zero data loss

**Cost:** ~2x instance cost

## Troubleshooting

### Connection Issues

```bash
# Check instance status
gcloud sql instances describe INSTANCE_NAME --project=ev-cost-tracker

# Check connectivity from GKE
kubectl run -n api psql-test --image=postgres:16-alpine --rm -it -- \
  psql -h PRIVATE_IP -U evcost -d evcost

# Check IAM permissions
gcloud projects get-iam-policy ev-cost-tracker \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:*cloud-sql*"
```

### Performance Issues

```bash
# Check Query Insights in Cloud Console
https://console.cloud.google.com/sql/instances/INSTANCE_NAME/query-insights

# Upgrade instance tier
# Edit terraform.tfvars: cloud_sql_instance_tier = "db-g1-small"
# Run: terraform apply
```

## Migration from StatefulSet

See `../../CLOUD_SQL_MIGRATION_GUIDE.md` for complete migration instructions.

Quick steps:
1. Provision Cloud SQL (this module)
2. Export data: `pg_dump`
3. Import data: `pg_restore`
4. Update connection strings
5. Deploy

## Example: Full Configuration

```hcl
module "cloud_sql" {
  source = "./modules/cloud-sql"

  # Required
  project_id        = "ev-cost-tracker"
  region            = "europe-west1"
  database_password = var.cloud_sql_password
  gke_sa_email      = module.gke.service_account_email

  # Instance configuration
  instance_name     = "my-postgres"
  instance_tier     = "db-g1-small"      # Upgrade for more memory
  availability_type = "REGIONAL"         # Enable HA
  disk_size_gb      = 50                 # Larger disk

  # Database
  database_name = "myapp"
  database_user = "appuser"

  # Backups
  backup_retention_days         = 14     # 2 weeks
  enable_point_in_time_recovery = true

  # Safety
  deletion_protection = true

  # PostgreSQL tuning (for db-g1-small with 1.7GB RAM)
  shared_buffers       = "32768"   # 256MB
  work_mem             = "8192"    # 8MB
  effective_cache_size = "98304"   # 768MB
}
```

## Resources Created

- `google_compute_global_address.private_ip_address` - Private IP reservation
- `google_service_networking_connection.private_vpc_connection` - VPC peering
- `google_sql_database_instance.postgres` - Cloud SQL instance
- `google_sql_database.database` - Database
- `google_sql_user.user` - Database user
- `google_project_iam_member.cloud_sql_client` - IAM role binding

## Deletion

To delete Cloud SQL instance:

1. **Backup data first!**
2. Set `deletion_protection = false` in terraform.tfvars
3. Run `terraform apply`
4. Run `terraform destroy` (or set `enable_cloud_sql = false`)

**Note:** Instance names are reserved for 7 days after deletion. The module adds a random suffix to allow recreating if needed.
