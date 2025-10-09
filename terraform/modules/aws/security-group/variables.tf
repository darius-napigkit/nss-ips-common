variable "name" {
  description = "Name key for legacy single security group mode (used when security_groups is empty)"
  type        = string
  default     = "nss-sg"
}

variable "target_vpc_id" {
  description = "Legacy: VPC ID for the single security group (used when security_groups is empty)"
  type        = string
  default     = null
}

variable "allowed_cidrs" {
  description = "Legacy: List of CIDR blocks allowed to connect (e.g., for SSH). If empty, no ingress is allowed."
  type        = list(string)
  default     = []
}

variable "allowed_port" {
  description = "Legacy: TCP port to allow from allowed_cidrs (e.g., 22 for SSH)"
  type        = number
  default     = 22
}

variable "egress_cidrs" {
  description = "Legacy: Egress CIDRs for the security group"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Legacy: tags for the single security group (merged into the SG created in legacy mode)"
  type        = map(string)
  default     = {}
}

variable "security_groups" {
  description = "Map of security group definitions. Key = logical SG name. Each value is an object with: vpc_id (string), description (string, optional), tags (map(string), optional), revoke_rules_on_delete (bool, optional), ingress (list(object), optional), egress (list(object), optional). In rule objects you can use: description, protocol, from_port, to_port, cidr_blocks, ipv6_cidr_blocks, prefix_list_ids, security_groups (list of SG IDs to expand), source_security_group_id, self."
  type = object({
    vpc_id                 = string
    description            = optional(string)
    tags                   = optional(map(string))
    revoke_rules_on_delete = optional(bool)
    ingress = optional(list(object({
      description              = optional(string)
      protocol                 = optional(string)
      from_port                = optional(number)
      to_port                  = optional(number)
      cidr_blocks              = optional(list(string))
      ipv6_cidr_blocks         = optional(list(string))
      prefix_list_ids          = optional(list(string))
      security_groups          = optional(list(string))
      source_security_group_id = optional(string)
      self                     = optional(bool)
    })))
    egress = optional(list(object({
      description              = optional(string)
      protocol                 = optional(string)
      from_port                = optional(number)
      to_port                  = optional(number)
      cidr_blocks              = optional(list(string))
      ipv6_cidr_blocks         = optional(list(string))
      prefix_list_ids          = optional(list(string))
      security_groups          = optional(list(string))
      source_security_group_id = optional(string)
      self                     = optional(bool)
    })))
  })
  default = null
}
