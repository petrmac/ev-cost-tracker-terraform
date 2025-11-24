terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Random suffix for instance name (Cloud SQL names must be unique for 7 days after deletion)
resource "random_id" "db_suffix" {
  byte_length = 4
}

# Cloud SQL PostgreSQL instance
resource "google_sql_database_instance" "postgres" {
  name             = "${var.instance_name}-${random_id.db_suffix.hex}"
  database_version = var.database_version
  region           = var.region
  project          = var.project_id

  # Instance tier (db-f1-micro, db-g1-small, db-custom-1-3840, etc.)
  settings {
    tier              = var.instance_tier
    availability_type = var.availability_type # ZONAL or REGIONAL (HA)
    disk_type         = "PD_SSD"
    disk_size         = var.disk_size_gb
    disk_autoresize       = true
    disk_autoresize_limit = var.disk_autoresize_limit_gb

    # Backup configuration
    backup_configuration {
      enabled                        = true
      start_time                     = var.backup_start_time
      point_in_time_recovery_enabled = var.enable_point_in_time_recovery
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = var.backup_retention_days
        retention_unit   = "COUNT"
      }
    }

    # Maintenance window
    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = "stable"
    }

    # IP configuration
    ip_configuration {
      ipv4_enabled    = false # Private IP only
      private_network = "projects/${var.project_id}/global/networks/default"
      ssl_mode        = "ENCRYPTED_ONLY" # Require SSL connections (replaces deprecated require_ssl)

      # Allow access from GKE cluster (via private IP)
      # No authorized networks needed since we're using private IP
    }

    # Database flags
    database_flags {
      name  = "max_connections"
      value = var.max_connections
    }

    database_flags {
      name  = "shared_buffers"
      value = var.shared_buffers
    }

    database_flags {
      name  = "work_mem"
      value = var.work_mem
    }

    database_flags {
      name  = "maintenance_work_mem"
      value = var.maintenance_work_mem
    }

    database_flags {
      name  = "effective_cache_size"
      value = var.effective_cache_size
    }

    # Insights configuration
    insights_config {
      query_insights_enabled  = true
      query_plans_per_minute  = 5
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }

    # User labels
    user_labels = {
      environment = terraform.workspace
      managed-by  = "terraform"
      service     = "ev-cost-tracker"
    }
  }

  # Deletion protection
  deletion_protection = var.deletion_protection

  # Wait for private service connection
  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# Private VPC connection for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.instance_name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = "projects/${var.project_id}/global/networks/default"
  project       = var.project_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = "projects/${var.project_id}/global/networks/default"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Database
resource "google_sql_database" "database" {
  name     = var.database_name
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id
}

# Database user
resource "google_sql_user" "user" {
  name     = var.database_user
  instance = google_sql_database_instance.postgres.name
  password = var.database_password
  project  = var.project_id
}

# IAM binding for Cloud SQL Client role (for Cloud SQL Proxy)
resource "google_project_iam_member" "cloud_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${var.gke_sa_email}"
}
