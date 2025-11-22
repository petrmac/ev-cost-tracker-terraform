output "project_name" {
  description = "Cloudflare Pages project name"
  value       = cloudflare_pages_project.frontend.name
}

output "subdomain" {
  description = "Cloudflare Pages subdomain"
  value       = cloudflare_pages_project.frontend.subdomain
}

output "domains" {
  description = "Custom domains attached to the project"
  value       = [for d in cloudflare_pages_domain.domains : d.domain]
}
