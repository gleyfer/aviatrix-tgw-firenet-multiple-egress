#Create Egress Firenet VPCs
resource "aviatrix_vpc" "firenet_vpc" {
  for_each             = var.firenets
  cloud_type           = 1
  account_name         = var.account
  region               = var.region
  name                 = "fnet-${each.key}"
  cidr                 = each.value
  aviatrix_transit_vpc = false
  aviatrix_firenet_vpc = true
}

#Create Spoke VPCs
resource "aviatrix_vpc" "spoke_vpc" {
  for_each             = var.spokes
  cloud_type           = 1
  account_name         = var.account
  region               = var.region
  name                 = "spoke-${each.key}"
  cidr                 = each.value
  aviatrix_transit_vpc = false
  aviatrix_firenet_vpc = false
  num_of_subnet_pairs  = 3
  subnet_size          = 28
}

#Create Transits in the firenet VPCs
resource "aviatrix_transit_gateway" "firenet_transit" {
  for_each                 = var.firenets
  cloud_type               = 1
  account_name             = var.account
  gw_name                  = "${each.key}-transit"
  vpc_id                   = aviatrix_vpc.firenet_vpc[each.key].vpc_id
  vpc_reg                  = var.region
  gw_size                  = var.transit_gw_instance_size
  subnet                   = aviatrix_vpc.firenet_vpc[each.key].public_subnets[0].cidr
  ha_subnet                = aviatrix_vpc.firenet_vpc[each.key].public_subnets[2].cidr
  ha_gw_size               = var.transit_gw_instance_size
  enable_active_mesh       = true
  enable_hybrid_connection = true
  connected_transit        = true
  enable_firenet           = true
  single_az_ha             = true
}

#Create egress gateways in the firenet VPCs
resource "aviatrix_gateway" "egress" {
  for_each       = { for egress_gw in local.egress_gws : keys(egress_gw)[0] => values(egress_gw)[0] }
  cloud_type     = 1
  account_name   = var.account
  gw_name        = each.key
  vpc_id         = aviatrix_vpc.firenet_vpc[each.value].vpc_id
  vpc_reg        = var.region
  gw_size        = var.egress_gw_instance_size
  subnet         = substr(split("-", each.key)[2], 1, 1) == "a" ? aviatrix_vpc.firenet_vpc[each.value].public_subnets[1].cidr : aviatrix_vpc.firenet_vpc[each.value].public_subnets[3].cidr
  single_ip_snat = false
  single_az_ha   = true
}

#Create and attach FQDN tags to egress gateways
resource "aviatrix_fqdn" "fqdn_tag" {
  for_each     = var.firenets
  fqdn_tag     = each.key
  fqdn_enabled = true
  fqdn_mode    = "black"

  dynamic "gw_filter_tag_list" {
    for_each = { for k, v in aviatrix_gateway.egress : k => v if split("-", k)[0] == each.key }
    content {
      gw_name = gw_filter_tag_list.value.gw_name
    }
  }

  depends_on = [aviatrix_firenet.test_firenet]
}

#Create Firenet gateway associations
resource "aviatrix_firewall_instance_association" "fqdn_fnet_association" {
  for_each        = aviatrix_gateway.egress
  vpc_id          = each.value.vpc_id
  firenet_gw_name = substr(split("-", each.key)[2], 1, 1) == "a" ? aviatrix_transit_gateway.firenet_transit[split("-", each.key)[0]].gw_name : aviatrix_transit_gateway.firenet_transit[split("-", each.key)[0]].ha_gw_name
  instance_id     = each.value.gw_name
  vendor_type     = "fqdn_gateway"
  attached        = true
}

#Create Firenet
resource "aviatrix_firenet" "test_firenet" {
  for_each                             = var.firenets
  vpc_id                               = aviatrix_vpc.firenet_vpc[each.key].vpc_id
  inspection_enabled                   = false
  egress_enabled                       = true
  tgw_segmentation_for_egress_enabled  = true
  keep_alive_via_lan_interface_enabled = false
  manage_firewall_instance_association = false

  depends_on = [aviatrix_firewall_instance_association.fqdn_fnet_association]
}

#Create TGW
resource "aviatrix_aws_tgw" "test_aws_tgw" {
  account_name                      = var.account
  aws_side_as_number                = "64512"
  manage_vpc_attachment             = false
  manage_transit_gateway_attachment = false
  manage_security_domain            = false
  region                            = var.region
  tgw_name                          = var.tgw_name
}

# Create default domains and connection policies
resource "aviatrix_aws_tgw_security_domain" "Default_Domain" {
  name     = "Default_Domain"
  tgw_name = aviatrix_aws_tgw.test_aws_tgw.tgw_name
}

resource "aviatrix_aws_tgw_security_domain" "Shared_Service_Domain" {
  name     = "Shared_Service_Domain"
  tgw_name = aviatrix_aws_tgw.test_aws_tgw.tgw_name
}

resource "aviatrix_aws_tgw_security_domain" "Aviatrix_Edge_Domain" {
  name     = "Aviatrix_Edge_Domain"
  tgw_name = aviatrix_aws_tgw.test_aws_tgw.tgw_name
}

resource "aviatrix_aws_tgw_security_domain_connection" "default_sd_conn1" {
  tgw_name     = aviatrix_aws_tgw.test_aws_tgw.tgw_name
  domain_name1 = aviatrix_aws_tgw_security_domain.Aviatrix_Edge_Domain.name
  domain_name2 = aviatrix_aws_tgw_security_domain.Default_Domain.name
}

resource "aviatrix_aws_tgw_security_domain_connection" "default_sd_conn2" {
  tgw_name     = aviatrix_aws_tgw.test_aws_tgw.tgw_name
  domain_name1 = aviatrix_aws_tgw_security_domain.Aviatrix_Edge_Domain.name
  domain_name2 = aviatrix_aws_tgw_security_domain.Shared_Service_Domain.name
}

resource "aviatrix_aws_tgw_security_domain_connection" "default_sd_conn3" {
  tgw_name     = aviatrix_aws_tgw.test_aws_tgw.tgw_name
  domain_name1 = aviatrix_aws_tgw_security_domain.Default_Domain.name
  domain_name2 = aviatrix_aws_tgw_security_domain.Shared_Service_Domain.name
}

# Create custom security domains for spokes
resource "aviatrix_aws_tgw_security_domain" "spoke_sec_domain" {
  for_each = var.firenets
  name     = each.key
  tgw_name = aviatrix_aws_tgw.test_aws_tgw.tgw_name
  depends_on = [
    aviatrix_aws_tgw_security_domain.Default_Domain,
    aviatrix_aws_tgw_security_domain.Shared_Service_Domain,
    aviatrix_aws_tgw_security_domain.Aviatrix_Edge_Domain
  ]
}

# Create firewall security domains
resource "aviatrix_aws_tgw_security_domain" "firenet_sec_domain" {
  for_each          = var.firenets
  name              = "${each.key}-egress"
  tgw_name          = aviatrix_aws_tgw.test_aws_tgw.tgw_name
  aviatrix_firewall = true
  depends_on = [
    aviatrix_aws_tgw_security_domain.Default_Domain,
    aviatrix_aws_tgw_security_domain.Shared_Service_Domain,
    aviatrix_aws_tgw_security_domain.Aviatrix_Edge_Domain
  ]
}

# Attach respective spoke and egress domains
resource "aviatrix_aws_tgw_security_domain_connection" "spoke_to_egress" {
  for_each     = var.firenets
  tgw_name     = aviatrix_aws_tgw.test_aws_tgw.tgw_name
  domain_name1 = aviatrix_aws_tgw_security_domain.firenet_sec_domain[each.key].name
  domain_name2 = aviatrix_aws_tgw_security_domain.spoke_sec_domain[each.key].name
}

# Attach Firenet VPCs to TGW
resource "aviatrix_aws_tgw_vpc_attachment" "firenet_tgw_attachment" {
  for_each             = var.firenets
  tgw_name             = aviatrix_aws_tgw.test_aws_tgw.tgw_name
  region               = var.region
  security_domain_name = aviatrix_aws_tgw_security_domain.firenet_sec_domain[each.key].name
  vpc_account_name     = var.account
  vpc_id               = aviatrix_vpc.firenet_vpc[each.key].vpc_id
  depends_on           = [aviatrix_firenet.test_firenet]
}

# Attach spoke VPCs to TGW
resource "aviatrix_aws_tgw_vpc_attachment" "spoke_tgw_attachment" {
  for_each             = var.firenets
  tgw_name             = aviatrix_aws_tgw.test_aws_tgw.tgw_name
  region               = var.region
  security_domain_name = aviatrix_aws_tgw_security_domain.spoke_sec_domain[each.key].name
  vpc_account_name     = var.account
  vpc_id               = aviatrix_vpc.spoke_vpc[each.key].vpc_id
}

# Create some test instances
data "aws_ami" "amazon-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

resource "tls_private_key" "testclient_key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "testclient_key" {
  key_name   = "testclient_sshkey"
  public_key = tls_private_key.testclient_key.public_key_openssh
}

resource "aws_security_group" "test_client" {
  for_each    = var.spokes
  name        = "${each.key}-testclient-SG"
  description = "Security Group for ${each.key} test instance"
  vpc_id      = aviatrix_vpc.spoke_vpc[each.key].vpc_id

  ingress {
    description      = "HTTP from Anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH from Anywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    "Name" = "${each.key}-testclient-SG"
  }
}

resource "aws_instance" "test_client" {
  for_each                    = { for test_client in local.test_clients : keys(test_client)[0] => values(test_client)[0] }
  ami                         = data.aws_ami.amazon-linux.id
  instance_type               = var.testclient_instance_size
  key_name                    = aws_key_pair.testclient_key.key_name
  subnet_id                   = substr(split("-", each.key)[2], 0, 1) == "a" ? aviatrix_vpc.spoke_vpc[each.value].private_subnets[0].subnet_id : aviatrix_vpc.spoke_vpc[each.value].private_subnets[1].subnet_id
  vpc_security_group_ids      = [aws_security_group.test_client[each.value].id]
  associate_public_ip_address = false

  user_data = <<EOF
#! /bin/bash
sed 's/PasswordAuthentication no/PasswordAuthentication yes/' -i /etc/ssh/sshd_config
systemctl restart sshd
service sshd restart

echo "Aviatrix123!" | passwd --stdin ec2-user
yum -y install httpd
systemctl start httpd
systemctl enable httpd
EOF

  tags = {
    "Name" = each.key
  }
}
