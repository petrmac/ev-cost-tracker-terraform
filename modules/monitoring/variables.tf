variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  sensitive   = true
}

variable "enable_alerts" {
  description = "Whether to enable alert policies"
  type        = bool
  default     = true
}

variable "error_rate_threshold" {
  description = "Error rate threshold percentage (0.01 = 1%)"
  type        = number
  default     = 0.01
}

variable "latency_threshold_seconds" {
  description = "Latency threshold in seconds"
  type        = number
  default     = 2.0
}

variable "memory_threshold_bytes" {
  description = "Memory threshold in bytes"
  type        = number
  default     = 500000000
}

variable "pod_restart_threshold" {
  description = "Pod restart count threshold"
  type        = number
  default     = 5
}

variable "exclude_debug_logs" {
  description = "Exclude DEBUG level logs"
  type        = bool
  default     = true
}

variable "exclude_info_logs" {
  description = "Exclude INFO level logs"
  type        = bool
  default     = false
}

variable "exclude_health_checks" {
  description = "Exclude health check logs"
  type        = bool
  default     = true
}

variable "exclude_k8s_system_logs" {
  description = "Exclude Kubernetes system logs"
  type        = bool
  default     = true
}

variable "exclude_k8s_events" {
  description = "Exclude Kubernetes events"
  type        = bool
  default     = true
}

variable "exclude_gke_system_pods" {
  description = "Exclude GKE system pods logs"
  type        = bool
  default     = true
}

variable "monitoring_cost_threshold" {
  description = "Daily monitoring cost threshold in USD"
  type        = number
  default     = 10
}

variable "enable_billing_export" {
  description = "Enable billing export to BigQuery"
  type        = bool
  default     = false
}

variable "billing_account" {
  description = "Billing account ID"
  type        = string
  default     = ""
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 100
}