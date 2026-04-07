# ── Standardised outputs ─────────────────────
# Every provider module exposes the same interface.

output "server_ip" {
  value = var.server_enabled ? vultr_instance.minecraft[0].main_ip : ""
}

output "server_id" {
  value = var.server_enabled ? vultr_instance.minecraft[0].id : null
}

output "server_status" {
  value = var.server_enabled ? vultr_instance.minecraft[0].status : "destroyed"
}

output "volume_id" {
  value = vultr_block_storage.minecraft_data.id
}

output "minecraft_address" {
  value = var.server_enabled ? (
    var.domain_name != "" ? (
      var.domain_subdomain == "@" ? var.domain_name : "${var.domain_subdomain}.${var.domain_name}"
    ) : "${vultr_instance.minecraft[0].main_ip}:${var.minecraft_port}"
  ) : ""
}

output "domain" {
  value = var.domain_name != "" ? (
    var.domain_subdomain == "@" ? var.domain_name : "${var.domain_subdomain}.${var.domain_name}"
  ) : ""
}

output "dns_nameservers" {
  value = [
    "ns1.vultr.com",
    "ns2.vultr.com",
  ]
}
