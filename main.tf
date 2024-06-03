provider "google" {
  project     = "saravana95"
  region      = "us-central1"
}
locals {
  env = "deskpro"
}

resource "google_compute_subnetwork" "custom_subnet" {
  name          = "${local.env}-subnet-1"
  region        = "us-west1"  # Specify the same region as the VPC
  network       = "jenkins-network"
  ip_cidr_range = "10.0.2.0/24"  # Specify the CIDR range for your subnets
}

resource "google_compute_firewall" "allow_firewall" {
  name    = "${local.env}-allow-8080"
  network = "jenkins-network"
  direction = "INGRESS"
  priority = 1000
  
  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]  # Allow traffic from any source
  target_tags = ["desktop"]
}


# Create a Google Compute Engine instance
resource "google_compute_instance" "my_instance" {
  name         = "${local.env}"
  machine_type = "n1-standard-1"
  zone         = "us-west1-a"

  boot_disk {
    auto_delete = true

    initialize_params {
      image =  "projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20240519"      
      size = 20
      type = "pd-balanced"
    }
  }

network_interface {
    network = "jenkins-network"
    subnetwork = google_compute_subnetwork.custom_subnet.self_link
 
    access_config {}
}

service_account {
    email  = "default"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

tags = ["desktop"]

metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y openssh-server
    sudo hostnamectl set-hostname worker
    echo 'root:${var.slave_password}' | sudo chpasswd
    sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    # Modify /etc/ssh/sshd_configcd t
    #sudo sed -i '39s/^#//' /etc/ssh/sshd_config
    #sudo sed -i '42s/^#//' /etc/ssh/sshd_config
    sudo systemctl restart sshd
    SCRIPT
}
