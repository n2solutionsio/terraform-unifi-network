# terraform-unifi-network

OpenTofu module for UniFi networks on the zone-based firewall (UniFi Network 9+):
VLANs and DHCP, custom firewall zones, zone-based policies, switch port
profiles and individual device ports.

## Usage

```hcl
module "network" {
  source = "git::https://github.com/n2solutionsio/terraform-unifi-network.git?ref=v1.0.0"

  networks = {
    "Servers" = {
      vlan_id    = 101
      subnet     = "192.0.2.0/24"
      zone       = "Servers"
      dhcp_start = "192.0.2.100"
      dhcp_stop  = "192.0.2.200"
      dhcp_dns   = ["198.51.100.53"]
    }
  }

  zones = ["Servers"]

  policies = {
    "Internal to Servers HTTPS" = {
      source_zone      = "Internal"
      destination_zone = "Servers"
      protocol         = "tcp"
      destination      = { port = "443" }
    }
  }
}
```

## How it behaves

- **Everything is keyed by name** (`for_each`), so adding or removing one entry
  never touches the others.
- **Built-in zones** (`Internal`, `External`, `Gateway`, `Vpn`, `Hotspot`,
  `Dmz`) are read as data sources and never managed.
- **Zone membership is set on the network** (`networks[*].zone`, default
  `Internal`). Custom zones are created empty and ignore their own
  `network_ids`, so the two sides never fight. Moving a network between zones
  is a one-line change.
- **Policy order can't be managed.** The controller appends each policy to the
  end of its zone pair, and the provider can't reorder them. Prefer `ALLOW`
  policies and let the zone defaults block everything else. `ALLOW` policies
  also allow return traffic (`create_allow_respond`).
- **Networks have `prevent_destroy`.** Deleting a network drops its clients;
  remove one deliberately with a `removed` block.
- **Adopting existing objects:** put `import` blocks in the root configuration
  (or the Terragrunt unit), keyed by name, e.g.
  `id = "name=Servers"` for `unifi_network.this["Servers"]`.

## Upgrading from v0.x

v1.0.0 is a breaking change:

- Provider moves from `paultyng/unifi` (archived) to
  `ubiquiti-community/unifi`, pinned exactly.
- `firewall_rules` (legacy `LAN_IN` rules, `count`-indexed) is removed;
  use `zones` and `policies`.
- `networks[*].subnet` is now the network CIDR (the gateway is
  `gateway_host`, default 1), DHCP DNS is `dhcp_dns`, the lease is
  `dhcp_leasetime` as a duration string, and `network_group` is gone.
- Network references in `port_profiles` and `device_ports` are names, not IDs.

Don't swap the version under an existing state: import into a new state and
release the old one with `removed { lifecycle { destroy = false } }`.

## Requirements

| Name | Version |
|------|---------|
| OpenTofu | >= 1.9.0 |
| ubiquiti-community/unifi | = 0.65.0 |

## License

MPL-2.0
