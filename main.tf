locals {
  zone_ids = merge(
    { for name, z in data.unifi_firewall_zone.builtin : name => z.id },
    { for name, z in unifi_firewall_zone.this : name => z.id },
  )

  network_ids = { for name, n in unifi_network.this : name => n.id }
}

# -----------------------------------------------------------------------------
# Zones. Built-in zones are looked up, never managed (#717: External can't be
# updated). Custom zones are created empty; networks join them below.
# -----------------------------------------------------------------------------

data "unifi_firewall_zone" "builtin" {
  for_each = var.builtin_zones

  name = each.key
}

resource "unifi_firewall_zone" "this" {
  for_each = var.zones

  name = each.key

  lifecycle {
    # Membership is managed from the network side only (firewall_zone_id);
    # managing it here as well makes the two fight.
    ignore_changes = [network_ids]
  }
}

# -----------------------------------------------------------------------------
# Networks. prevent_destroy: a deleted network drops every client on it.
# -----------------------------------------------------------------------------

resource "unifi_network" "this" {
  for_each = var.networks

  name             = each.key
  vlan             = each.value.vlan_id
  subnet           = "${cidrhost(each.value.subnet, each.value.gateway_host)}/${split("/", each.value.subnet)[1]}"
  purpose          = each.value.purpose
  firewall_zone_id = lookup(local.zone_ids, each.value.zone, null)
  domain_name      = each.value.domain_name
  igmp_snooping    = each.value.igmp_snooping
  multicast_dns    = each.value.multicast_dns

  dhcp_server = {
    enabled   = each.value.dhcp_enabled
    start     = each.value.dhcp_start
    stop      = each.value.dhcp_stop
    leasetime = each.value.dhcp_leasetime
    dns = length(each.value.dhcp_dns) > 0 ? {
      enabled = true
      servers = each.value.dhcp_dns
    } : null
  }

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = contains(keys(local.zone_ids), each.value.zone)
      error_message = "Network ${each.key}: zone \"${each.value.zone}\" is neither a built-in zone nor in var.zones."
    }
  }
}

# -----------------------------------------------------------------------------
# Policies. Index is controller-assigned and can't be managed, so order within
# a zone pair is not under our control (see var.policies).
# -----------------------------------------------------------------------------

resource "unifi_firewall_policy" "this" {
  for_each = var.policies

  name        = each.key
  description = each.value.description
  action      = each.value.action
  protocol    = each.value.protocol
  enabled     = each.value.enabled
  logging     = each.value.logging
  ip_version  = "IPV4"

  # Return traffic for an ALLOW; without it the reply hits the zone default.
  create_allow_respond = each.value.action == "ALLOW"

  source = {
    zone_id         = lookup(local.zone_ids, each.value.source_zone, null)
    matching_target = length(each.value.source.networks) > 0 ? "NETWORK" : length(each.value.source.ips) > 0 ? "IP" : "ANY"
    network_ids     = length(each.value.source.networks) > 0 ? [for n in each.value.source.networks : lookup(local.network_ids, n, null)] : null
    ips             = length(each.value.source.ips) > 0 ? each.value.source.ips : null
  }

  destination = {
    zone_id            = lookup(local.zone_ids, each.value.destination_zone, null)
    matching_target    = length(each.value.destination.networks) > 0 ? "NETWORK" : length(each.value.destination.ips) > 0 ? "IP" : "ANY"
    network_ids        = length(each.value.destination.networks) > 0 ? [for n in each.value.destination.networks : lookup(local.network_ids, n, null)] : null
    ips                = length(each.value.destination.ips) > 0 ? each.value.destination.ips : null
    port_matching_type = each.value.destination.port != null ? "SPECIFIC" : null
    port               = each.value.destination.port
  }

  lifecycle {
    precondition {
      condition = alltrue([
        contains(keys(local.zone_ids), each.value.source_zone),
        contains(keys(local.zone_ids), each.value.destination_zone),
      ])
      error_message = "Policy ${each.key}: source and destination zones must be built-in zones or in var.zones."
    }

    precondition {
      condition     = alltrue([for n in concat(each.value.source.networks, each.value.destination.networks) : contains(keys(var.networks), n)])
      error_message = "Policy ${each.key}: every network must be a key of var.networks."
    }
  }
}

# -----------------------------------------------------------------------------
# Switching
# -----------------------------------------------------------------------------

resource "unifi_port_profile" "this" {
  for_each = var.port_profiles

  name                   = each.key
  native_networkconf_id  = each.value.native_network != null ? local.network_ids[each.value.native_network] : null
  tagged_vlan_mgmt       = each.value.tagged_vlan_mgmt
  tagged_networkconf_ids = each.value.tagged_networks != null ? [for n in each.value.tagged_networks : local.network_ids[n]] : null
  forward                = each.value.forward
  poe_mode               = each.value.poe_mode
}

resource "unifi_device_port" "this" {
  for_each = var.device_ports

  device_mac             = split("/", each.key)[0]
  index                  = tonumber(split("/", each.key)[1])
  name                   = each.value.name
  native_networkconf_id  = each.value.native_network != null ? local.network_ids[each.value.native_network] : null
  tagged_vlan_mgmt       = each.value.tagged_vlan_mgmt
  tagged_networkconf_ids = each.value.tagged_networks != null ? toset([for n in each.value.tagged_networks : local.network_ids[n]]) : null
  port_profile_id        = each.value.port_profile != null ? unifi_port_profile.this[each.value.port_profile].id : null
}

# -----------------------------------------------------------------------------
# Clients
# -----------------------------------------------------------------------------

resource "unifi_client" "this" {
  for_each = var.clients

  mac      = each.value.mac
  name     = each.key
  fixed_ip = each.value.fixed_ip
  note     = each.value.note

  allow_existing         = true
  skip_forget_on_destroy = true
}
