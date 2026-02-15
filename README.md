# terraform-unifi-network

OpenTofu module for managing UniFi network infrastructure — VLANs, DHCP, firewall rules, and switch port profiles.

## Usage

```hcl
module "network" {
  source = "git::https://github.com/n2solutionsio/terraform-unifi-network.git?ref=v0.1.0"

  networks = {
    "Management" = {
      vlan_id      = 10
      subnet       = "10.10.10.0/24"
      dhcp_enabled = true
      dhcp_start   = "10.10.10.100"
      dhcp_stop    = "10.10.10.254"
    }
  }

  firewall_rules = [
    {
      name       = "drop-inter-vlan"
      action     = "drop"
      ruleset    = "LAN_IN"
      rule_index = 2100
    },
  ]
}
```

## Requirements

| Name | Version |
|------|---------|
| OpenTofu/Terraform | >= 1.6.0 |
| unifi | ~> 0.41.0 |

## License

MPL-2.0
