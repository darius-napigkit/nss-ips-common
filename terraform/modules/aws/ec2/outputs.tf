output "instance_ids" {
  description = "IDs of created instances"
  value       = [for i in aws_instance.this : i.id]
}

output "public_ips" {
  description = "Public IPs of created instances (if any)"
  value       = [for i in aws_instance.this : i.public_ip]
}

output "private_ips" {
  description = "Private IPs of created instances"
  value       = [for i in aws_instance.this : i.private_ip]
}

output "security_group_id" {
  description = "ID of the security group applied to instances"
  value       = aws_security_group.this.id
}
