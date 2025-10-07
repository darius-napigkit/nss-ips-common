# VPC Module: Creates/ensures a default VPC and/or a custom VPC with public and private subnets
# Provider configuration should be done in the root module; do not configure providers in modules.

# Ensure a default VPC exists when requested
resource "aws_default_vpc" "this" {
  count = var.create_default_vpc ? 1 : 0

  tags = merge({
    Name = var.default_vpc_name
  }, var.tags)
}

# Optionally fetch info about the default VPC (useful for outputs/composition)
data "aws_vpc" "default" {
  count = var.create_default_vpc ? 1 : 0

  default = true
}

data "aws_subnets" "default" {
  count = var.create_default_vpc ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

# Custom VPC
resource "aws_vpc" "this" {
  count = var.create_custom_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge({
    Name = var.name
  }, var.tags)
}

resource "aws_internet_gateway" "this" {
  count = var.create_custom_vpc ? 1 : 0

  vpc_id = aws_vpc.this[0].id
  tags = merge({
    Name = "${var.name}-igw"
  }, var.tags)
}

# Public subnets
resource "aws_subnet" "public" {
  count = var.create_custom_vpc ? length(var.public_subnets) : 0

  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true
  tags = merge({
    Name = "${var.name}-public-${count.index}"
  }, var.tags)
}

# Private subnets
resource "aws_subnet" "private" {
  count = var.create_custom_vpc ? length(var.private_subnets) : 0

  vpc_id            = aws_vpc.this[0].id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]
  tags = merge({
    Name = "${var.name}-private-${count.index}"
  }, var.tags)
}

# Route table for public subnets
resource "aws_route_table" "public" {
  count = var.create_custom_vpc && length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.this[0].id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }
  tags = merge({
    Name = "${var.name}-public-rt"
  }, var.tags)
}

resource "aws_route_table_association" "public" {
  count = var.create_custom_vpc ? length(var.public_subnets) : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# NAT Gateway (optional)
resource "aws_eip" "nat" {
  count = var.create_custom_vpc && var.enable_nat_gateway && length(var.private_subnets) > 0 ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0

  # vpc   = true
  tags = merge({
    Name = "${var.name}-nat-eip-${count.index}"
  }, var.tags)
}

resource "aws_nat_gateway" "this" {
  count = length(aws_eip.nat)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[var.single_nat_gateway ? 0 : count.index].id
  tags = merge({
    Name = "${var.name}-nat-${count.index}"
  }, var.tags)
  depends_on = [aws_internet_gateway.this]
}

# Private route tables
resource "aws_route_table" "private" {
  count = var.create_custom_vpc && length(var.private_subnets) > 0 ? (var.single_nat_gateway ? 1 : length(var.private_subnets)) : 0

  vpc_id = aws_vpc.this[0].id
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
    }
  }
  tags = merge({
    Name = "${var.name}-private-rt-${count.index}"
  }, var.tags)
}

resource "aws_route_table_association" "private" {
  count = var.create_custom_vpc ? length(var.private_subnets) : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}
