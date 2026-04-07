# Minecraft Server – IaC + Automation

Fully automated, modpack-agnostic Minecraft server on **your choice of cloud provider**. One command to set up. Push to deploy. Backups run themselves. **The VM is ephemeral** — start creates it, stop destroys it. You only pay for storage when not playing.

## Supported Providers

| Provider | Region | Running Cost | Parked Cost | Status |
|----------|--------|-------------|-------------|--------|
| **Vultr** | Stockholm (~800km from Riga) | ~€55-65/mo | ~€5/mo | **Ready** |
| **Hetzner** | Helsinki (~350km from Riga) | ~€48/mo | ~€3/mo | **Ready** |
| AWS | Stockholm | ~€55-70/mo (Spot) | ~€9/mo | Boilerplate |
| OCI | Amsterdam | **Free** (ARM free tier) | **Free** | Boilerplate |

## Architecture

```
GitHub (this repo)
    │
    ├── terraform/
    │   ├── modules/hetzner/   → Hetzner-specific resources
    │   ├── modules/vultr/     → Vultr-specific resources
    │   ├── modules/aws/       → AWS boilerplate (TODO)
    │   ├── modules/oci/       → OCI boilerplate (TODO)
    │   └── main.tf            → Provider selection + unified interface
    ├── ansible/               → OS config, Java, modpack install, backups, monitoring
    ├── config/modpacks.yml    → Modpack catalog (swap modpacks by changing one value)
    ├── .github/workflows/     → CI/CD pipelines for everything
    ├── scripts/               → Bootstrap, inventory, RCON helper
    └── Makefile               → Local shortcuts for all operations

Cloud (selected provider)
    ├── PERSISTENT (always exists, ~€3-5/mo):
    │   ├── Block storage volume → world data survives VM destruction
    │   ├── SSH key + Firewall rules
    │   ├── DNS zone + records (auto-updated)
    │   └── S3-compatible storage → encrypted restic backups
    │
    └── EPHEMERAL (created on start, destroyed on stop):
        └── VM (size depends on provider + plan)
            ├── systemd service → auto-restart on crash, graceful RCON shutdown
            ├── restic cron     → encrypted backups every 3h, verified weekly
            └── Promtail        → logs shipped to Grafana Cloud

    make start  →  VM created + Ansible deploys + Minecraft runs  (~3 min)
    make stop   →  Backup + graceful RCON stop + VM destroyed     (~2 min)
```

## Cost

Costs vary by provider. The ephemeral VM pattern means you only pay for compute while playing.

| State | Vultr | Hetzner | AWS (Spot) | OCI (Free Tier) |
|-------|-------|---------|------------|-----------------|
| **Playing** | ~€55-65/mo | ~€48/mo | ~€55-70/mo | **€0** |
| **Parked** | ~€5/mo | ~€3/mo | ~€9/mo | **€0** |
| **Destroyed** | ~€1/mo¹ | ~€1/mo¹ | ~€1/mo¹ | ~€1/mo¹ |

¹ S3 backup storage only

## Quick Start

### Prerequisites
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/) >= 2.15
- An account with **Vultr** ([sign up](https://my.vultr.com/)) or **Hetzner** ([sign up](https://accounts.hetzner.com/signUp)) + API token
- `jq`, `ssh-keygen` (usually pre-installed)

### One-Command Setup

```bash
git clone <this-repo> && cd mc_server
make bootstrap
```

The bootstrap script will:
1. Check prerequisites
2. Generate an SSH key pair
3. Ask for **cloud provider** (Vultr or Hetzner), API token, admin IP, RCON password, modpack, **domain (optional)**
4. Provision infrastructure with Terraform
5. Deploy & configure the server with Ansible
6. Start the Minecraft server
7. If domain configured: auto-update DNS A record

Total time: ~10 minutes.

### Manual Setup

```bash
# 1. Provision infrastructure
cd terraform
cp terraform.tfvars.example terraform.tfvars  # Edit with your values
terraform init && terraform apply

# 2. Generate Ansible inventory
cd ..
bash scripts/generate-inventory.sh

# 3. Deploy server
cd ansible
ansible-playbook site.yml -i inventory/hosts.ini \
  --extra-vars "modpack_name=prominence-2-rpg rcon_password=YOUR_PASSWORD"
```

## Modpack Management

Modpacks are defined in [`config/modpacks.yml`](config/modpacks.yml). The active modpack is set in `ansible/group_vars/all.yml` → `modpack_name`.

### Available Modpacks (pre-configured)
| Key | Name | Loader | MC Version | Memory |
|-----|------|--------|------------|--------|
| `prominence-2-rpg` | Prominence II RPG: Hasturian Era | Forge | 1.20.1 | 12-24G |
| `better-mc-forge` | Better Minecraft [FORGE] | Forge | 1.20.1 | 8-16G |
| `all-the-mods-9` | All the Mods 9 | Forge | 1.20.1 | 12-28G |
| `rlcraft` | RLCraft | Forge | 1.12.2 | 6-10G |
| `cobblemon-fabric` | Cobblemon (Fabric) | Fabric | 1.20.1 | 6-12G |
| `vanilla-plus` | Vanilla+ (Performance) | Fabric | 1.20.4 | 4-8G |

### Switching Modpacks

**Via GitHub Actions:**
Run the "Change Modpack" workflow → select modpack → optionally wipe world → deploy.

**Via CLI:**
```bash
make deploy-modpack MODPACK=better-mc-forge
```

**Adding a new modpack:**
1. Add entry to `config/modpacks.yml` (copy the template at the bottom)
2. Set `download_url` to the server pack ZIP from CurseForge/Modrinth
3. Deploy: `make deploy-modpack MODPACK=your-new-pack`

## Backup System

Backups are the most critical part of this setup. World data is irreplaceable.

### How It Works
- **Tool:** [restic](https://restic.net/) → Cloudflare R2 (S3-compatible, zero egress fees, ~$0.015/GB/mo)
- **Schedule:** Every 3 hours (configurable)
- **Verification:** Weekly integrity check + content validation
- **Encryption:** All backups encrypted with restic password
- **Retention:** 8 three-hourly, 7 daily, 4 weekly, 6 monthly
- **Cost:** ~$0.15-0.45/mo for 10-30GB (first 10GB free)

### Backup Flow
```
1. RCON → "say backup starting..."     (warn players)
2. RCON → "save-off"                    (disable async writes)
3. RCON → "save-all flush"             (force save to disk)
4. wait 5s                              (ensure flush completes)
5. restic backup world/ + configs       (deduplicated, encrypted, compressed)
6. RCON → "save-on"                     (re-enable writes)
7. restic forget --prune                (apply retention policy)
8. RCON → "say backup complete!"        (notify players)
```

### Backup Commands
```bash
make backup              # Manual backup now
make list-backups        # List all snapshots
make restore             # Interactive restore (picks latest or by ID)
make verify-backup       # Check backup integrity
```

### Restore
```bash
# List available snapshots
make list-backups

# Restore latest
make restore

# Restore specific snapshot (SSH in, then:)
/opt/minecraft/backups/scripts/restore.sh <snapshot_id>

# Preview what would be restored
/opt/minecraft/backups/scripts/restore.sh --dry-run <snapshot_id>
```

The restore script automatically:
1. Stops the server
2. Backs up current state (safety net)
3. Restores from chosen snapshot
4. Restarts the server

## GitHub Actions Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **Provision** | Manual dispatch | First-time setup: persistent resources + VM |
| **Deploy** | Push to `main` OR manual | Install/update server, modpack, config |
| **Server Control** | Manual dispatch | **Start** (create VM) / **Stop** (destroy VM) / Restart / Status |
| **Backup & Restore** | Manual dispatch | On-demand backup, list snapshots, restore |
| **Change Modpack** | Manual dispatch | Switch modpacks with optional world wipe |
| **Scheduled** | Cron (every 3h + weekly) | Automated backups + verification (skips if VM parked) |
| **Destroy Everything** | Manual (requires "DESTROY-ALL") | Delete VM + volume + all data |

### Required GitHub Secrets & Variables

**Repository Variables** (Settings → Variables → Actions):

| Variable | Description |
|----------|-------------|
| `CLOUD_PROVIDER` | `vultr` or `hetzner` (default: `vultr`) |

**Repository Secrets** (Settings → Secrets → Actions):

| Secret | Description |
|--------|-------------|
| `TF_API_TOKEN` | Terraform Cloud API token ([create here](https://app.terraform.io/app/settings/tokens)) |
| `VULTR_API_KEY` | Vultr API key *(if using Vultr)* |
| `HETZNER_API_TOKEN` | Hetzner Cloud API token *(if using Hetzner)* |
| `HETZNER_DNS_TOKEN` | *(optional)* Hetzner DNS token (omit if same account) |
| `SSH_PRIVATE_KEY` | SSH private key (from `~/.ssh/mc_server`) |
| `SSH_PUBLIC_KEY` | SSH public key |
| `ADMIN_IP` | Your IP for firewall rules |
| `RCON_PASSWORD` | RCON password |
| `BACKUP_S3_ENDPOINT` | R2 endpoint: `https://<ACCOUNT_ID>.r2.cloudflarestorage.com` |
| `BACKUP_S3_BUCKET` | R2 bucket name |
| `BACKUP_S3_ACCESS_KEY` | R2 API token Access Key ID |
| `BACKUP_S3_SECRET_KEY` | R2 API token Secret Access Key |
| `RESTIC_PASSWORD` | Encryption password for backups |
| `DOMAIN_NAME` | *(optional)* Domain name, e.g. `example.com` |
| `DOMAIN_SUBDOMAIN` | *(optional)* Subdomain, e.g. `mc` for `mc.example.com` |
| `GRAFANA_CLOUD_URL` | *(optional)* Loki push URL |
| `GRAFANA_CLOUD_USER` | *(optional)* Grafana Cloud user |
| `GRAFANA_CLOUD_API_KEY` | *(optional)* Grafana Cloud API key |

## Daily Operations

```bash
make start        # Create VM + deploy + start server (~3 min)
make stop         # Backup + destroy VM, saves ~€45/mo (~2 min)
make status       # Is it running? Who's online?
make logs         # Live log tail
make players      # Player list
make rcon CMD="difficulty normal"   # Run any command
make ssh          # Full SSH access
make backup       # Manual backup
```

> **Note:** `make start` creates a new VM each time. If you configured a domain, the DNS A record updates automatically and players always connect to the same address (e.g., `mc.example.com`). Without a domain, the IP changes each session.

## DNS Setup (Optional)

Gives players a stable address like `mc.example.com` — no need to update the IP after every start/stop. Works with all supported providers.

### How it works
1. Terraform creates a DNS zone with your chosen provider (free on both Hetzner and Vultr)
2. On every `make start`, the A record is updated to the new VM IP
3. On `make stop`, the A record is removed (VM doesn't exist)
4. An SRV record lets players connect without typing `:25565`

### Setup
1. **Register a domain** with any registrar (~€10-15/year)
2. **Point nameservers** to your cloud provider:

   **Vultr:**
   ```
   ns1.vultr.com
   ns2.vultr.com
   ```

   **Hetzner:**
   ```
   hydrogen.ns.hetzner.com
   oxygen.ns.hetzner.com
   helium.ns.hetzner.de
   ```

3. **Set variables** in `terraform/terraform.tfvars`:
   ```hcl
   domain_name      = "example.com"
   domain_subdomain = "mc"           # → mc.example.com
   ```
4. Run `make start` — DNS is configured automatically

**Cost:** Domain registration ~€10-15/year (~€1/mo). DNS hosting is **free** on both Vultr and Hetzner.

## Backup Storage Setup (Cloudflare R2)

Backups use [Cloudflare R2](https://www.cloudflare.com/products/r2/) — S3-compatible object storage with **zero egress fees** and 10GB free tier.

### Why R2?
- **~$0.015/GB/mo** (30GB of MC backups = ~$0.30/mo)
- **Zero egress** — restoring a 30GB backup costs $0 (AWS S3 would cost ~$2.70)
- S3-compatible API — restic works without changes
- 10GB free tier — small worlds are free forever

### Setup
1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/) → **R2** (free account works)
2. **Create a bucket** → name it `mc-server-backups` (or whatever you like)
3. **Create an API token:** R2 → Manage R2 API Tokens → Create API token
   - Permissions: **Object Read & Write**
   - Scope: your bucket
4. Note your **Account ID** (shown in the R2 dashboard URL)
5. Set these values:
   ```
   Endpoint:   https://<ACCOUNT_ID>.r2.cloudflarestorage.com
   Bucket:     mc-server-backups
   Access Key: (from API token)
   Secret Key: (from API token)
   ```

The bootstrap script will prompt for these values. For GitHub Actions, add them as secrets (`BACKUP_S3_ENDPOINT`, `BACKUP_S3_BUCKET`, `BACKUP_S3_ACCESS_KEY`, `BACKUP_S3_SECRET_KEY`).

> **Alternative backends:** Any S3-compatible storage works — AWS S3, Backblaze B2, Wasabi, etc. Just change the endpoint.

## Server Sizing

Leave `server_plan` empty to use the default for your provider. Override with a specific plan ID if needed.

### Vultr (High Performance AMD)
| Plan | vCPU | RAM | Best For | Cost/mo |
|------|------|-----|----------|---------|
| `vc2-4c-8gb` | 4 shared | 8GB | Vanilla, testing | ~€24 |
| `vhp-2c-4gb-amd` | 2 HP | 4GB | Vanilla, 1-5 players | ~€24 |
| `vhp-4c-8gb-amd` | 4 HP | 8GB | Light modpacks, ≤10 players | ~€48 |
| **`vhp-4c-12gb-amd`** | **4 HP** | **12GB** | **Most modpacks, ≤15 players (default)** | **~€64** |
| `vhp-8c-16gb-amd` | 8 HP | 16GB | Heavy modpacks, ≤20 players | ~€96 |

### Hetzner Cloud (Dedicated CPU)
| Plan | vCPU | RAM | Best For | Cost/mo |
|------|------|-----|----------|---------|
| cx22 | 2 shared | 4GB | Testing only | ~€4 |
| cx32 | 4 shared | 8GB | Vanilla, 1-3 players | ~€8 |
| ccx23 | 4 dedicated | 16GB | Light modpacks, ≤10 players | ~€22 |
| **ccx33** | **8 dedicated** | **32GB** | **Heavy modpacks, ≤20 players (default)** | **~€45** |
| ccx43 | 16 dedicated | 64GB | ATM9/large packs, 20+ players | ~€90 |

## Project Structure

```
mc_server/
├── .github/workflows/
│   ├── provision.yml         # Terraform create/update
│   ├── destroy.yml           # Terraform destroy (with confirmation)
│   ├── deploy.yml            # Ansible full deployment
│   ├── server-control.yml    # Start/stop/restart/status
│   ├── backup.yml            # Manual backup/restore/list
│   ├── change-modpack.yml    # Switch modpacks
│   └── scheduled.yml         # Cron: backups + verification
├── terraform/
│   ├── main.tf               # Provider selection + module routing
│   ├── variables.tf          # Common + provider-specific variables
│   ├── outputs.tf            # Unified outputs (provider-agnostic)
│   ├── versions.tf           # All provider declarations
│   ├── backend.tf            # State storage options
│   ├── terraform.tfvars.example
│   ├── templates/cloud-init.yml
│   └── modules/
│       ├── hetzner/          # Hetzner: VM, volume, firewall, DNS
│       ├── vultr/            # Vultr: instance, block storage, firewall, DNS
│       ├── aws/              # AWS boilerplate (TODO)
│       └── oci/              # OCI boilerplate (TODO)
├── ansible/
│   ├── site.yml              # Main playbook
│   ├── group_vars/all.yml    # Master config (single source of truth)
│   ├── roles/
│   │   ├── base/             # OS setup, swap, ulimits, security
│   │   ├── java/             # Eclipse Temurin JDK
│   │   ├── minecraft/        # Modpack-agnostic server install
│   │   ├── backup/           # Restic + S3 + RCON integration
│   │   └── monitoring/       # Node exporter + Promtail
│   └── inventory/
├── config/
│   └── modpacks.yml          # Modpack catalog (add yours here)
├── scripts/
│   ├── bootstrap.sh          # One-command setup
│   ├── generate-inventory.sh # Terraform → Ansible bridge
│   └── rcon.sh               # RCON command helper
├── Makefile                  # All operations as make targets
├── .gitignore
└── README.md
```

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Multi-provider modules** | Cloud provider is a variable, not hardcoded. Switch with one line in tfvars. Each module has the same output interface so Ansible/workflows are provider-agnostic. |
| **Ephemeral VM** | Start creates the VM, stop destroys it. You only pay for storage when not playing. Volume + backups persist. |
| **Vultr default** | Good balance of price/performance, Stockholm DC has low latency to Riga, mature Terraform provider, free DNS hosting. |
| **No Docker** | Game servers need direct disk I/O and aren't horizontally scaled. Docker adds overhead and complexity for no benefit here. |
| **systemd over tmux/screen** | Proper service management: auto-restart, journald integration, dependency ordering |
| **restic over tar/rsync** | Deduplication, encryption, S3 backend, snapshot-based, built-in retention policies |
| **Separate persistent volume** | World data survives VM destruction. `prevent_destroy` lifecycle rule protects against accidental deletion. |
| **Modpack catalog pattern** | Decouple "which modpack" from "how to deploy". Add any pack to the YAML; the Ansible role handles the rest. |
| **Aikar's JVM flags** | Industry standard for Minecraft servers. G1GC tuned for the unique allocation patterns of MC. |
| **RCON for graceful shutdown** | Prevents chunk corruption. Backup → save-all → stop → destroy VM, in that order. |
| **DNS auto-update** | A + SRV records update on every `make start`. Players use a stable address; no manual IP sharing needed. Free on Vultr and Hetzner. |

## Automation After Initial Setup

Once bootstrapped, these things happen **automatically** with zero intervention:

- **`make start`** → VM created, Ansible configures everything, Minecraft runs (~3 min)
- **`make stop`** → Backup taken, RCON graceful stop, VM destroyed (~2 min)
- **Push to `main`** → Server config/modpack redeployed (if VM is running)
- **Every 3 hours** → World backup to S3 (skipped if VM is parked)
- **Every Sunday** → Backup integrity verification
- **Server crash** → Auto-restart via systemd (up to 5 attempts, 30s backoff)
- **Every stop** → Automatic backup before VM destruction

Things that require manual action (by design):
- Initial bootstrap (`make bootstrap`)
- Starting/stopping the server (`make start` / `make stop`)
- Switching modpacks (workflow dispatch or `make deploy-modpack`)
- Restoring from backup (`make restore`)
- Changing server size (update Terraform variable)
- Full infrastructure destruction (requires typing "DESTROY-ALL")