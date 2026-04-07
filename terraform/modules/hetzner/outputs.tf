# ── Standardised outputs ─────────────────────
# Every provider module exposes the same interface.

output "server_ip" {
  value = var.server_enabled ? hcloud_server.minecraft[0].ipv4_address : ""
}

output "server_id" {
  value = var.server_enabled ? hcloud_server.minecraft[0].id : null
}

output "server_status" {
  value = var.server_enabled ? hcloud_server.minecraft[0].status : "destroyed"
}

output "volume_id" {
  value = hcloud_volume.minecraft_data.id
}

output "minecraft_address" {
  value = var.server_enabled ? (
    var.domain_name != "" ? (
      var.domain_subdomain == "@" ? var.domain_name : "${var.domain_subdomain}.${var.domain_name}"
    ) : "${hcloud_server.minecraft[0].ipv4_address}:${var.minecraft_port}"
  ) : ""
}

output "domain" {
  value = var.domain_name != "" ? (
    var.domain_subdomain == "@" ? var.domain_name : "${var.domain_subdomain}.${var.domain_name}"
  ) : ""
}

output "dns_nameservers" {
  value = [
    "hydrogen.ns.hetzner.com",
    "oxygen.ns.hetzner.com",
    "helium.ns.hetzner.de",
  ]
}
