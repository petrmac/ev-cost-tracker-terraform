# Cloud SQL Quick Start

Fast-track guide to provision Cloud SQL. See `CLOUD_SQL_MIGRATION_GUIDE.md` for complete migration instructions.

## 1. Set Database Password

```bash
# Generate secure password
openssl rand -base64 32 > cloud_sql_password.txt

# Or use existing StatefulSet password
kubectl get secret -n postgres postgres-credentials -o jsonpath='{.data.DB_PASSWORD}' | base64 -d > cloud_sql_password.txt
```

## 2. Configure Terraform

Edit `terraform.tfvars`:

```hcl
# Enable Cloud SQL
enable_cloud_sql = true

# Configuration (defaults shown, customize as needed)
cloud_sql_instance_name     = "ev-tracker-postgres"
cloud_sql_instance_tier     = "db-f1-micro"          # $13.29/month
cloud_sql_disk_size_gb      = 20
cloud_sql_database_name     = "evcost"
cloud_sql_database_user     = "evcost"
cloud_sql_database_password = "PASTE_PASSWORD_HERE"   # From cloud_sql_password.txt
```

**Optional upgrades:**
```hcl
# Upgrade to more memory ($30.93/month)
cloud_sql_instance_tier = "db-g1-small"

# Enable High Availability (+100% cost)
cloud_sql_availability_type = "REGIONAL"

# Increase backup retention
cloud_sql_backup_retention_days = 14
```

## 3. Provision Cloud SQL

```bash
# Initialize module
terraform init

# Preview changes
terraform plan

# Apply (takes ~10 minutes)
terraform apply
```

## 4. Get Connection Details

```bash
# Connection name (for Cloud SQL Proxy)
terraform output cloud_sql_connection_name
# Output: ev-cost-tracker:europe-west1:ev-tracker-postgres-abc123

# Private IP (for direct connection)
terraform output cloud_sql_private_ip
# Output: 10.x.x.x

# Instance name
terraform output cloud_sql_instance_name
# Output: ev-tracker-postgres-abc123
```

## 5. Test Connection

```bash
# Install Cloud SQL Proxy
brew install cloud-sql-proxy  # macOS

# Start proxy
CONNECTION_NAME=$(terraform output -raw cloud_sql_connection_name)
cloud-sql-proxy --private-ip $CONNECTION_NAME --port 5433

# Connect with psql (in another terminal)
PGPASSWORD="YOUR_PASSWORD" psql -h localhost -p 5433 -U evcost -d evcost

# Test query
SELECT version();
\dt
```

## 6. Next Steps

Choose migration path:

### Option A: Zero-Downtime Migration
See `CLOUD_SQL_MIGRATION_GUIDE.md` Phase 2 for:
- Data replication
- Dual-write setup
- Gradual cutover

### Option B: Maintenance Window Migration (Recommended)
1. Schedule 15-minute maintenance window
2. Export data from StatefulSet: `pg_dump`
3. Import to Cloud SQL: `pg_restore`
4. Update application connection strings
5. Deploy

See `CLOUD_SQL_MIGRATION_GUIDE.md` Phase 3.

## Cost Comparison

| Configuration | Monthly Cost | Use Case |
|---------------|--------------|----------|
| **db-f1-micro (ZONAL)** | **$13.29** | ✅ Current workload (recommended) |
| db-g1-small (ZONAL) | $30.93 | More memory, better performance |
| db-f1-micro (REGIONAL HA) | $26.58 | High availability, auto-failover |
| db-g1-small (REGIONAL HA) | $61.86 | Production HA with better performance |
| StatefulSet (current) | $19.40 | Manual management required |

**Recommended:** Start with `db-f1-micro (ZONAL)` - saves $6/month and reduces operational burden.

## Terraform Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_cloud_sql` | `false` | **Set to `true`** to provision Cloud SQL |
| `cloud_sql_instance_name` | `ev-tracker-postgres` | Instance name (appended with random suffix) |
| `cloud_sql_instance_tier` | `db-f1-micro` | Machine type ($13.29/mo) |
| `cloud_sql_availability_type` | `ZONAL` | `ZONAL` or `REGIONAL` (HA) |
| `cloud_sql_disk_size_gb` | `20` | Initial disk size (auto-resizes) |
| `cloud_sql_database_name` | `evcost` | Database name |
| `cloud_sql_database_user` | `evcost` | Database user |
| `cloud_sql_database_password` | (required) | **Must set in terraform.tfvars** |
| `cloud_sql_backup_retention_days` | `7` | Backup retention (1-365 days) |
| `cloud_sql_enable_pitr` | `true` | Point-in-time recovery |
| `cloud_sql_deletion_protection` | `true` | Prevent accidental deletion |

## Features Included

✅ **Automatic Backups** - Daily at 2am UTC (3am CET)
✅ **Point-in-Time Recovery** - Restore to any second in last 7 days
✅ **Auto Storage Resize** - Never run out of disk space
✅ **Private IP Only** - No public internet exposure
✅ **SSL/TLS Enforced** - Encrypted connections
✅ **Query Insights** - Performance monitoring
✅ **Maintenance Windows** - Sunday 3am UTC (4am CET)
✅ **IAM Integration** - GKE Workload Identity
✅ **Deletion Protection** - Prevent accidents

## Rollback

If you need to remove Cloud SQL:

```bash
# Set enable_cloud_sql = false in terraform.tfvars
terraform apply

# WARNING: This will delete the instance after deletion_protection = false
# Make sure to backup data first!
```

## Support

- Migration guide: `CLOUD_SQL_MIGRATION_GUIDE.md`
- Cost comparison: `POSTGRES_COMPARISON.md`
- Terraform docs: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance
- Cloud SQL docs: https://cloud.google.com/sql/docs/postgres
