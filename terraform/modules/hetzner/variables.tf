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
  description = "Hetzner server type (e.g., ccx33)"
  type        = string
}

variable "region" {
  description = "Hetzner location (e.g., hel1)"
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
