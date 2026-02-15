output "network_ids" {
  description = "Map of network names to their IDs"
  value       = { for k, v in unifi_network.this : k => v.id }
}

output "firewall_rule_ids" {
  description = "List of firewall rule IDs"
  value       = unifi_firewall_rule.this[*].id
}

output "port_profile_ids" {
  description = "Map of port profile names to their IDs"
  value       = { for k, v in unifi_port_profile.this : k => v.id }
}
