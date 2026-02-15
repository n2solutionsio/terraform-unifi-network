mock_provider "unifi" {}

variables {
  networks = {
    "Management" = {
      vlan_id      = 10
      subnet       = "10.10.10.0/24"
      dhcp_enabled = true
      dhcp_start   = "10.10.10.100"
      dhcp_stop    = "10.10.10.254"
    }
    "Storage" = {
      vlan_id      = 20
      subnet       = "10.20.20.0/24"
      dhcp_enabled = false
    }
  }

  firewall_rules = [
    {
      name       = "allow-management-to-storage"
      action     = "accept"
      ruleset    = "LAN_IN"
      rule_index = 2001
      protocol   = "all"
    },
    {
      name       = "drop-inter-vlan"
      action     = "drop"
      ruleset    = "LAN_IN"
      rule_index = 2100
      protocol   = "all"
    },
  ]

  port_profiles = {
    "trunk-all" = {
      forward = "all"
    }
  }
}

run "creates_networks_with_correct_vlan" {
  command = plan

  assert {
    condition     = unifi_network.this["Management"].vlan_id == 10
    error_message = "Management VLAN ID should be 10"
  }

  assert {
    condition     = unifi_network.this["Storage"].vlan_id == 20
    error_message = "Storage VLAN ID should be 20"
  }
}

run "dhcp_enable_disable" {
  command = plan

  assert {
    condition     = unifi_network.this["Management"].dhcp_enabled == true
    error_message = "Management DHCP should be enabled"
  }

  assert {
    condition     = unifi_network.this["Storage"].dhcp_enabled == false
    error_message = "Storage DHCP should be disabled"
  }
}

run "creates_firewall_rules" {
  command = plan

  assert {
    condition     = length(unifi_firewall_rule.this) == 2
    error_message = "Should create 2 firewall rules"
  }

  assert {
    condition     = unifi_firewall_rule.this[0].action == "accept"
    error_message = "First rule should be accept"
  }

  assert {
    condition     = unifi_firewall_rule.this[1].action == "drop"
    error_message = "Second rule should be drop"
  }
}

run "creates_port_profiles" {
  command = plan

  assert {
    condition     = unifi_port_profile.this["trunk-all"].forward == "all"
    error_message = "Port profile forward should be all"
  }
}

run "default_values" {
  command = plan

  assert {
    condition     = unifi_network.this["Management"].purpose == "corporate"
    error_message = "Default purpose should be corporate"
  }

  assert {
    condition     = unifi_network.this["Management"].network_group == "LAN"
    error_message = "Default network_group should be LAN"
  }
}
