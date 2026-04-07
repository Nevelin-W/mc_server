# ──────────────────────────────────────────────
# Hetzner Cloud Module
# ──────────────────────────────────────────────
# Ephemeral VM + persistent volume on Hetzner Cloud.
# Toggle var.server_enabled to create/destroy the VM.
# ──────────────────────────────────────────────

terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    hetznerdns = {
      source = "timohirt/hetznerdns"
    }
  }
}

# ── SSH Key (persistent) ─────────────────────
resource "hcloud_ssh_key" "minecraft" {
  name       = "${var.project_name}-key"
  public_key = var.ssh_public_key
}

# ── Server (ephemeral) ──────────────────────
resource "hcloud_server" "minecraft" {
  count = var.server_enabled ? 1 : 0

  name        = "${var.project_name}-server"
  image       = "ubuntu-24.04"
  server_type = var.server_plan
  location    = var.region
  ssh_keys    = [hcloud_ssh_key.minecraft.id]

  labels = {
    project = var.project_name
    managed = "terraform"
  }

  user_data = var.cloud_init_content

  lifecycle {
    ignore_changes = [user_data]
  }
}

# ── Persistent Volume ────────────────────────
resource "hcloud_volume" "minecraft_data" {
  name     = "${var.project_name}-data"
  size     = var.volume_size_gb
  location = var.region
  format   = "ext4"

  labels = {
    project = var.project_name
    purpose = "minecraft-world-data"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# ── Volume Attachment (only when server exists) ──
resource "hcloud_volume_attachment" "minecraft_data" {
  count = var.server_enabled ? 1 : 0

  volume_id = hcloud_volume.minecraft_data.id
  server_id = hcloud_server.minecraft[0].id
  automount = true
}
