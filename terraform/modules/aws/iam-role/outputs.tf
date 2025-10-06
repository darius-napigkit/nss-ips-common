output "iam_role_arn" {
  description = "The ARN of the newly created IAM role."
  value       = aws_iam_role.custom_role.arn
}

output "iam_role_name" {
  description = "The name of the newly created IAM role."
  value       = aws_iam_role.custom_role.name
}

output "iam_user_arn" {
  description = "The ARN of the newly created IAM user (if created)."
  value       = var.create_iam_user ? aws_iam_user.assumer[0].arn : null
}

output "iam_user_name" {
  description = "The name of the newly created IAM user (if created)."
  value       = var.create_iam_user ? aws_iam_user.assumer[0].name : null
}

# --- NEW Outputs for Access Keys (Programmatic Access) ---

output "access_key_id" {
  description = "The Access Key ID for programmatic access (if created)."
  value       = var.create_programmatic_access ? aws_iam_access_key.assumer_keys[0].id : null
  sensitive   = true # Mark as sensitive
}

output "secret_access_key" {
  description = "The Secret Access Key for programmatic access (if created). **STORE THIS SECURELY.**"
  value       = var.create_programmatic_access ? aws_iam_access_key.assumer_keys[0].secret : null
  sensitive   = true # Mark as sensitive
}

# --- NEW Output for Console Access ---

output "console_password" {
  description = "The generated password for console access (if created). **STORE THIS SECURELY.**"
  value       = var.create_console_access ? aws_iam_user_login_profile.assumer_login[0].password : null
  sensitive   = true # Mark as sensitive
}
