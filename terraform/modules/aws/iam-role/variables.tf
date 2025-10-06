variable "role_name" {
  description = "The name for the IAM role."
  type        = string
}

variable "assume_role_policy" {
  description = "The trust policy document allowing entities to assume the role (e.g., EC2, Lambda)."
  type        = string
}

variable "policy_arns" {
  description = "A list of ARNs for policies to attach to the role (e.g., customer managed policies)."
  type        = list(string)
  default     = []
}

# --- Variables for IAM User Creation ---
variable "create_iam_user" {
  description = "Set to true to create an associated IAM user who can assume this role."
  type        = bool
  default     = false
}

variable "iam_user_name" {
  description = "The name for the IAM user, if create_iam_user is true."
  type        = string
  default     = ""
}

# --- NEW Variables for Access Configuration ---
variable "create_programmatic_access" {
  description = "Set to true to create an Access Key ID and Secret Access Key for the user."
  type        = bool
  default     = false
}

variable "create_console_access" {
  description = "Set to true to generate a login password for console access."
  type        = bool
  default     = false
}

variable "assign_power_user_policy" {
  description = "Set to true to attach the AWS Managed PowerUserAccess policy to the user."
  type        = bool
  default     = false
}
