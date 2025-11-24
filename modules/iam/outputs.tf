output "external_dns_sa_email" {
  description = "External DNS service account email"
  value       = var.create_external_dns_sa ? google_service_account.external_dns[0].email : null
}

output "cert_manager_sa_email" {
  description = "Cert Manager service account email"
  value       = var.create_cert_manager_sa ? google_service_account.cert_manager[0].email : null
}

output "otel_collector_sa_email" {
  description = "OpenTelemetry Collector service account email"
  value       = var.create_otel_collector_sa ? google_service_account.otel_collector[0].email : null
}

output "otel_collector_key_private_key" {
  description = "OpenTelemetry Collector service account private key (base64 encoded)"
  value       = var.create_otel_collector_sa ? google_service_account_key.otel_collector_key[0].private_key : null
  sensitive   = true
}