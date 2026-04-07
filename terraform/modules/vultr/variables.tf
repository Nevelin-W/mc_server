# ── Common variables (passed by root module) ──
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
  description = "Vultr plan ID (e.g., vhp-4c-12gb-amd)"
  type        = string
}

variable "region" {
  description = "Vultr region code (e.g., sto for Stockholm)"
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
