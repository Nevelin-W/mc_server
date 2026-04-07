# ── Remote State ──────────────────────────────
# Option 1: Terraform Cloud (recommended for teams)
# Option 2: S3-compatible backend (Hetzner Object Storage)
#
# Uncomment ONE of the blocks below.

# ── Option 1: Terraform Cloud ────────────────
terraform {
  cloud {
    organization = "applications"
    workspaces {
      name = "mc_server"
    }
  }
}

# ── Option 2: S3-compatible (Hetzner Object Storage) ──
# terraform {
#   backend "s3" {
#     bucket                      = "mc-server-tfstate"
#     key                         = "terraform.tfstate"
#     region                      = "main"
#     endpoint                    = "https://fsn1.your-objectstorage.com"
#     skip_credentials_validation = true
#     skip_metadata_api_check     = true
#     skip_region_validation      = true
#     skip_requesting_account_id  = true
#     force_path_style            = true
#   }
# }

# ── Option 3: Local (default – for getting started) ──
# State is stored locally. DO NOT use this in production
# with multiple contributors. Migrate to Option 1 or 2.
