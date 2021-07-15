provider "aviatrix" {
  controller_ip = var.controller_ip
  username      = var.username
  password      = var.password
}

provider "aws" {
  region = var.region
}
