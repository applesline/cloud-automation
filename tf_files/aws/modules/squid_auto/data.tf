### DATA RESOURCES:

#Basics

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#data "aws_vpc" "the_vpc" {
#tags {
#    Name = "${var.env_vpc_name}"
#  }
#}

# Let's get the availability zones for the region we are working on
#data "aws_availability_zones" "available" {}

# get public route table 
#data "aws_route_table" "public_route_table" {
#  vpc_id      = "${data.aws_vpc.the_vpc.id}"
#  tags {
#    Name = "main"
#  }
#}


# get the private kube table id 
#data "aws_route_table" "private_kube_route_table" {
#  vpc_id      = "${var.env_vpc_id}"
#  tags {
#    Name = "private_kube"
#  }
#}

#get the internal zone id
#data "aws_route53_zone" "vpczone" {
#  name        = "internal.io."
#  vpc_id      = "${var.env_vpc_id}"
#}

########
