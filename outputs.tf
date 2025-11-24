output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "api_ip_address" {
  description = "Static IP address for API"
  value       = module.networking.api_ip_address
}

output "cloudflare_dns_records" {
  description = "Cloudflare DNS records created"
  value       = var.use_cloudflare_dns ? module.cloudflare_dns[0].dns_records : {}
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}"
}

output "flux_status_command" {
  description = "Command to check Flux status"
  value       = var.enable_flux ? "kubectl get all -n flux-system" : "Flux is disabled"
}

output "domains_configured" {
  description = "List of domains configured"
  value       = var.domains
}

# ===== OpenTelemetry Service Account Outputs =====

output "otel_collector_sa_email" {
  description = "OpenTelemetry Collector service account email"
  value       = module.iam.otel_collector_sa_email
}

output "otel_collector_key_base64" {
  description = "OpenTelemetry Collector service account key (base64 encoded JSON)"
  value       = module.iam.otel_collector_key_private_key
  sensitive   = true
}