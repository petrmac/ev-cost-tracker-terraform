output "namespace" {
  description = "Flux system namespace"
  value       = kubernetes_namespace.flux_system.metadata[0].name
}

output "git_repository" {
  description = "Git repository URL"
  value       = "ssh://git@github.com/${var.github_owner}/${var.github_repository}"
}