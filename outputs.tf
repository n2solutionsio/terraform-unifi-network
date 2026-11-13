output "network_ids" {
  description = "Network names to IDs"
  value       = local.network_ids
}

output "zone_ids" {
  description = "Zone names (built-in and custom) to IDs"
  value       = local.zone_ids
}

output "policy_ids" {
  description = "Policy names to IDs"
  value       = { for k, v in unifi_firewall_policy.this : k => v.id }
}

output "port_profile_ids" {
  description = "Port profile names to IDs"
  value       = { for k, v in unifi_port_profile.this : k => v.id }
}

output "device_port_ids" {
  description = "Device port keys to IDs"
  value       = { for k, v in unifi_device_port.this : k => v.id }
}

output "client_ids" {
  description = "Client names to IDs"
  value       = { for k, v in unifi_client.this : k => v.id }
}
