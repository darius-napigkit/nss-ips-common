# Security group that restricts ingress to allowed IPs
resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "Security group for ${var.name}"
  vpc_id      = var.target_vpc_id

  dynamic "ingress" {
    for_each = var.allowed_cidrs
    content {
      description = "allowed"
      from_port   = var.allowed_port
      to_port     = var.allowed_port
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.egress_cidrs
  }

  tags = merge({
    Name = "${var.name}-sg"
  }, var.tags)
}
