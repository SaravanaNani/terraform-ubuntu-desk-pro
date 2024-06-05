variable "vpc_name" {
  type    = string
  default = "jenkins-vpc"
}

variable "master_subnet" {
  type    = string
  default = "master-subnet"
}

variable "slave_subnet" {
  type    = string
  default = "slave-subnet"
}

variable "firewall_name" {
  type    = string
  default = "jenkins-rule"
}
