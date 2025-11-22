output "instance_name" {
  description = "The name of the Cloud SQL instance"
  value       = google_sql_database_instance.postgres.name
}

output "instance_connection_name" {
  description = "The connection name of the Cloud SQL instance (project:region:instance)"
  value       = google_sql_database_instance.postgres.connection_name
}

output "instance_ip_address" {
  description = "The private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "instance_first_ip_address" {
  description = "The first IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.postgres.ip_address.0.ip_address
}

output "database_name" {
  description = "The name of the database"
  value       = google_sql_database.database.name
}

output "database_user" {
  description = "The database user"
  value       = google_sql_user.user.name
}

output "connection_string" {
  description = "Connection string for applications (use with Cloud SQL Proxy)"
  value       = "postgresql://${google_sql_user.user.name}@localhost:5432/${google_sql_database.database.name}"
  sensitive   = true
}

output "private_ip_address_name" {
  description = "The name of the private IP address reservation"
  value       = google_compute_global_address.private_ip_address.name
}
