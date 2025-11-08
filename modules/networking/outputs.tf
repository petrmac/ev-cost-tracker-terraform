output "api_ip_address" {
  description = "Static IP address for API"
  value       = google_compute_global_address.api_ip.address
}

output "api_ip_name" {
  description = "Name of the API static IP resource"
  value       = google_compute_global_address.api_ip.name
}

output "network_name" {
  description = "VPC network name"
  value       = data.google_compute_network.default.name
}