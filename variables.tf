# Aviatrix Controller AUTH VARS
variable "controller_ip" {
  type    = string
  default = ""
}

variable "username" {
  type    = string
  default = ""
}

variable "password" {
  type    = string
  default = ""
}

variable "region" {
  description = "The AWS region to deploy this module in"
  type        = string
}

variable "tgw_name" {
  description = "The name of the Aviatrix managed TGW which will be created"
  type        = string
  default     = "test-fnet-tgw"
}

variable "account" {
  description = "The AWS account name to use for creating the spokes, as known by the Aviatrix controller"
  type        = string
}

variable "spokes" {
  description = "Map of Names and CIDR ranges to be used for the Spoke VPCs"
  type        = map(string)
}

variable "firenets" {
  description = "Map of Names and CIDR ranges to be used for the Egress Firenet VPCs"
  type        = map(string)
}

variable "transit_gw_instance_size" {
  description = "Instance size for gateway"
  type        = string
  default     = "c5.xlarge"
}

variable "egress_gw_instance_size" {
  description = "Instance size for gateway"
  type        = string
  default     = "t3.medium"
}

variable "testclient_instance_size" {
  description = "Instance size for gateway"
  type        = string
  default     = "t3.micro"
}

variable "egress_gw_per_az" {
  description = "Number of egress fqdn gateways to deploy in each AZ for each firenet domain"
  type        = number
  default     = 1
}

locals {
  azs          = ["a", "b"]
  egress_gws   = flatten([for domain, subnet in var.firenets : [for az in local.azs : [for i in range(var.egress_gw_per_az) : { "${domain}-egress-${i + 1}${az}" = domain }]]])
  test_clients = flatten([for domain, subnet in var.spokes : [for az in local.azs : { "${domain}-testclient-${az}" = domain }]])
}
