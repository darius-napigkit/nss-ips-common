variable "name" {
  description = "Name prefix for instances"
  type        = string
  default     = "nss-ec2"
}

variable "use_default_vpc" {
  description = "If true, target the default VPC (and discover its subnets if subnet_ids not provided)"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID where to create resources (ignored if use_default_vpc is true)"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "List of subnet IDs to choose from. If empty and use_default_vpc is true, default VPC subnets will be used."
  type        = list(string)
  default     = []
}

variable "subnet_type" {
  description = "Subnet type to target: public or private"
  type        = string
  default     = "public"
  validation {
    condition     = contains(["public", "private"], var.subnet_type)
    error_message = "subnet_type must be 'public' or 'private'."
  }
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 1
}

variable "ami" {
  description = "AMI ID to use for instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "security_group_ids" {
  description = "List of Security Group IDs where to associate the EC2 instance"
  type        = list(string)
  default     = []
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = null
}

variable "root_block_device" {
  type        = any
  default     = null
  description = <<EOT
Optional root block device configuration. Set to null to omit.
Example:
{
  volume_size           = 20
  volume_type           = "gp3"
  delete_on_termination = true
  encrypted             = true
  kms_key_id            = "arn:aws:kms:REGION:ACCOUNT:key/KEY-ID"
  iops                  = 3000
  throughput            = 125
}
EOT
}


variable "user_data" {
  description = "Optional user_data content. Pass null to disable, or provide file(\"${path.module}/script.sh\") from the calling module."
  type        = string
  default     = null
}

variable "user_data_replace_on_change" {
  description = "Replace the instance when user_data changes"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags to apply"
  type        = map(string)
  default     = {}
}
