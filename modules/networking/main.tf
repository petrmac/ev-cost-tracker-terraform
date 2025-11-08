# Reserve static IP for API/backend (will be used by Ingress)
resource "google_compute_global_address" "api_ip" {
  name = var.api_ip_name
}

# Get the default network
data "google_compute_network" "default" {
  name = var.network_name
}