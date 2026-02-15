resource "unifi_network" "this" {
  for_each = var.networks

  name          = each.key
  vlan_id       = each.value.vlan_id
  subnet        = each.value.subnet
  dhcp_enabled  = each.value.dhcp_enabled
  dhcp_start    = each.value.dhcp_start
  dhcp_stop     = each.value.dhcp_stop
  domain_name   = each.value.domain_name
  purpose       = each.value.purpose
  network_group = each.value.network_group
  igmp_snooping = each.value.igmp_snooping
  dhcp_dns      = each.value.dhcp_dns
  dhcp_lease    = each.value.dhcp_lease_time
}

resource "unifi_firewall_rule" "this" {
  count = length(var.firewall_rules)

  name       = var.firewall_rules[count.index].name
  action     = var.firewall_rules[count.index].action
  ruleset    = var.firewall_rules[count.index].ruleset
  rule_index = var.firewall_rules[count.index].rule_index
  protocol   = var.firewall_rules[count.index].protocol

  src_network_id = var.firewall_rules[count.index].src_network_id
  dst_network_id = var.firewall_rules[count.index].dst_network_id
  src_address    = var.firewall_rules[count.index].src_address
  dst_address    = var.firewall_rules[count.index].dst_address
  dst_port       = var.firewall_rules[count.index].dst_port
  logging        = var.firewall_rules[count.index].logging

  state_established = var.firewall_rules[count.index].state_established
  state_related     = var.firewall_rules[count.index].state_related

  src_firewall_group_ids = var.firewall_rules[count.index].src_firewall_group_ids
  dst_firewall_group_ids = var.firewall_rules[count.index].dst_firewall_group_ids
}

resource "unifi_port_profile" "this" {
  for_each = var.port_profiles

  name                   = each.key
  native_networkconf_id  = each.value.native_networkconf_id
  tagged_networkconf_ids = each.value.tagged_networkconf_ids
  poe_mode               = each.value.poe_mode
  forward                = each.value.forward
}
