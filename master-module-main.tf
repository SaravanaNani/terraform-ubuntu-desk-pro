module "network" {
  source = "/root/terraform/network"  # Adjust the path as needed
}

locals {
  env = "master"
}

resource "google_compute_instance" "my_instance" {
  name         = local.env
  machine_type = "n2-standard-2"
  zone         = "us-west1-b"

  boot_disk {
    auto_delete = true

    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20240519"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = module.network.network_self_link
    subnetwork = module.network.subnetwork_master_self_link
    access_config {}
  }

  service_account {
    email  = "default"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  tags = ["jenkins"]

  metadata_startup_script = <<-EOF
    #! /bin/bash
    sudo apt-get update
    sudo apt install git -y
    sudo apt install -y openjdk-17-jre wget vim

    # Install Jenkins
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
    /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt-get update
    sudo apt-get install jenkins -y
    sudo systemctl start jenkins
    sudo systemctl enable jenkins

    # Install Maven
    wget https://apache.osuosl.org/maven/maven-3/3.9.5/binaries/apache-maven-3.9.5-bin.tar.gz
    tar xzvf apache-maven-3.9.5-bin.tar.gz
    sudo mv apache-maven-3.9.5 /opt
    echo 'export M2_HOME=/opt/apache-maven-3.9.5' >> ~/.bashrc
    echo 'export PATH=$M2_HOME/bin:$PATH' >> ~/.bashrc
    source ~/.bashrc
  EOF
}

# Slave instance creation

resource "google_compute_instance" "my_slave_instance" {
  name         = var.slave_name
  machine_type = "n2-standard-4"
  zone         = "us-west1-b"

  boot_disk {
    auto_delete = true

    initialize_params {
      image =  "projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20240519"
      size = 20
      type = "pd-balanced"
    }
  }

network_interface {
    network = module.network.network_self_link
    subnetwork = module.network.subnetwork_slave_self_link

    access_config {}
}

service_account {
    email  = "default"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }


tags = ["jenkins"]

metadata_startup_script = <<-EOF
  #! /bin/bash
    sudo apt-get update
    sudo apt install git -y
    sudo apt install -y openjdk-17-jre wget vim

    # Install Maven
    wget https://apache.osuosl.org/maven/maven-3/3.9.5/binaries/apache-maven-3.9.5-bin.tar.gz
    tar xzvf apache-maven-3.9.5-bin.tar.gz
    sudo mv apache-maven-3.9.5 /opt
    # Set environment variables
    echo 'export M2_HOME=/opt/apache-maven-3.9.5' >> ~/.bashrc
    echo 'export PATH=$M2_HOME/bin:$PATH' >> ~/.bashrc
    source ~/.bashrc

    # Install Ansible
    sudo apt-get update
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository --yes --update ppa:ansible/ansible
    sudo apt-get install -y ansible
    sudo apt-get install -y openssh-server ansible

    # Install Terraform
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install terraform -y

    sudo useradd -m -d /var/lib/jenkins -s /bin/bash jenkins && \
    echo 'jenkins:${var.user_password}' | chpasswd
    echo 'jenkins ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers

    # Generate SSH key pair
    ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N ""

    # Copy the public key to a directory accessible by Jenkins

    sudo mkdir -p /var/lib/jenkins/.ssh
    sudo cp /root/.ssh/id_rsa.pub /var/lib/jenkins/.ssh/id_rsa.pub
    sudo chown jenkins:jenkins /var/lib/jenkins/.ssh/id_rsa.pub
    sudo chmod 644 /var/lib/jenkins/.ssh/id_rsa.pub

    sudo cp /root/.ssh/id_rsa /var/lib/jenkins/.ssh/id_rsa
    sudo chown jenkins:jenkins /var/lib/jenkins/.ssh/id_rsa
    sudo chmod 644 /var/lib/jenkins/.ssh/id_rsa

    # Create Ansible playbook
    sudo mkdir -p /etc/ansible
    cat << 'EOL' | sudo tee /etc/ansible/playbook.yml
---
- name: Setup Ubuntu Desktop Environment and Chrome Remote Desktop
  hosts: all
  become: true
  tasks:
    - name: Update and upgrade APT packages
      apt:
        update_cache: yes
        upgrade: dist

    - name: Install wget, python3 and tasksel
      apt:
        name:
          - wget
          - tasksel
          - python3
          - python3-pip
        state: present

    - name: Download Chrome Remote Desktop package
      get_url:
        url: https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
        dest: /tmp/chrome-remote-desktop_current_amd64.deb

    - name: Install Chrome Remote Desktop package
      apt:
        deb: /tmp/chrome-remote-desktop_current_amd64.deb

    - name: Install Ubuntu desktop environment
      shell: DEBIAN_FRONTEND=noninteractive tasksel install ubuntu-desktop
      become: yes


    - name: Setting Chrome Remote Desktop session to use Gnome
      copy:
        dest: /etc/chrome-remote-desktop-session
        content: |
          exec /etc/X11/Xsession /usr/bin/gnome-session
      become: yes

    - name: Reboot the system to apply changes
      reboot:
        msg: "Reboot initiated by Ansible to complete the setup"
        pre_reboot_delay: 30
        post_reboot_delay: 60
EOL
  EOF
}
