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

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = null
}

variable "allowed_cidrs" {
  description = "List of CIDR blocks allowed to connect (e.g., for SSH). If empty, no ingress is allowed."
  type        = list(string)
  default     = []
}

variable "allowed_port" {
  description = "TCP port to allow from allowed_cidrs (e.g., 22 for SSH)"
  type        = number
  default     = 22
}

variable "egress_cidrs" {
  description = "Egress CIDRs for the security group"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Common tags to apply"
  type        = map(string)
  default     = {}
}
