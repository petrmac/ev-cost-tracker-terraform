variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "gke_sa_email" {
  description = "GKE service account email"
  type        = string
}

variable "create_external_dns_sa" {
  description = "Create service account for external-dns"
  type        = bool
  default     = false
}

variable "create_cert_manager_sa" {
  description = "Create service account for cert-manager"
  type        = bool
  default     = false
}

variable "create_otel_collector_sa" {
  description = "Create service account for OpenTelemetry Collector"
  type        = bool
  default     = false
}