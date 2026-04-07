# ══════════════════════════════════════════════
# Cloud Provider Selection
# ══════════════════════════════════════════════

variable "cloud_provider" {
  description = "Cloud provider to use: hetzner, vultr (aws, oci planned)"
  type        = string
  default     = "vultr"

  validation {
    condition     = contains(["hetzner", "vultr"], var.cloud_provider)
    error_message = "Supported providers: hetzner, vultr. (aws, oci coming soon)"
  }
}

# ══════════════════════════════════════════════
# Common Variables (all providers)
# ══════════════════════════════════════════════

variable "ssh_public_key" {
  description = "SSH public key for server access"
  type        = string
}

variable "server_enabled" {
  description = "Whether the VM should exist. false = destroy VM (stop), true = create VM (start). Volume always persists."
  type        = bool
  default     = true
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "mc-server"
}

variable "server_plan" {
  description = "Provider-specific server plan/type. Leave empty for smart default per provider."
  type        = string
  default     = "" # Auto: ccx33 (hetzner), vhp-4c-12gb-amd (vultr), c6i.2xlarge (aws)
}

variable "region" {
  description = "Provider-specific region/location. Leave empty for closest-to-Riga default."
  type        = string
  default     = "" # Auto: hel1 (hetzner), sto (vultr), eu-north-1 (aws)
}

variable "volume_size_gb" {
  description = "Persistent volume size in GB for world data"
  type        = number
  default     = 50
}

# ── Networking ───────────────────────────────
variable "minecraft_port" {
  description = "Minecraft server port"
  type        = string
  default     = "25565"
}

variable "rcon_port" {
  description = "RCON port"
  type        = string
  default     = "25575"
}

variable "admin_ips" {
  description = "List of admin IPs for SSH and RCON access (CIDR notation)"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"] # CHANGE THIS – restrict to your IP
}

# ── DNS (optional – works with all providers) ─
variable "domain_name" {
  description = "Domain name for Minecraft server (e.g., example.com). Leave empty to skip DNS."
  type        = string
  default     = ""
}

variable "domain_subdomain" {
  description = "Subdomain for the Minecraft server (e.g., 'mc' for mc.example.com, or '@' for root domain)"
  type        = string
  default     = "mc"
}

# ── Backup (Cloudflare R2 recommended) ───────
variable "backup_s3_endpoint" {
  description = "S3-compatible endpoint for backups. R2: https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
  type        = string
  default     = ""
}

variable "backup_s3_bucket" {
  description = "S3 bucket name for backups (R2 bucket name)"
  type        = string
  default     = "mc-server-backups"
}

# ══════════════════════════════════════════════
# Provider-Specific API Tokens
# ══════════════════════════════════════════════
# Only the token for your chosen cloud_provider is required.
# The rest can be left empty.

# ── Hetzner ──────────────────────────────────
variable "hcloud_token" {
  description = "Hetzner Cloud API token (required if cloud_provider = hetzner)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "hetzner_dns_token" {
  description = "Hetzner DNS API token. If empty, uses hcloud_token (same account)."
  type        = string
  sensitive   = true
  default     = ""
}

# ── Vultr ────────────────────────────────────
variable "vultr_api_key" {
  description = "Vultr API key (required if cloud_provider = vultr)"
  type        = string
  sensitive   = true
  default     = ""
}

# ── AWS (future) ─────────────────────────────
# variable "aws_access_key" { ... }
# variable "aws_secret_key" { ... }

# ── OCI (future) ─────────────────────────────
# variable "oci_tenancy_ocid" { ... }
# variable "oci_user_ocid" { ... }
