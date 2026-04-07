# ──────────────────────────────────────────────
# Oracle Cloud (OCI) Module – BOILERPLATE
# ──────────────────────────────────────────────
# TODO: Complete implementation when OCI support is needed.
# This provides the module interface so Terraform validates.
# ──────────────────────────────────────────────

terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

# ── Placeholder resources ────────────────────
# Uncomment and implement when ready:
#
# resource "oci_core_instance" "minecraft" { ... }
# resource "oci_core_volume" "minecraft_data" { ... }
# resource "oci_core_volume_attachment" "minecraft_data" { ... }
# resource "oci_core_vcn" "minecraft" { ... }
# resource "oci_core_subnet" "minecraft" { ... }
# resource "oci_core_security_list" "minecraft" { ... }
# resource "oci_dns_zone" "minecraft" { ... }
# resource "oci_dns_rrset" "minecraft_a" { ... }
#
# Recommended setup:
#   - Region: eu-amsterdam-1 or eu-frankfurt-1
#   - Shape: VM.Standard.A1.Flex (ARM – part of Always Free tier!)
#     - 4 OCPUs + 24GB RAM = free
#     - ARM: needs compatible JVM (Temurin has ARM builds)
#   - Block Volume: 50GB (200GB free tier total)
#   - DNS: OCI DNS or external
#   - Estimated cost: FREE (within Always Free tier limits)
#
# Note: ARM compatibility varies by modpack. Forge modpacks
# may have issues with native libraries on aarch64. Fabric
# and Vanilla work well on ARM.
