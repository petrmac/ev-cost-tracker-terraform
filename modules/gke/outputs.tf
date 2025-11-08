output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.autopilot.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.autopilot.endpoint
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate"
  value       = google_container_cluster.autopilot.master_auth.0.cluster_ca_certificate
  sensitive   = true
}

output "service_account_email" {
  description = "Service account email for workload identity"
  value       = google_service_account.gke_workload.email
}

output "workload_pool" {
  description = "Workload identity pool"
  value       = "${var.project_id}.svc.id.goog"
}