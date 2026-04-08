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
  # ══════════════════════════════════════════════
  # Unified server size → provider-specific plan
  # ══════════════════════════════════════════════
  #
  # Size    │ Use case                         │ vCPU  │ RAM
  # ────────┼──────────────────────────────────┼───────┼────────
  # small   │ Testing, vanilla, 1-3 players    │ 2-4   │ 4-8 GB
  # medium  │ Light modpacks, ≤10 players      │ 4     │ 8-16 GB
  # large   │ Most modpacks, ≤20 players       │ 4-8   │ 12-32 GB  (default)
  # xlarge  │ ATM9/heavy packs, 20+ players    │ 8-16  │ 16-64 GB
  #
  size_map = {
    hetzner = {
      small  = "cx32"              # 4 shared vCPU,  8GB   ~€8/mo
      medium = "ccx23"             # 4 dedicated,   16GB  ~€22/mo
      large  = "ccx33"             # 8 dedicated,   32GB  ~€45/mo
      xlarge = "ccx43"             # 16 dedicated,  64GB  ~€90/mo
    }
    vultr = {
      small  = "vc2-2c-4gb"       # 2 vCPU,  4GB   ~€18/mo
      medium = "vhp-2c-4gb-amd"   # 2 HP,    4GB   ~€24/mo
      large  = "vhp-4c-12gb-amd"  # 4 HP,   12GB   ~€64/mo
      xlarge = "vhp-8c-16gb-amd"  # 8 HP,   16GB   ~€96/mo
    }
    aws = {
      small  = "c6i.large"        # 2 vCPU,  4GB
      medium = "c6i.xlarge"       # 4 vCPU,  8GB
      large  = "c6i.2xlarge"      # 8 vCPU, 16GB
      xlarge = "m6i.4xlarge"      # 16 vCPU, 64GB
    }
    oci = {
      small  = "VM.Standard.A1.Flex"  # 2 OCPU, 12GB (free tier)
      medium = "VM.Standard.A1.Flex"  # 4 OCPU, 24GB (free tier)
      large  = "VM.Standard.A1.Flex"  # 4 OCPU, 24GB (free tier)
      xlarge = "VM.Standard.E4.Flex"  # 8 OCPU, 64GB
    }
  }

  region_defaults = {
    hetzner = "hel1"           # Helsinki (~350km from Riga)
    vultr   = "sto"            # Stockholm (~800km from Riga)
    aws     = "eu-north-1"    # Stockholm
    oci     = "eu-amsterdam-1"
  }

  # Resolve: explicit plan override > size map > default (large)
  server_plan = var.server_plan != "" ? var.server_plan : local.size_map[var.cloud_provider][var.server_size]
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
