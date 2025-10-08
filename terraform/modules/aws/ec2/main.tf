# EC2 Module: Launch instances into default or custom VPC on public or private subnets with restricted ingress

# Optionally discover default VPC and subnets when requested
data "aws_vpc" "default" {
  count   = var.use_default_vpc ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.use_default_vpc && length(var.subnet_ids) == 0 ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

# Determine target VPC id
locals {
  target_vpc_id        = var.use_default_vpc ? data.aws_vpc.default[0].id : var.vpc_id
  candidate_subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : (var.use_default_vpc ? data.aws_subnets.default[0].ids : [])
}

resource "aws_instance" "this" {
  count                       = var.instance_count
  ami                         = var.ami
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = local.candidate_subnet_ids[count.index % max(1, length(local.candidate_subnet_ids))]
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = var.subnet_type == "public"

  tags = merge({
    Name = "${var.name}-${count.index}"
  }, var.tags)

  lifecycle {
    ignore_changes = [ami]
  }
}
