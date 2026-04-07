# ──────────────────────────────────────────────
# Provider Configuration
# ──────────────────────────────────────────────
# All providers are declared but only the active one (var.cloud_provider)
# makes API calls. Inactive providers get a dummy token and do nothing.
# ──────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # ── Hetzner ──
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    hetznerdns = {
      source  = "timohirt/hetznerdns"
      version = "~> 2.2"
    }
    # ── Vultr ──
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.21"
    }
    # ── AWS (uncomment when implementing) ──
    # aws = {
    #   source  = "hashicorp/aws"
    #   version = "~> 5.0"
    # }
    # ── OCI (uncomment when implementing) ──
    # oci = {
    #   source  = "oracle/oci"
    #   version = "~> 5.0"
    # }
  }
}

# ── Hetzner Cloud ────────────────────────────
provider "hcloud" {
  token = var.hcloud_token != "" ? var.hcloud_token : "unused"
}

provider "hetznerdns" {
  apitoken = var.hetzner_dns_token != "" ? var.hetzner_dns_token : (
    var.hcloud_token != "" ? var.hcloud_token : "unused"
  )
}

# ── Vultr ────────────────────────────────────
provider "vultr" {
  api_key     = var.vultr_api_key != "" ? var.vultr_api_key : "unused"
  rate_limit  = 100
  retry_limit = 3
}

# ── AWS (uncomment when implementing) ────────
# provider "aws" {
#   region = local.region
# }

# ── OCI (uncomment when implementing) ────────
# provider "oci" {
#   region = local.region
# }
