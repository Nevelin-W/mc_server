# ──────────────────────────────────────────────
# Unified Outputs (provider-agnostic)
# ──────────────────────────────────────────────
# All provider modules expose the same interface.
# These outputs route to whichever module is active.
# ──────────────────────────────────────────────

locals {
  # Pick outputs from the active provider module
  active = (
    var.cloud_provider == "hetzner" ? module.hetzner[0] :
    var.cloud_provider == "vultr"   ? module.vultr[0] :
    null
  )
}

output "cloud_provider" {
  description = "Active cloud provider"
  value       = var.cloud_provider
}

output "server_enabled" {
  description = "Whether the server VM currently exists"
  value       = var.server_enabled
}

output "server_ip" {
  description = "Public IPv4 address of the Minecraft server"
  value       = var.server_enabled ? local.active.server_ip : "(server stopped)"
}

output "server_id" {
  description = "Provider-specific server ID"
  value       = local.active.server_id
}

output "server_status" {
  description = "Current server status"
  value       = local.active.server_status
}

output "volume_id" {
  description = "Persistent volume ID (always exists)"
  value       = local.active.volume_id
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = var.server_enabled ? "ssh root@${local.active.server_ip}" : "(server stopped)"
}

output "minecraft_address" {
  description = "Address players use to connect"
  value       = var.server_enabled ? local.active.minecraft_address : "(server stopped)"
}

output "domain" {
  description = "Domain name configured for the server"
  value       = local.active.domain != "" ? local.active.domain : "(no domain configured)"
}

output "dns_nameservers" {
  description = "Nameservers to point your domain to (provider-specific)"
  value       = local.active.dns_nameservers
}

output "server_size" {
  description = "Unified server size name"
  value       = var.server_size
}

output "server_plan" {
  description = "Resolved provider-specific plan ID"
  value       = local.server_plan
}

output "region" {
  description = "Resolved region for the active provider"
  value       = local.region
}
