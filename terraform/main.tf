# ──────────────────────────────────────────────
# Minecraft Server – Multi-Provider Infrastructure
# ──────────────────────────────────────────────
# Set var.cloud_provider to choose: "hetzner" | "vultr"
# Future: "aws" | "oci"
#
# The VM is EPHEMERAL – created on start, destroyed on stop.
# The volume is PERSISTENT – survives VM destruction.
# Toggle var.server_enabled to create/destroy the VM.
# ──────────────────────────────────────────────

locals {
  # ── Per-provider defaults ──────────────────
  plan_defaults = {
    hetzner = "ccx33"
    vultr   = "vhp-4c-12gb-amd"
    aws     = "c6i.2xlarge"
    oci     = "VM.Standard.A1.Flex"
  }

  region_defaults = {
    hetzner = "hel1"           # Helsinki (~350km from Riga)
    vultr   = "sto"            # Stockholm (~800km from Riga)
    aws     = "eu-north-1"    # Stockholm
    oci     = "eu-amsterdam-1"
  }

  # Resolve "auto" / empty to provider-specific defaults
  server_plan = var.server_plan != "" ? var.server_plan : local.plan_defaults[var.cloud_provider]
  region      = var.region != "" ? var.region : local.region_defaults[var.cloud_provider]

  # Cloud-init (shared across all providers)
  cloud_init = templatefile("${path.module}/templates/cloud-init.yml", {
    ssh_public_key = var.ssh_public_key
  })
}

# ══════════════════════════════════════════════
# Provider Modules – only the selected one creates resources
# ══════════════════════════════════════════════

module "hetzner" {
  count  = var.cloud_provider == "hetzner" ? 1 : 0
  source = "./modules/hetzner"

  server_enabled     = var.server_enabled
  project_name       = var.project_name
  ssh_public_key     = var.ssh_public_key
  server_plan        = local.server_plan
  region             = local.region
  volume_size_gb     = var.volume_size_gb
  minecraft_port     = var.minecraft_port
  rcon_port          = var.rcon_port
  admin_ips          = var.admin_ips
  domain_name        = var.domain_name
  domain_subdomain   = var.domain_subdomain
  cloud_init_content = local.cloud_init
}

module "vultr" {
  count  = var.cloud_provider == "vultr" ? 1 : 0
  source = "./modules/vultr"

  server_enabled     = var.server_enabled
  project_name       = var.project_name
  ssh_public_key     = var.ssh_public_key
  server_plan        = local.server_plan
  region             = local.region
  volume_size_gb     = var.volume_size_gb
  minecraft_port     = var.minecraft_port
  rcon_port          = var.rcon_port
  admin_ips          = var.admin_ips
  domain_name        = var.domain_name
  domain_subdomain   = var.domain_subdomain
  cloud_init_content = local.cloud_init
}

# ── Future providers (uncomment when implemented) ──

# module "aws" {
#   count  = var.cloud_provider == "aws" ? 1 : 0
#   source = "./modules/aws"
#   ...
# }

# module "oci" {
#   count  = var.cloud_provider == "oci" ? 1 : 0
#   source = "./modules/oci"
#   ...
# }
