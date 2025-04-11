terraform {
  backend "local" {
    # Path set by environment variable points to cloud-backed storage.
  }
  required_providers {
    namecheap = {
      source  = "namecheap/namecheap"
      version = "~>2.2"
    }
  }
}

provider "namecheap" {
  # All configuration set with environment variables.
}

locals {
  csanford_cloud_record_config = flatten([
    for type, set in yamldecode(file("${path.module}/records.yaml")) : [
      for record in set : {
        address  = record.value
        hostname = record.host
        type     = upper(type)
        mx_pref  = type == "mx" ? record.weight : null
        ttl      = try(record.ttl, var.default_ttl)
      }
    ]
  ])
}

resource "namecheap_domain_records" "csanford_cloud" {
  domain     = "csanford.cloud"
  email_type = "MX"
  mode       = var.config_mode

  dynamic "record" {
    for_each = local.csanford_cloud_record_config
    content {
      address  = record.value.address
      hostname = record.value.hostname
      type     = record.value.type
      mx_pref  = record.value.mx_pref
      ttl      = record.value.ttl
    }
  }
}