# ── Vultr Firewall ───────────────────────────
resource "vultr_firewall_group" "minecraft" {
  description = "${var.project_name} firewall"
}

# SSH – restricted to admin IPs
resource "vultr_firewall_rule" "ssh" {
  count = length(var.admin_ips)

  firewall_group_id = vultr_firewall_group.minecraft.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = cidrhost(var.admin_ips[count.index], 0)
  subnet_size       = tonumber(split("/", var.admin_ips[count.index])[1])
  port              = "22"
  notes             = "SSH from admin"
}

# Minecraft TCP – open to all
resource "vultr_firewall_rule" "minecraft_tcp" {
  firewall_group_id = vultr_firewall_group.minecraft.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = var.minecraft_port
  notes             = "Minecraft TCP"
}

resource "vultr_firewall_rule" "minecraft_tcp_v6" {
  firewall_group_id = vultr_firewall_group.minecraft.id
  protocol          = "tcp"
  ip_type           = "v6"
  subnet            = "::"
  subnet_size       = 0
  port              = var.minecraft_port
  notes             = "Minecraft TCP IPv6"
}

# Minecraft UDP – open to all (voice mods, query)
resource "vultr_firewall_rule" "minecraft_udp" {
  firewall_group_id = vultr_firewall_group.minecraft.id
  protocol          = "udp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = var.minecraft_port
  notes             = "Minecraft UDP"
}

# RCON – restricted to admin IPs
resource "vultr_firewall_rule" "rcon" {
  count = length(var.admin_ips)

  firewall_group_id = vultr_firewall_group.minecraft.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = cidrhost(var.admin_ips[count.index], 0)
  subnet_size       = tonumber(split("/", var.admin_ips[count.index])[1])
  port              = var.rcon_port
  notes             = "RCON from admin"
}

# Node exporter – restricted to admin IPs
resource "vultr_firewall_rule" "node_exporter" {
  count = length(var.admin_ips)

  firewall_group_id = vultr_firewall_group.minecraft.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = cidrhost(var.admin_ips[count.index], 0)
  subnet_size       = tonumber(split("/", var.admin_ips[count.index])[1])
  port              = "9100"
  notes             = "Node exporter"
}
