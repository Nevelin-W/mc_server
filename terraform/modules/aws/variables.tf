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
  description = "AWS instance type (e.g., c6i.2xlarge)"
  type        = string
}

variable "region" {
  description = "AWS region (e.g., eu-north-1)"
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

# ── AWS-specific variables ───────────────────
variable "use_spot" {
  description = "Use Spot instances for ~70% cost savings (recommended for MC)"
  type        = bool
  default     = true
}
