terraform {
  required_providers {
    aviatrix = {
      source  = "AviatrixSystems/aviatrix"
      version = "2.19.5"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "3.49.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">=3.1.0"
    }
  }
  required_version = ">= 0.13"
}
