variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for Cloud SQL instance"
  type        = string
}

variable "instance_name" {
  description = "Name of the Cloud SQL instance"
  type        = string
  default     = "ev-tracker-postgres"
}

variable "database_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "POSTGRES_16"
}

variable "instance_tier" {
  description = "Cloud SQL instance tier (db-f1-micro, db-g1-small, db-custom-1-3840, etc.)"
  type        = string
  default     = "db-f1-micro"
}

variable "availability_type" {
  description = "Availability type (ZONAL for single instance, REGIONAL for HA)"
  type        = string
  default     = "ZONAL"
}

variable "disk_size_gb" {
  description = "Disk size in GB"
  type        = number
  default     = 20
}

variable "disk_autoresize_limit_gb" {
  description = "Maximum disk size for autoresize (0 = unlimited)"
  type        = number
  default     = 100
}

variable "backup_start_time" {
  description = "Backup start time in HH:MM format (UTC)"
  type        = string
  default     = "02:00" # 3am CET / 4am CEST
}

variable "backup_retention_days" {
  description = "Number of backups to retain"
  type        = number
  default     = 7
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery (requires transaction logs)"
  type        = bool
  default     = true
}

variable "maintenance_window_day" {
  description = "Maintenance window day (1-7, 1=Monday)"
  type        = number
  default     = 7 # Sunday
}

variable "maintenance_window_hour" {
  description = "Maintenance window hour (0-23, UTC)"
  type        = number
  default     = 3 # 4am CET / 5am CEST
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "evcost"
}

variable "database_user" {
  description = "Database user name"
  type        = string
  default     = "evcost"
}

variable "database_password" {
  description = "Database user password"
  type        = string
  sensitive   = true
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "gke_sa_email" {
  description = "GKE service account email for Cloud SQL Client role"
  type        = string
}

# PostgreSQL configuration flags
variable "max_connections" {
  description = "Maximum number of connections"
  type        = string
  default     = "100"
}

variable "shared_buffers" {
  description = "Shared buffers (in KB or MB)"
  type        = string
  default     = "16384" # 128MB (for f1-micro with 614MB RAM)
}

variable "work_mem" {
  description = "Work memory per operation (in KB)"
  type        = string
  default     = "4096" # 4MB
}

variable "maintenance_work_mem" {
  description = "Maintenance work memory (in KB)"
  type        = string
  default     = "16384" # 16MB
}

variable "effective_cache_size" {
  description = "Effective cache size (in KB or MB)"
  type        = string
  default     = "49152" # 384MB (~75% of 512MB available memory)
}
