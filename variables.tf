variable "networks" {
  description = "VLAN networks keyed by name. `subnet` is the network CIDR; the gateway is host `gateway_host` in it. `zone` is a built-in zone or a key of `zones`."
  type = map(object({
    vlan_id        = number
    subnet         = string
    gateway_host   = optional(number, 1)
    zone           = optional(string, "Internal")
    purpose        = optional(string, "corporate")
    domain_name    = optional(string)
    igmp_snooping  = optional(bool)
    multicast_dns  = optional(bool)
    dhcp_enabled   = optional(bool, true)
    dhcp_start     = optional(string)
    dhcp_stop      = optional(string)
    dhcp_dns       = optional(list(string), [])
    dhcp_leasetime = optional(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.networks : v.vlan_id >= 1 && v.vlan_id <= 4094])
    error_message = "VLAN ID must be between 1 and 4094."
  }

  validation {
    condition     = alltrue([for k, v in var.networks : can(cidrhost(v.subnet, v.gateway_host))])
    error_message = "Each subnet must be a CIDR that contains gateway_host."
  }

  validation {
    condition     = alltrue([for k, v in var.networks : contains(["corporate", "guest", "vlan-only"], v.purpose)])
    error_message = "Network purpose must be corporate, guest or vlan-only."
  }
}

variable "builtin_zones" {
  description = "Controller built-in firewall zones to look up by name. They are read, never managed."
  type        = set(string)
  default     = ["Internal", "External", "Gateway", "Vpn", "Hotspot", "Dmz"]
}

variable "zones" {
  description = "Custom firewall zones to create. Membership is set on each network (`networks[*].zone`), so a zone starts empty."
  type        = set(string)
  default     = []

  validation {
    condition     = length(setintersection(var.zones, var.builtin_zones)) == 0
    error_message = "A custom zone cannot reuse a built-in zone name."
  }
}

variable "policies" {
  description = <<-EOT
    Zone-based firewall policies keyed by name. Each endpoint matches ANY, or
    `networks` (names from `networks`), or `ips` (addresses or CIDRs), never
    both. The controller appends every policy to the end of its zone pair and
    the provider cannot reorder them, so keep to ALLOW policies and let the
    zone defaults block the rest.
  EOT
  type = map(object({
    source_zone      = string
    destination_zone = string
    action           = optional(string, "ALLOW")
    protocol         = optional(string, "all")
    source = optional(object({
      networks = optional(list(string), [])
      ips      = optional(list(string), [])
    }), {})
    destination = optional(object({
      networks = optional(list(string), [])
      ips      = optional(list(string), [])
      port     = optional(string)
    }), {})
    logging     = optional(bool, false)
    enabled     = optional(bool, true)
    description = optional(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for k, p in var.policies : contains(["ALLOW", "BLOCK", "REJECT"], p.action)])
    error_message = "Policy action must be ALLOW, BLOCK or REJECT."
  }

  validation {
    condition     = alltrue([for k, p in var.policies : contains(["all", "tcp", "udp", "tcp_udp", "icmp", "icmpv6"], p.protocol)])
    error_message = "Policy protocol must be all, tcp, udp, tcp_udp, icmp or icmpv6."
  }

  validation {
    condition = alltrue([for k, p in var.policies :
      !(length(p.source.networks) > 0 && length(p.source.ips) > 0) &&
      !(length(p.destination.networks) > 0 && length(p.destination.ips) > 0)
    ])
    error_message = "A policy endpoint matches networks or ips, not both."
  }

  validation {
    condition     = alltrue([for k, p in var.policies : p.destination.port == null || contains(["tcp", "udp", "tcp_udp"], p.protocol)])
    error_message = "A destination port needs protocol tcp, udp or tcp_udp."
  }
}

variable "port_profiles" {
  description = "Switch port profiles keyed by name. Network references are names from `networks`."
  type = map(object({
    native_network   = optional(string)
    tagged_vlan_mgmt = optional(string)
    tagged_networks  = optional(list(string))
    forward          = optional(string)
    poe_mode         = optional(string)
  }))
  default = {}
}

variable "device_ports" {
  description = <<-EOT
    Individual switch or gateway ports keyed by "<device_mac>/<index>".
    Network references are names from `networks`. Unset fields keep the
    controller's current value.
  EOT
  type = map(object({
    name             = optional(string)
    native_network   = optional(string)
    tagged_vlan_mgmt = optional(string)
    tagged_networks  = optional(list(string))
    port_profile     = optional(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.device_ports : can(regex("^([0-9a-f]{2}:){5}[0-9a-f]{2}/[0-9]+$", k))])
    error_message = "device_ports keys must be \"<lowercase device_mac>/<port index>\"."
  }

  validation {
    condition     = alltrue([for k, v in var.device_ports : v.tagged_vlan_mgmt == null || contains(["auto", "block_all", "custom"], v.tagged_vlan_mgmt)])
    error_message = "tagged_vlan_mgmt must be auto, block_all or custom."
  }
}

variable "clients" {
  description = <<-EOT
    Known clients keyed by name, for fixed IPs (DHCP reservations). The
    controller already knows every client it has seen, so these take over the
    existing entry instead of creating one, and removing an entry stops
    managing the client without forgetting it.
  EOT
  type = map(object({
    mac      = string
    fixed_ip = optional(string)
    note     = optional(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.clients : can(regex("^([0-9a-f]{2}:){5}[0-9a-f]{2}$", v.mac))])
    error_message = "clients[*].mac must be a lowercase MAC address."
  }

  validation {
    condition     = alltrue([for k, v in var.clients : v.fixed_ip == null || can(cidrhost("${v.fixed_ip}/32", 0))])
    error_message = "clients[*].fixed_ip must be an IPv4 address."
  }
}
