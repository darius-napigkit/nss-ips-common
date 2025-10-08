variable "name" {
  description = "Name prefix for security groups"
  type        = string
  default     = "nss-sg"
}

variable "target_vpc_id" {
  description = "ID of target VPC for which the Security Group will be attached to"
  type        = string
  default     = "default"
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
  description = "A mapping of tags to assign to the resource"
  type        = map(string)
  default     = {}
}
