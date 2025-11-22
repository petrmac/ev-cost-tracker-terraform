# Reserve static IP for API/backend (will be used by Ingress)
resource "google_compute_global_address" "api_ip" {
  name = var.api_ip_name
}

# Get the default network
data "google_compute_network" "default" {
  name = var.network_name
}

# Firewall rule to allow HTTPS traffic
resource "google_compute_firewall" "allow_https" {
  name    = "${var.firewall_rule_prefix}-allow-https"
  network = data.google_compute_network.default.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = var.https_firewall_target_tags
  
  description = "Allow HTTPS traffic from anywhere"
  priority    = 1000
}