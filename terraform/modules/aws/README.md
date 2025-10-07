# AWS Terraform Modules

This directory contains reusable Terraform modules for AWS networking and compute.

Modules provided:
- vpc: Creates/ensures a default VPC and optionally creates a custom VPC with public and private subnets, IGW, routes, and optional NAT.
- ec2: Launches EC2 instances into either the default VPC or a provided custom VPC, in public or private subnets, and restricts access to a list of allowed IP CIDRs via a security group.

Example: Create default and custom VPC, then an instance in each

module "vpc" {
  source = "./vpc"

  # Ensure default VPC exists (and outputs its IDs)
  create_default_vpc = true

  # Create a custom VPC with 2 AZs, public/private subnets, and a single NAT gateway
  create_custom_vpc   = true
  name                = "example"
  vpc_cidr            = "10.10.0.0/16"
  azs                 = ["us-east-1a", "us-east-1b"]
  public_subnets      = ["10.10.1.0/24", "10.10.2.0/24"]
  private_subnets     = ["10.10.11.0/24", "10.10.12.0/24"]
  enable_nat_gateway  = true
  single_nat_gateway  = true
}

# Instance in the default VPC (public subnet) restricted to allowed IPs
module "ec2_default" {
  source = "./ec2"

  use_default_vpc = true
  subnet_type     = "public"

  name           = "default-ec2"
  ami            = "ami-xxxxxxxx"    # provide a valid AMI for your region
  instance_type  = "t3.micro"
  allowed_cidrs  = ["203.0.113.10/32", "198.51.100.0/24"]
  allowed_port   = 22
}

# Instance in the custom VPC private subnets (no public IP)
module "ec2_custom" {
  source = "./ec2"

  vpc_id      = module.vpc.custom_vpc_id
  subnet_ids  = module.vpc.private_subnet_ids
  subnet_type = "private"

  name           = "custom-ec2"
  ami            = "ami-xxxxxxxx"    # provide a valid AMI for your region
  instance_type  = "t3.micro"
  allowed_cidrs  = ["203.0.113.10/32"]
  allowed_port   = 22
}

Notes:
- Provider configuration (aws) must be set in the root module.
- When using subnet_type = "private", instances will not associate a public IP.
- When use_default_vpc = true and you want private placement, provide subnet_ids for private subnets you manage in the default VPC.
