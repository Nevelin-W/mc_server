# ──────────────────────────────────────────────
# Vultr Module
# ──────────────────────────────────────────────
# Ephemeral VM + persistent block storage on Vultr.
# Toggle var.server_enabled to create/destroy the VM.
# ──────────────────────────────────────────────

terraform {
  required_providers {
    vultr = {
      source = "vultr/vultr"
    }
  }
}

# ── Lookup Ubuntu 24.04 OS ID ────────────────
data "vultr_os" "ubuntu" {
  filter {
    name   = "name"
    values = ["Ubuntu 24.04 LTS x64"]
  }
}

# ── SSH Key (persistent) ─────────────────────
resource "vultr_ssh_key" "minecraft" {
  name    = "${var.project_name}-key"
  ssh_key = var.ssh_public_key
}

# ── Server (ephemeral) ──────────────────────
resource "vultr_instance" "minecraft" {
  count = var.server_enabled ? 1 : 0

  label             = "${var.project_name}-server"
  region            = var.region
  plan              = var.server_plan
  os_id             = data.vultr_os.ubuntu.id
  ssh_key_ids       = [vultr_ssh_key.minecraft.id]
  user_data         = var.cloud_init_content
  backups           = "disabled" # We handle our own backups
  enable_ipv6       = true
  firewall_group_id = vultr_firewall_group.minecraft.id
  hostname          = var.project_name

  tags = [var.project_name, "managed-by-terraform"]
}

# ── Persistent Block Storage ─────────────────
# This ALWAYS exists. World data survives VM destruction.
resource "vultr_block_storage" "minecraft_data" {
  label                = "${var.project_name}-data"
  size_gb              = var.volume_size_gb
  region               = var.region
  block_type           = "storage_opt"
  attached_to_instance = var.server_enabled ? vultr_instance.minecraft[0].id : ""

  lifecycle {
    prevent_destroy = true
  }
}
