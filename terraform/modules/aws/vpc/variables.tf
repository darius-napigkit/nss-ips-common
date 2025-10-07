variable "name" {
  description = "Name prefix for VPC resources"
  type        = string
  default     = "nss"
}

variable "tags" {
  description = "Common tags to apply"
  type        = map(string)
  default     = {}
}

variable "create_default_vpc" {
  description = "Whether to ensure a default VPC exists and output its info"
  type        = bool
  default     = true
}

variable "default_vpc_name" {
  description = "Tag name to apply to default VPC when created"
  type        = string
  default     = "default"
}

variable "create_custom_vpc" {
  description = "Whether to create a custom VPC"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of availability zones to use (must match number of subnets)"
  type        = list(string)
  default     = []
}

variable "public_subnets" {
  description = "List of public subnet CIDRs"
  type        = list(string)
  default     = []
}

variable "private_subnets" {
  description = "List of private subnet CIDRs"
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Create a NAT gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway across all private subnets (cost saver)"
  type        = bool
  default     = true
}

# Basic validations
validation {
  condition     = !(var.create_custom_vpc && (length(var.public_subnets) != length(var.private_subnets) || length(var.public_subnets) != length(var.azs)))
  error_message = "When creating a custom VPC, public_subnets, private_subnets, and azs lists must be the same non-zero length."
}
