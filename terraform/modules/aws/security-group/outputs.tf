output "security_group_ids" {
  description = "Map of security group IDs keyed by logical name"
  value       = { for k, sg in aws_security_group.this : k => sg.id }
}

output "security_group_id_list" {
  description = "List of all security group IDs (values of security_group_ids)"
  value       = values({ for k, sg in aws_security_group.this : k => sg.id })
}

output "security_group_arns" {
  description = "Map of security group ARNs keyed by logical name"
  value       = { for k, sg in aws_security_group.this : k => sg.arn }
}

output "security_group_names" {
  description = "Map of security group names keyed by logical name"
  value       = { for k, sg in aws_security_group.this : k => sg.name }
}

output "total_ingress_rules" {
  description = "Total number of ingress rules created across all security groups"
  value       = length(local.ingress_map)
}

output "total_egress_rules" {
  description = "Total number of egress rules created across all security groups"
  value       = length(local.egress_map)
}

output "console_summary" {
  description = "Human-friendly summary of security groups created"
  value       = [for k, sg in aws_security_group.this : format("%s: %s (%s)", k, sg.id, sg.name)]
}
