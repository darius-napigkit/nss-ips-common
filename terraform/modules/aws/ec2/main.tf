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

  # Optional root_block_device
  dynamic "root_block_device" {
    for_each = var.root_block_device == null ? [] : [var.root_block_device]
    content {
      volume_size           = lookup(root_block_device.value, "volume_size", null)
      volume_type           = lookup(root_block_device.value, "volume_type", null)
      delete_on_termination = lookup(root_block_device.value, "delete_on_termination", null)
      encrypted             = lookup(root_block_device.value, "encrypted", null)
      kms_key_id            = lookup(root_block_device.value, "kms_key_id", null)
      iops                  = lookup(root_block_device.value, "iops", null)
      throughput            = lookup(root_block_device.value, "throughput", null)
      # Some provider versions support tagging the EBS volume created for the root device:
      tags = merge({
        Name = "${var.name}-rbb"
      }, var.tags)
    }
  }

  # Optional user_data
  user_data                   = var.user_data
  user_data_replace_on_change = var.user_data_replace_on_change

  tags = merge({
    Name = "${var.name}-${count.index}"
  }, var.tags)

  lifecycle {
    ignore_changes = [ami]
  }
}
