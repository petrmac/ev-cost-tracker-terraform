variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "europe-west1"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "ev-tracker-gke-autopilot"
}

variable "domains" {
  description = "List of domain names for the application"
  type        = list(string)
  default     = ["evtracker.cz", "evtracker.online", "evtracker.cloud"]
}

variable "create_dns_zone" {
  description = "Whether to create and manage DNS zone"
  type        = bool
  default     = false
}

variable "enable_flux" {
  description = "Whether to install Flux CD"
  type        = bool
  default     = true
}

variable "github_owner" {
  description = "GitHub owner/organization for Flux"
  type        = string
  default     = "petrmac"
}

variable "github_repository" {
  description = "GitHub repository name for Flux"
  type        = string
  default     = "ev-cost-tracker-gitops"
}

variable "github_branch" {
  description = "Git branch for Flux"
  type        = string
  default     = "main"
}

variable "git_ssh_key" {
  description = "SSH private key for Git repository access (for Flux)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "git_ssh_key_pub" {
  description = "SSH public key for Git repository access (for Flux)"
  type        = string
  default     = ""
}

variable "known_hosts" {
  description = "SSH known_hosts content for git provider"
  type        = string
  default     = "github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk="
}

variable "age_key" {
  description = "Age private key for SOPS decryption (contents of age.agekey file)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "api_ip_name" {
  description = "Name for the API static IP resource"
  type        = string
  default     = "ev-tracker-api-ip"
}

variable "configure_k8s_providers" {
  description = "Whether to configure Kubernetes/Helm/kubectl providers (set to false during import)"
  type        = bool
  default     = true
}

variable "use_cloudflare_dns" {
  description = "Use Cloudflare for DNS instead of Google Cloud DNS"
  type        = bool
  default     = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS management"
  type        = string
  sensitive   = true
  default     = ""
}

variable "create_environment_subdomains" {
  description = "Create environment-specific subdomains (dev.domain.com, staging.domain.com)"
  type        = bool
  default     = true
}

# Monitoring Configuration
variable "alert_email" {
  description = "Email address for monitoring alerts"
  type        = string
  sensitive   = true
}

variable "enable_monitoring_alerts" {
  description = "Whether to enable Cloud Monitoring alert policies"
  type        = bool
  default     = true
}

# Cost Monitoring Configuration
variable "billing_account" {
  description = "Billing account ID for budget alerts (format: XXXXXX-XXXXXX-XXXXXX)"
  type        = string
  default     = ""
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 100
}

variable "monitoring_cost_threshold" {
  description = "Daily cost threshold for Cloud Operations alerts (USD)"
  type        = number
  default     = 10
}

variable "enable_billing_export" {
  description = "Enable billing export to BigQuery for detailed cost analysis"
  type        = bool
  default     = false
}

# Log Exclusion Settings to Reduce Costs
variable "exclude_debug_logs" {
  description = "Exclude DEBUG level logs to reduce costs"
  type        = bool
  default     = true
}

variable "exclude_info_logs" {
  description = "Exclude INFO level logs (keep WARNING, ERROR only)"
  type        = bool
  default     = false
}

variable "exclude_health_checks" {
  description = "Exclude health check endpoint logs"
  type        = bool
  default     = true
}

# Kubernetes Log Exclusions - MAJOR COST SAVINGS
variable "exclude_k8s_system_logs" {
  description = "Exclude Kubernetes API audit logs (saves ~50% of k8s logs)"
  type        = bool
  default     = true
}

variable "exclude_k8s_events" {
  description = "Exclude Kubernetes event logs"
  type        = bool
  default     = true
}

variable "exclude_gke_system_pods" {
  description = "Exclude logs from GKE system namespaces"
  type        = bool
  default     = true
}

variable "manage_zone_settings" {
  description = "Manage Cloudflare zone settings (requires additional permissions)"
  type        = bool
  default     = false
}