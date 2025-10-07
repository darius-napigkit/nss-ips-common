output "custom_vpc_id" {
  description = "ID of the custom VPC (if created)"
  value       = try(aws_vpc.this[0].id, null)
}

output "public_subnet_ids" {
  description = "IDs of public subnets (custom VPC)"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "IDs of private subnets (custom VPC)"
  value       = [for s in aws_subnet.private : s.id]
}

output "default_vpc_id" {
  description = "ID of the default VPC (if ensured)"
  value       = try(data.aws_vpc.default[0].id, try(aws_default_vpc.this[0].id, null))
}

output "default_subnet_ids" {
  description = "IDs of the default VPC subnets (if ensured)"
  value       = try(data.aws_subnets.default[0].ids, [])
}
