# Grant necessary permissions to GKE service account

# Allow GKE nodes to pull images from GCR
resource "google_project_iam_member" "gke_gcr_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${var.gke_sa_email}"
}

# Allow GKE to write logs
resource "google_project_iam_member" "gke_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${var.gke_sa_email}"
}

# Allow GKE to write metrics
resource "google_project_iam_member" "gke_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${var.gke_sa_email}"
}

# Allow GKE to read monitoring data
resource "google_project_iam_member" "gke_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${var.gke_sa_email}"
}

# Create service account for external-dns if needed
resource "google_service_account" "external_dns" {
  count = var.create_external_dns_sa ? 1 : 0

  account_id   = "external-dns"
  display_name = "External DNS Service Account"
  project      = var.project_id
}

# Grant DNS admin permissions to external-dns service account
resource "google_project_iam_member" "external_dns_admin" {
  count = var.create_external_dns_sa ? 1 : 0

  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.external_dns[0].email}"
}

# Workload Identity binding for external-dns
resource "google_service_account_iam_member" "external_dns_workload_identity" {
  count = var.create_external_dns_sa ? 1 : 0

  service_account_id = google_service_account.external_dns[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[external-dns/external-dns]"
}

# Create service account for cert-manager if needed
resource "google_service_account" "cert_manager" {
  count = var.create_cert_manager_sa ? 1 : 0

  account_id   = "cert-manager"
  display_name = "Cert Manager Service Account"
  project      = var.project_id
}

# Grant DNS admin permissions to cert-manager service account
resource "google_project_iam_member" "cert_manager_dns_admin" {
  count = var.create_cert_manager_sa ? 1 : 0

  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.cert_manager[0].email}"
}

# Workload Identity binding for cert-manager
resource "google_service_account_iam_member" "cert_manager_workload_identity" {
  count = var.create_cert_manager_sa ? 1 : 0

  service_account_id = google_service_account.cert_manager[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[cert-manager/cert-manager]"
}