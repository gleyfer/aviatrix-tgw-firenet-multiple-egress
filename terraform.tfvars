// Note: best to set controller_ip, username, password for Aviatrix Controller
// as environment variables.
// example: export TF_VAR_controller_ip=YOUR.IP

// Modify below as needed:
region                   = "us-west-2"
account                  = "AWSAccount" # Replace with your AWS Access Account in Controller
spokes                   = { "Dev" = "10.1.0.0/24", "Prod" = "10.2.0.0/24" }
firenets                 = { "Dev" = "10.5.0.0/23", "Prod" = "10.0.0.0/23" }
tgw_name                 = "test-fnet-tgw"
egress_gw_per_az         = 2
transit_gw_instance_size = "c5.xlarge"
egress_gw_instance_size  = "t3.micro"
testclient_instance_size = "t3.micro"
