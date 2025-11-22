terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

locals {
  services = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "dns.googleapis.com",
    "certificatemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    # Container image storage
    "containerregistry.googleapis.com",
    "artifactregistry.googleapis.com",
    # Database
    "sqladmin.googleapis.com",
    # Observability
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudtrace.googleapis.com",
    # Storage for backups
    "storage.googleapis.com",
    # Billing and cost management
    "bigquery.googleapis.com",
    "billingbudgets.googleapis.com"
  ]

  # Workspace-aware naming
  env = terraform.workspace == "default" ? "" : "-${terraform.workspace}"
}

resource "google_project_service" "services" {
  for_each = toset(local.services)

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

module "gke" {
  source = "./modules/gke"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.region

  depends_on = [google_project_service.services]
}

module "networking" {
  source = "./modules/networking"

  api_ip_name  = var.api_ip_name
  region       = var.region
  network_name = "default"

  depends_on = [google_project_service.services]
}

module "iam" {
  source = "./modules/iam"

  project_id   = var.project_id
  gke_sa_email = module.gke.service_account_email

  depends_on = [
    google_project_service.services,
    module.gke
  ]
}

# Cloudflare DNS for multiple domains
module "cloudflare_dns" {
  source = "./modules/cloudflare-dns"

  count = var.use_cloudflare_dns ? 1 : 0

  domains = var.domains
  api_ip  = module.networking.api_ip_address

  # Environment subdomains
  create_environment_subdomains = var.create_environment_subdomains
  environment                   = terraform.workspace

  # Zone settings management
  manage_zone_settings = var.manage_zone_settings

  # Cloudflare Pages support
  use_pages           = var.use_cloudflare_pages
  pages_project_name  = "ev-cost-tracker-frontend"

  depends_on = [
    module.networking
  ]
}

# Cloudflare Pages for frontend hosting
module "cloudflare_pages" {
  source = "./modules/cloudflare-pages"

  count = var.use_cloudflare_pages ? 1 : 0

  account_id        = var.cloudflare_account_id
  project_name      = "ev-cost-tracker-frontend"
  production_branch = "main"
  github_owner      = var.github_owner
  github_repo       = "ev-cost-tracker"  # Main repo with frontend code
  api_base_url      = "https://api.${var.domains[0]}"
  custom_domains    = var.domains

  depends_on = [module.cloudflare_dns]
}

# Configure Kubernetes provider
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = try("https://${module.gke.cluster_endpoint}", "")
  token                  = try(data.google_client_config.default.access_token, "")
  cluster_ca_certificate = try(base64decode(module.gke.cluster_ca_certificate), "")
}

provider "kubectl" {
  host                   = try("https://${module.gke.cluster_endpoint}", "")
  token                  = try(data.google_client_config.default.access_token, "")
  cluster_ca_certificate = try(base64decode(module.gke.cluster_ca_certificate), "")
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = try("https://${module.gke.cluster_endpoint}", "")
    token                  = try(data.google_client_config.default.access_token, "")
    cluster_ca_certificate = try(base64decode(module.gke.cluster_ca_certificate), "")
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Cloud Monitoring module for dashboards and alerts
module "monitoring" {
  source = "./modules/monitoring"

  project_id                = var.project_id
  alert_email               = var.alert_email
  enable_alerts             = var.enable_monitoring_alerts
  error_rate_threshold      = 0.01      # Alert on 1% error rate
  latency_threshold_seconds = 2.0       # Alert on p95 > 2 seconds
  memory_threshold_bytes    = 500000000 # 500MB
  pod_restart_threshold     = 5

  # Cost monitoring configuration
  exclude_debug_logs        = var.exclude_debug_logs
  exclude_info_logs         = var.exclude_info_logs
  exclude_health_checks     = var.exclude_health_checks
  exclude_k8s_system_logs   = var.exclude_k8s_system_logs
  exclude_k8s_events        = var.exclude_k8s_events
  exclude_gke_system_pods   = var.exclude_gke_system_pods
  monitoring_cost_threshold = var.monitoring_cost_threshold

  # Billing configuration
  enable_billing_export = var.enable_billing_export
  billing_account       = var.billing_account
  monthly_budget_amount = var.monthly_budget_amount

  depends_on = [google_project_service.services]
}

module "flux" {
  source = "./modules/flux"

  count = var.enable_flux ? 1 : 0

  cluster_name      = var.cluster_name
  github_owner      = var.github_owner
  github_repository = var.github_repository
  github_branch     = var.github_branch
  git_ssh_key       = var.git_ssh_key
  git_ssh_key_pub   = var.git_ssh_key_pub
  known_hosts       = var.known_hosts
  age_key           = var.age_key

  depends_on = [
    module.gke,
    module.iam
  ]
}