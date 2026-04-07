# ── Vultr DNS ────────────────────────────────
# Auto-updates A + SRV records when VM is created.
# Vultr DNS hosting is free with every account.
# Prerequisites:
#   1. Register a domain with any registrar
#   2. Point NS records to Vultr:
#        ns1.vultr.com
#        ns2.vultr.com

resource "vultr_dns_domain" "minecraft" {
  count = var.domain_name != "" ? 1 : 0

  domain    = var.domain_name
  # Vultr requires an initial IP; use a placeholder when server is down
  ip        = var.server_enabled ? vultr_instance.minecraft[0].main_ip : "127.0.0.1"
  dns_sec   = "disabled"
}

# ── A record: points to current VM IP ────────
resource "vultr_dns_record" "minecraft_a" {
  count = var.domain_name != "" && var.server_enabled ? 1 : 0

  domain = vultr_dns_domain.minecraft[0].domain
  name   = var.domain_subdomain == "@" ? "" : var.domain_subdomain
  type   = "A"
  data   = vultr_instance.minecraft[0].main_ip
  ttl    = 60
}

# ── A record: root domain (optional) ────────
resource "vultr_dns_record" "root_a" {
  count = var.domain_name != "" && var.server_enabled && var.domain_subdomain != "@" ? 1 : 0

  domain = vultr_dns_domain.minecraft[0].domain
  name   = ""
  type   = "A"
  data   = vultr_instance.minecraft[0].main_ip
  ttl    = 60
}

# ── SRV record: allows portless connections ──
resource "vultr_dns_record" "minecraft_srv" {
  count = var.domain_name != "" && var.server_enabled ? 1 : 0

  domain   = vultr_dns_domain.minecraft[0].domain
  name     = "_minecraft._tcp.${var.domain_subdomain == "@" ? "" : var.domain_subdomain}"
  type     = "SRV"
  data     = "${var.domain_subdomain == "@" ? var.domain_name : "${var.domain_subdomain}.${var.domain_name}"}"
  ttl      = 60
  priority = 0
}
