locals {
  # Define your company's standard/mandatory tags here
  standard_tags = {
    Environment = var.environment
    Project     = var.project
    Owner       = "NSS"
    ManagedBy   = "Terraform"
  }

  # Use the merge function to combine standard and additional tags.
  # If a key exists in both, the value from var.additional_tags wins.
  final_tags = merge(local.standard_tags, var.additional_tags)
}
