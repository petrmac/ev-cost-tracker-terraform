resource "google_container_cluster" "autopilot" {
  name     = var.cluster_name
  location = var.region

  # Autopilot mode
  enable_autopilot = true

  # Network configuration
  network    = "default"
  subnetwork = "default"

  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = ""
    services_ipv4_cidr_block = ""
  }

  # Release channel for automatic upgrades
  release_channel {
    channel = "REGULAR"
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Addons configuration
  addons_config {
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  # Database encryption
  database_encryption {
    state    = "DECRYPTED"
    key_name = ""
  }

  # Logging and monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Maintenance window - Sunday 03:00 UTC
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-07T03:00:00Z"
      end_time   = "2024-01-07T07:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SU"
    }
  }

  # Default node pool is managed by Autopilot
  lifecycle {
    ignore_changes = [
      node_pool,
      initial_node_count,
      resource_labels["autopilot-resource-type"],
    ]
  }
}

# Service account for workload identity
resource "google_service_account" "gke_workload" {
  account_id   = "${var.cluster_name}-workload"
  display_name = "Service Account for GKE workload identity"
  project      = var.project_id
}