# AWS Terraform Modules

This directory contains reusable Terraform modules for AWS networking and compute.

Modules provided:

- vpc: Creates/ensures a default VPC and optionally creates a custom VPC with public and private subnets, IGW, routes,
  and optional NAT.
- ec2: Launches EC2 instances into either the default VPC or a provided custom VPC, in public or private subnets, and
  restricts access to a list of allowed IP CIDRs via a security group.

Example: Create default and custom VPC, then an instance in each

```hcl
module "vpc" {
  source = "./vpc"

  # Ensure default VPC exists (and outputs its IDs)
  create_default_vpc = true

  # Create a custom VPC with 2 AZs, public/private subnets, and a single NAT gateway
  create_custom_vpc  = true
  name               = "example"
  vpc_cidr           = "10.10.0.0/16"
  azs = ["us-east-1a", "us-east-1b"]
  public_subnets = ["10.10.1.0/24", "10.10.2.0/24"]
  private_subnets = ["10.10.11.0/24", "10.10.12.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
}
```

# Instance in the default VPC (public subnet) restricted to allowed IPs

```hcl
module "ec2_default" {
  source = "./ec2"

  use_default_vpc = true
  subnet_type     = "public"

  name          = "default-ec2"
  ami = "ami-xxxxxxxx"    # provide a valid AMI for your region
  instance_type = "t3.micro"
  allowed_cidrs = ["203.0.113.10/32", "198.51.100.0/24"]
  allowed_port  = 22
}
```

# Instance in the custom VPC private subnets (no public IP)

```hcl
module "ec2_custom" {
  source = "./ec2"

  vpc_id      = module.vpc.custom_vpc_id
  subnet_ids  = module.vpc.private_subnet_ids
  subnet_type = "private"

  name          = "custom-ec2"
  ami           = "ami-xxxxxxxx"    # provide a valid AMI for your region
  instance_type = "t3.micro"
  allowed_cidrs = ["203.0.113.10/32"]
  allowed_port  = 22

  # Option A: pass raw user_data content directly
  # user_data = file("${path.module}/scripts/bootstrap.sh")

  # Option B: let the module read the file (recommended if you prefer passing a path)
  # Provide an absolute path or construct with path.module from root
  # user_data_file = "${path.module}/scripts/bootstrap.sh"

  # Optionally render the file as a template
  # user_data_file         = "${path.module}/scripts/bootstrap.tpl"
  # user_data_template_vars = {
  #   env    = var.environment
  #   region = var.region
  # }
}
```

Notes:

- Provider configuration (aws) must be set in the root module.
- When using subnet_type = "private", instances will not associate a public IP.
- When use_default_vpc = true and you want private placement, provide subnet_ids for private subnets you manage in the
  default VPC.

## security-group module usage

### Legacy single security group (backward compatible)

```hcl
module "web_sg" {
  source = "./security-group"

  name          = "web"
  target_vpc_id = module.vpc.custom_vpc_id
  allowed_cidrs = ["203.0.113.10/32", "198.51.100.0/24"]
  allowed_port  = 443
  egress_cidrs = ["0.0.0.0/0"]
  tags = { App = "demo" }
}
```

# Consume outputs in other modules (e.g., EC2)

```hcl
module "ec2_web" {
  source = "./ec2"

  vpc_id             = module.vpc.custom_vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  subnet_type        = "public"
  name               = "web"
  ami = "ami-xxxxxxxx"  # valid AMI for your region
  instance_type      = "t3.micro"
  security_group_ids = module.web_sg.security_group_id_list
}
```

### Multiple security groups with flexible rules

```hcl
module "sg" {
  source = "./security-group"

  security_groups = {
    web = {
      vpc_id      = module.vpc.custom_vpc_id
      description = "Web tier SG"
      tags = { Tier = "web" }
      ingress = [
        {
          description = "HTTPS from Internet"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          cidr_blocks = ["0.0.0.0/0"]
        },
        {
          description = "Health checks from ALB SG"
          protocol    = "tcp"
          from_port   = 80
          to_port     = 80
          security_groups = [aws_security_group.alb.id] # example if you have an ALB SG id
        }
      ]
      egress = [
        {
          description = "All egress"
          protocol    = "-1"
          from_port   = 0
          to_port     = 0
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]
    }
    db = {
      vpc_id      = module.vpc.custom_vpc_id
      description = "DB tier SG"
      tags = { Tier = "db" }
      ingress = [
        {
          description = "Postgres from web"
          protocol    = "tcp"
          from_port   = 5432
          to_port     = 5432
          security_groups = [
            # Reference the created 'web' SG from this module output when known, or pass external SG ids
          ]
        }
      ]
      egress = [] # No egress
    }
  }
}
```

# Outputs available:

# - module.sg.security_group_ids: map(string)

# - module.sg.security_group_id_list: list(string)

# - module.sg.security_group_arns, .security_group_names

# - module.sg.total_ingress_rules, .total_egress_rules

# - module.sg.console_summary: list(string)
