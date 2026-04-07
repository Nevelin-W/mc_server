# ── Hetzner DNS ──────────────────────────────
# Auto-updates A + SRV records when VM is created.
# Prerequisites:
#   1. Register a domain with any registrar
#   2. Point NS records to Hetzner:
#        hydrogen.ns.hetzner.com
#        oxygen.ns.hetzner.com
#        helium.ns.hetzner.de
#   3. Set var.domain_name

# ── DNS Zone ─────────────────────────────────
resource "hetznerdns_zone" "minecraft" {
  count = var.domain_name != "" ? 1 : 0

  name = var.domain_name
  ttl  = 60
}

# ── A record: points to current VM IP ────────
resource "hetznerdns_record" "minecraft_a" {
  count = var.domain_name != "" && var.server_enabled ? 1 : 0

  zone_id = hetznerdns_zone.minecraft[0].id
  name    = var.domain_subdomain
  type    = "A"
  value   = hcloud_server.minecraft[0].ipv4_address
  ttl     = 60
}

# ── A record: root domain redirect (optional) ─
resource "hetznerdns_record" "root_a" {
  count = var.domain_name != "" && var.server_enabled && var.domain_subdomain != "@" ? 1 : 0

  zone_id = hetznerdns_zone.minecraft[0].id
  name    = "@"
  type    = "A"
  value   = hcloud_server.minecraft[0].ipv4_address
  ttl     = 60
}

# ── SRV record: allows connecting without port ─
resource "hetznerdns_record" "minecraft_srv" {
  count = var.domain_name != "" && var.server_enabled ? 1 : 0

  zone_id = hetznerdns_zone.minecraft[0].id
  name    = "_minecraft._tcp.${var.domain_subdomain == "@" ? "" : var.domain_subdomain}"
  type    = "SRV"
  value   = "0 5 ${var.minecraft_port} ${var.domain_subdomain == "@" ? var.domain_name : "${var.domain_subdomain}.${var.domain_name}"}."
  ttl     = 60
}
