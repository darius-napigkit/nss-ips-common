# Security Group Module: flexible, multi-SG, multi-rule support
# This module can create one or many security groups with zero/one/many ingress/egress rules.
# It is compatible with a legacy single-SG interface via legacy variables when `security_groups` is empty.

locals {
  legacy_sg = {
    for_use = length(var.security_groups) == 0 ? true : false
    sg_map = length(var.security_groups) == 0 ? {
      (var.name) = {
        vpc_id                 = var.target_vpc_id
        description            = var.description
        tags                   = var.tags
        revoke_rules_on_delete = true
        ingress = length(var.allowed_cidrs) > 0 ? [for c in var.allowed_cidrs : {
          description              = "allowed"
          protocol                 = "tcp"
          from_port                = var.allowed_port
          to_port                  = var.allowed_port
          cidr_blocks              = [c]
          ipv6_cidr_blocks         = []
          prefix_list_ids          = []
          security_groups          = []
          source_security_group_id = null
          self                     = false
        }] : []
        egress = length(var.egress_cidrs) > 0 ? [{
          description              = "egress"
          protocol                 = "-1"
          from_port                = 0
          to_port                  = 0
          cidr_blocks              = var.egress_cidrs
          ipv6_cidr_blocks         = []
          prefix_list_ids          = []
          security_groups          = []
          source_security_group_id = null
          self                     = false
        }] : []
      }
    } : var.security_groups
  }

  security_groups = local.legacy_sg.sg_map

  # Expand any rule that contains multiple referenced security groups into multiple rules, one per SG.
  expanded_ingress = flatten([
    for sg_key, sg in local.security_groups : [
      for idx, r in lookup(sg, "ingress", []) : (
        length(lookup(r, "security_groups", [])) > 0
        ? [for i, ref_sg in r.security_groups : merge(r, {
          key                      = "${sg_key}-ingress-${idx}-${i}"
          sg_key                   = sg_key
          source_security_group_id = try(r.source_security_group_id, ref_sg)
          security_groups          = null
        })]
        : [merge(r, {
          key    = "${sg_key}-ingress-${idx}"
          sg_key = sg_key
        })]
      )
    ]
  ])

  expanded_egress = flatten([
    for sg_key, sg in local.security_groups : [
      for idx, r in lookup(sg, "egress", []) : (
        length(lookup(r, "security_groups", [])) > 0
        ? [for i, ref_sg in r.security_groups : merge(r, {
          key                      = "${sg_key}-egress-${idx}-${i}"
          sg_key                   = sg_key
          source_security_group_id = try(r.source_security_group_id, ref_sg)
          security_groups          = null
        })]
        : [merge(r, {
          key    = "${sg_key}-egress-${idx}"
          sg_key = sg_key
        })]
      )
    ]
  ])

  ingress_map = { for r in local.expanded_ingress : r.key => r }
  egress_map  = { for r in local.expanded_egress : r.key => r }
}

resource "aws_security_group" "this" {
  for_each = local.security_groups

  name                   = "${each.key}-sg"
  description            = coalesce(try(each.value.description, null), "Security group ${each.key}")
  vpc_id                 = each.value.vpc_id
  revoke_rules_on_delete = try(each.value.revoke_rules_on_delete, true)

  tags = merge({
    Name = "${each.key}-sg"
  }, try(each.value.tags, {}))
}

# Ingress rules (zero or many)
resource "aws_security_group_rule" "ingress" {
  for_each = local.ingress_map

  type                     = "ingress"
  security_group_id        = aws_security_group.this[each.value.sg_key].id
  description              = try(each.value.description, null)
  protocol                 = try(each.value.protocol, "tcp")
  from_port                = try(each.value.from_port, 0)
  to_port                  = try(each.value.to_port, 0)
  cidr_blocks              = try(each.value.cidr_blocks, null)
  ipv6_cidr_blocks         = try(each.value.ipv6_cidr_blocks, null)
  prefix_list_ids          = try(each.value.prefix_list_ids, null)
  source_security_group_id = try(each.value.source_security_group_id, null)
  self                     = try(each.value.self, null)
}

# Egress rules (zero or many)
resource "aws_security_group_rule" "egress" {
  for_each = local.egress_map

  type                     = "egress"
  security_group_id        = aws_security_group.this[each.value.sg_key].id
  description              = try(each.value.description, null)
  protocol                 = try(each.value.protocol, "-1")
  from_port                = try(each.value.from_port, 0)
  to_port                  = try(each.value.to_port, 0)
  cidr_blocks              = try(each.value.cidr_blocks, null)
  ipv6_cidr_blocks         = try(each.value.ipv6_cidr_blocks, null)
  prefix_list_ids          = try(each.value.prefix_list_ids, null)
  source_security_group_id = try(each.value.source_security_group_id, null)
  self                     = try(each.value.self, null)
}
