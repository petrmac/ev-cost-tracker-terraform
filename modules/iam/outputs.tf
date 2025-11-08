output "external_dns_sa_email" {
  description = "External DNS service account email"
  value       = var.create_external_dns_sa ? google_service_account.external_dns[0].email : null
}

output "cert_manager_sa_email" {
  description = "Cert Manager service account email"
  value       = var.create_cert_manager_sa ? google_service_account.cert_manager[0].email : null
}