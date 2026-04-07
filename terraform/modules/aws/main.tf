# ──────────────────────────────────────────────
# AWS Module – BOILERPLATE
# ──────────────────────────────────────────────
# TODO: Complete implementation when AWS support is needed.
# This provides the module interface so Terraform validates.
# ──────────────────────────────────────────────

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# ── Placeholder resources ────────────────────
# Uncomment and implement when ready:
#
# resource "aws_key_pair" "minecraft" { ... }
# resource "aws_instance" "minecraft" { ... }          # or aws_spot_instance_request
# resource "aws_ebs_volume" "minecraft_data" { ... }
# resource "aws_volume_attachment" "minecraft_data" { ... }
# resource "aws_security_group" "minecraft" { ... }
# resource "aws_route53_zone" "minecraft" { ... }
# resource "aws_route53_record" "minecraft_a" { ... }
#
# Recommended setup:
#   - Region: eu-north-1 (Stockholm, closest to Riga)
#   - Instance: c6i.2xlarge (8 vCPU, 16GB) or Spot
#   - EBS: gp3 50GB persistent volume
#   - DNS: Route 53 (~$0.50/mo)
#   - Estimated cost: ~$155/mo on-demand, ~$55/mo Spot
