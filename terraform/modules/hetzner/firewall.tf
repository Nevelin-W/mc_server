# ── Firewall ─────────────────────────────────
resource "hcloud_firewall" "minecraft" {
  name = "${var.project_name}-fw"

  # SSH (key-only auth enforced on the server)
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Minecraft (TCP)
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = var.minecraft_port
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Minecraft (UDP – voice mods, query)
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = var.minecraft_port
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # RCON – restricted to admin IPs only
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = var.rcon_port
    source_ips = var.admin_ips
  }

  # Node exporter – restricted to monitoring
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "9100"
    source_ips = var.admin_ips
  }

  labels = {
    project = var.project_name
  }
}

resource "hcloud_firewall_attachment" "minecraft" {
  count = var.server_enabled ? 1 : 0

  firewall_id = hcloud_firewall.minecraft.id
  server_ids  = [hcloud_server.minecraft[0].id]
}
