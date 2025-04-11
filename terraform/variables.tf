variable "config_mode" {
  description = "Toggle between merge (additive) and overwrite (exclusive) record-management."
  type        = string
  default     = "MERGE"

  # TODO - add validation for good measure
}

variable "default_ttl" {
  description = "Override the provider's default TTL (1800) if needed"
  type        = number
  default     = 1799
}