# ── Common variables (same interface as other modules) ──
variable "server_enabled" {
  type = bool
}

variable "project_name" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "server_plan" {
  description = "OCI shape (e.g., VM.Standard.A1.Flex)"
  type        = string
}

variable "region" {
  description = "OCI region (e.g., eu-amsterdam-1)"
  type        = string
}

variable "volume_size_gb" {
  type = number
}

variable "minecraft_port" {
  type = string
}

variable "rcon_port" {
  type = string
}

variable "admin_ips" {
  type = list(string)
}

variable "domain_name" {
  type    = string
  default = ""
}

variable "domain_subdomain" {
  type    = string
  default = "mc"
}

variable "cloud_init_content" {
  type    = string
  default = ""
}

# ── OCI-specific variables ───────────────────
variable "ocpus" {
  description = "Number of OCPUs for flexible shapes (free tier: up to 4)"
  type        = number
  default     = 4
}

variable "memory_gb" {
  description = "Memory in GB for flexible shapes (free tier: up to 24)"
  type        = number
  default     = 24
}
