# Plan-only tests with a mocked provider. Addresses are documentation ranges
# (RFC 5737), not a real network.

mock_provider "unifi" {}

variables {
  networks = {
    "Alpha" = {
      vlan_id    = 101
      subnet     = "192.0.2.0/24"
      dhcp_start = "192.0.2.100"
      dhcp_stop  = "192.0.2.200"
      dhcp_dns   = ["198.51.100.53"]
    }
    "Beta" = {
      vlan_id      = 102
      subnet       = "198.51.100.0/24"
      zone         = "Beta"
      dhcp_enabled = false
    }
  }

  zones = ["Beta"]

  policies = {
    "Alpha to Beta HTTPS" = {
      source_zone      = "Internal"
      destination_zone = "Beta"
      protocol         = "tcp"
      source           = { networks = ["Alpha"] }
      destination      = { ips = ["198.51.100.10"], port = "443" }
    }
    "Beta to Internet" = {
      source_zone      = "Beta"
      destination_zone = "External"
    }
  }
}

run "networks" {
  command = plan

  assert {
    condition     = unifi_network.this["Alpha"].vlan == 101 && unifi_network.this["Alpha"].subnet == "192.0.2.1/24"
    error_message = "Alpha should be VLAN 101 with gateway 192.0.2.1/24"
  }

  assert {
    condition     = unifi_network.this["Alpha"].dhcp_server.dns.servers == tolist(["198.51.100.53"])
    error_message = "Alpha should hand out its DHCP DNS server"
  }

  assert {
    condition     = unifi_network.this["Beta"].dhcp_server.enabled == false && unifi_network.this["Beta"].dhcp_server.dns == null
    error_message = "Beta DHCP should be off with no DNS block"
  }

  assert {
    condition     = unifi_network.this["Alpha"].purpose == "corporate"
    error_message = "Default purpose should be corporate"
  }
}

run "zones" {
  command = plan

  assert {
    condition     = length(data.unifi_firewall_zone.builtin) == 6 && length(unifi_firewall_zone.this) == 1
    error_message = "Should read 6 built-in zones and create 1 custom zone"
  }

  assert {
    condition     = length(coalesce(unifi_firewall_zone.this["Beta"].network_ids, [])) == 0
    error_message = "A custom zone is created empty; membership comes from the network"
  }

  assert {
    condition     = unifi_network.this["Alpha"].firewall_zone_id == data.unifi_firewall_zone.builtin["Internal"].id
    error_message = "A network defaults to the Internal zone"
  }
}

run "policies" {
  command = plan

  assert {
    condition = (
      unifi_firewall_policy.this["Alpha to Beta HTTPS"].source.matching_target == "NETWORK" &&
      unifi_firewall_policy.this["Alpha to Beta HTTPS"].destination.matching_target == "IP" &&
      unifi_firewall_policy.this["Alpha to Beta HTTPS"].destination.port == "443" &&
      unifi_firewall_policy.this["Alpha to Beta HTTPS"].destination.port_matching_type == "SPECIFIC"
    )
    error_message = "Network source, IP destination, port 443"
  }

  assert {
    condition = (
      unifi_firewall_policy.this["Beta to Internet"].source.matching_target == "ANY" &&
      unifi_firewall_policy.this["Beta to Internet"].destination.zone_id == data.unifi_firewall_zone.builtin["External"].id
    )
    error_message = "Empty endpoints match ANY; built-in zones resolve by name"
  }

  assert {
    condition     = alltrue([for p in unifi_firewall_policy.this : p.action == "ALLOW" && p.create_allow_respond])
    error_message = "Policies default to ALLOW with return traffic allowed"
  }
}

run "device_ports" {
  command = plan

  variables {
    device_ports = {
      "00:00:5e:00:53:01/8" = {
        name             = "Uplink"
        native_network   = "Alpha"
        tagged_vlan_mgmt = "block_all"
      }
    }
  }

  assert {
    condition = (
      unifi_device_port.this["00:00:5e:00:53:01/8"].device_mac == "00:00:5e:00:53:01" &&
      unifi_device_port.this["00:00:5e:00:53:01/8"].index == 8
    )
    error_message = "Key splits into device MAC and port index"
  }
}

run "unknown_zone_fails" {
  command = plan

  variables {
    networks = {
      "Gamma" = {
        vlan_id = 103
        subnet  = "203.0.113.0/24"
        zone    = "Nope"
      }
    }
    policies = {}
  }

  expect_failures = [unifi_network.this["Gamma"]]
}

run "networks_and_ips_rejected" {
  command = plan

  variables {
    policies = {
      "Bad" = {
        source_zone      = "Internal"
        destination_zone = "External"
        source           = { networks = ["Alpha"], ips = ["192.0.2.5"] }
      }
    }
  }

  expect_failures = [var.policies]
}

run "builtin_name_rejected" {
  command = plan

  variables {
    zones = ["Internal"]
  }

  expect_failures = [var.zones]
}
