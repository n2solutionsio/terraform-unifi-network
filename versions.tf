terraform {
  required_version = ">= 1.9.0"

  required_providers {
    unifi = {
      source = "ubiquiti-community/unifi"
      # Exact pin: pre-1.0 provider on a private controller API. Bump only
      # after a zero-change plan against the controller (ADR-0029).
      version = "= 0.65.0"
    }
  }
}
