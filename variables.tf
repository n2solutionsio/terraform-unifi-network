variable "networks" {
  description = "Map of VLAN networks to create"
  type = map(object({
    vlan_id         = number
    subnet          = string
    dhcp_enabled    = optional(bool, true)
    dhcp_start      = optional(string)
    dhcp_stop       = optional(string)
    domain_name     = optional(string)
    purpose         = optional(string, "corporate")
    network_group   = optional(string, "LAN")
    igmp_snooping   = optional(bool, false)
    dhcp_dns        = optional(list(string))
    dhcp_lease_time = optional(number)
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.networks : v.vlan_id >= 1 && v.vlan_id <= 4094])
    error_message = "VLAN ID must be between 1 and 4094."
  }
}

variable "firewall_rules" {
  description = "List of firewall rules to create"
  type = list(object({
    name                   = string
    action                 = string
    ruleset                = string
    rule_index             = number
    protocol               = optional(string, "all")
    src_network_id         = optional(string)
    dst_network_id         = optional(string)
    src_address            = optional(string)
    dst_address            = optional(string)
    dst_port               = optional(string)
    logging                = optional(bool, false)
    state_established      = optional(bool, false)
    state_related          = optional(bool, false)
    src_firewall_group_ids = optional(list(string))
    dst_firewall_group_ids = optional(list(string))
  }))
  default = []

  validation {
    condition     = alltrue([for r in var.firewall_rules : contains(["accept", "drop", "reject"], r.action)])
    error_message = "Firewall rule action must be accept, drop, or reject."
  }
}

variable "port_profiles" {
  description = "Map of switch port profiles to create"
  type = map(object({
    native_networkconf_id  = optional(string)
    tagged_networkconf_ids = optional(list(string))
    poe_mode               = optional(string)
    forward                = optional(string, "all")
  }))
  default = {}
}
