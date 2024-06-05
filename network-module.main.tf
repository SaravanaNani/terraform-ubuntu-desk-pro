resource "google_compute_network" "custom_network" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "custom_master_subnet" {
  name          = var.master_subnet
  region        = "us-west1"
  network       = google_compute_network.custom_network.self_link
  ip_cidr_range = "10.0.1.0/24"
}

resource "google_compute_subnetwork" "custom_slave_subnet" {
  name          = var.slave_subnet
  region        = "us-west1"
  network       = google_compute_network.custom_network.self_link
  ip_cidr_range = "10.0.2.0/24"
}

resource "google_compute_firewall" "allow_firewall" {
  name    = var.firewall_name
  network = google_compute_network.custom_network.self_link
  direction = "INGRESS"
  priority = 1000
  
  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = ["jenkins"]
}

output "network_self_link" {
  value = google_compute_network.custom_network.self_link
}

output "subnetwork_master_self_link" {
  value = google_compute_subnetwork.custom_master_subnet.self_link
}

output "subnetwork_slave_self_link" {
  value = google_compute_subnetwork.custom_slave_subnet.self_link
}
