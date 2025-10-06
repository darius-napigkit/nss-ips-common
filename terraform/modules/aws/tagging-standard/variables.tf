variable "environment" {
  description = "The environment name (e.g., dev, prod)."
  type        = string
}

variable "project" {
  description = "The project name."
  type        = string
}

variable "additional_tags" {
  description = "Additional tags to merge with standard tags."
  type        = map(string)
  default     = {}
}
