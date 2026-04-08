#!/usr/bin/env bash
# ═══════════════════════════════════════════════
# Bootstrap Script – One-command initial setup
# ═══════════════════════════════════════════════
# Usage: ./scripts/bootstrap.sh
#
# This script:
# 1. Checks prerequisites (terraform, ansible, ssh-keygen)
# 2. Generates SSH key pair if not present
# 3. Prompts for cloud provider and required config
# 4. Writes terraform.tfvars
# 5. Runs terraform init + apply
# 6. Generates Ansible inventory from Terraform output
# 7. Runs Ansible deployment
# ═══════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SSH_KEY_PATH="${HOME}/.ssh/mc_server"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; exit 1; }
info()  { echo -e "${BLUE}[i]${NC} $*"; }

echo ""
echo "═══════════════════════════════════════════════"
echo "  Minecraft Server – Bootstrap"
echo "═══════════════════════════════════════════════"
echo ""

# ── Check prerequisites ──────────────────────
info "Checking prerequisites..."

for cmd in terraform ansible-playbook ssh-keygen jq; do
    if ! command -v "$cmd" &>/dev/null; then
        error "$cmd is not installed. Install it first."
    fi
    log "$cmd found"
done

# ── SSH Key ──────────────────────────────────
if [[ ! -f "${SSH_KEY_PATH}" ]]; then
    info "Generating SSH key pair..."
    ssh-keygen -t ed25519 -f "${SSH_KEY_PATH}" -N "" -C "mc-server"
    log "SSH key generated at ${SSH_KEY_PATH}"
else
    log "SSH key already exists at ${SSH_KEY_PATH}"
fi

SSH_PUBLIC_KEY=$(cat "${SSH_KEY_PATH}.pub")

# ── Cloud provider selection ─────────────────
echo ""
info "Choose your cloud provider:"
echo "  1) vultr   – Stockholm DC, ~€55-65/mo running (recommended)"
echo "  2) hetzner – Helsinki DC, ~€48/mo running"
echo ""
read -p "Provider [1]: " PROVIDER_CHOICE
case "${PROVIDER_CHOICE}" in
    2|hetzner) CLOUD_PROVIDER="hetzner" ;;
    *)         CLOUD_PROVIDER="vultr" ;;
esac
log "Selected: ${CLOUD_PROVIDER}"

# ── Provider-specific config ─────────────────
echo ""
info "Configuration for ${CLOUD_PROVIDER}. Leave blank to use defaults."
echo ""

HCLOUD_TOKEN=""
VULTR_API_KEY=""
DNS_TOKEN=""

if [[ "${CLOUD_PROVIDER}" == "vultr" ]]; then
    read -p "Vultr API Key: " VULTR_API_KEY
    [[ -z "${VULTR_API_KEY}" ]] && error "Vultr API key is required. Get one at https://my.vultr.com/settings/#settingsapi"
elif [[ "${CLOUD_PROVIDER}" == "hetzner" ]]; then
    read -p "Hetzner API Token: " HCLOUD_TOKEN
    [[ -z "${HCLOUD_TOKEN}" ]] && error "Hetzner API token is required"
fi

echo ""
info "Choose server size:"
echo "  1) small  – 2 vCPU / 4GB   (vanilla / testing, ~\$12-24/mo)"
echo "  2) medium – 4 vCPU / 8GB   (light modpacks, ~\$24-48/mo)"
echo "  3) large  – 4-8 vCPU / 12-32GB (most modpacks, ~\$48-72/mo)"
echo "  4) xlarge – 8+ vCPU / 16-64GB  (heavy modpacks, ~\$72-144/mo)"
echo ""
read -p "Size [3]: " SIZE_CHOICE
case "${SIZE_CHOICE}" in
    1|small)  SERVER_SIZE="small" ;;
    2|medium) SERVER_SIZE="medium" ;;
    4|xlarge) SERVER_SIZE="xlarge" ;;
    *)        SERVER_SIZE="large" ;;
esac
log "Selected size: ${SERVER_SIZE}"

read -p "Region (leave empty for default): " REGION
REGION="${REGION:-}"

read -p "Your public IP for SSH/RCON (CIDR, e.g. 1.2.3.4/32): " ADMIN_IP
[[ -z "${ADMIN_IP}" ]] && ADMIN_IP="0.0.0.0/0" && warn "No admin IP set – SSH/RCON open to all. Restrict this later!"

read -p "RCON password: " RCON_PASSWORD
[[ -z "${RCON_PASSWORD}" ]] && RCON_PASSWORD=$(openssl rand -base64 16) && warn "Generated RCON password: ${RCON_PASSWORD}"

read -p "Modpack name [prominence-2-rpg]: " MODPACK_NAME
MODPACK_NAME="${MODPACK_NAME:-prominence-2-rpg}"

# DNS (optional)
echo ""
info "DNS setup (optional – gives players a stable address like mc.example.com)"
read -p "Domain name (leave empty to skip): " DOMAIN_NAME
DOMAIN_SUBDOMAIN="mc"
if [[ -n "${DOMAIN_NAME}" ]]; then
    read -p "Subdomain [mc]: " DOMAIN_SUBDOMAIN
    DOMAIN_SUBDOMAIN="${DOMAIN_SUBDOMAIN:-mc}"
    if [[ "${CLOUD_PROVIDER}" == "hetzner" ]]; then
        read -p "Hetzner DNS API token (leave empty to use Cloud token): " DNS_TOKEN
        info "Point your domain's NS records to:"
        info "  hydrogen.ns.hetzner.com"
        info "  oxygen.ns.hetzner.com"
        info "  helium.ns.hetzner.de"
    elif [[ "${CLOUD_PROVIDER}" == "vultr" ]]; then
        info "Point your domain's NS records to:"
        info "  ns1.vultr.com"
        info "  ns2.vultr.com"
    fi
fi

# Validate modpack exists
if ! python3 -c "
import yaml
with open('${PROJECT_DIR}/config/modpacks.yml') as f:
    data = yaml.safe_load(f)
assert '${MODPACK_NAME}' in data['modpacks'], '${MODPACK_NAME} not found'
" 2>/dev/null; then
    warn "Modpack '${MODPACK_NAME}' not found in config/modpacks.yml – you may need to add it"
fi

# Backup storage (Cloudflare R2)
echo ""
info "Backup storage setup (Cloudflare R2 recommended – cheap, zero egress fees)"
info "Create a free account at https://dash.cloudflare.com → R2 → Create bucket"
info "Then create an API token: R2 → Manage R2 API Tokens → Create API token"

read -p "R2/S3 endpoint (e.g., https://<ACCOUNT_ID>.r2.cloudflarestorage.com): " BACKUP_S3_ENDPOINT
read -p "R2/S3 bucket name [mc-server-backups]: " BACKUP_S3_BUCKET
BACKUP_S3_BUCKET="${BACKUP_S3_BUCKET:-mc-server-backups}"
read -p "R2/S3 Access Key ID: " BACKUP_S3_ACCESS_KEY
read -p "R2/S3 Secret Access Key: " BACKUP_S3_SECRET_KEY
read -p "Restic encryption password (random if empty): " RESTIC_PASSWORD
[[ -z "${RESTIC_PASSWORD}" ]] && RESTIC_PASSWORD=$(openssl rand -base64 24) && warn "Generated restic password: ${RESTIC_PASSWORD}"
warn "SAVE THIS PASSWORD! Without it, backups cannot be decrypted."

# ── Write terraform.tfvars ───────────────────
info "Writing terraform/terraform.tfvars..."
cat > "${PROJECT_DIR}/terraform/terraform.tfvars" <<EOF
# Generated by bootstrap.sh on $(date -u '+%Y-%m-%d %H:%M:%S UTC')
cloud_provider   = "${CLOUD_PROVIDER}"
ssh_public_key   = "${SSH_PUBLIC_KEY}"
project_name     = "mc-server"
server_size      = "${SERVER_SIZE}"
region           = "${REGION}"
volume_size_gb   = 50
admin_ips        = ["${ADMIN_IP}"]
domain_name      = "${DOMAIN_NAME}"
domain_subdomain = "${DOMAIN_SUBDOMAIN}"

# Provider tokens
vultr_api_key     = "${VULTR_API_KEY}"
hcloud_token      = "${HCLOUD_TOKEN}"
hetzner_dns_token = "${DNS_TOKEN:-}"

# Backup storage (Cloudflare R2)
backup_s3_endpoint = "${BACKUP_S3_ENDPOINT}"
backup_s3_bucket   = "${BACKUP_S3_BUCKET}"
EOF
log "terraform.tfvars written"

# ── Terraform ────────────────────────────────
info "Initializing Terraform..."
cd "${PROJECT_DIR}/terraform"
terraform init

info "Planning infrastructure..."
terraform plan -out=tfplan -var "server_enabled=true"

echo ""
read -p "Apply infrastructure? (y/N): " APPLY_CONFIRM
if [[ "${APPLY_CONFIRM}" =~ ^[Yy]$ ]]; then
    terraform apply tfplan
    SERVER_IP=$(terraform output -raw server_ip)
    log "Server provisioned at ${SERVER_IP}"

    # Save IP for other scripts/workflows
    echo "${SERVER_IP}" > "${PROJECT_DIR}/server_ip.txt"
else
    warn "Skipping terraform apply. Run 'make start' when ready."
    exit 0
fi

# ── Wait for server to be ready ──────────────
info "Waiting for server to be reachable..."
for i in $(seq 1 30); do
    if ssh -i "${SSH_KEY_PATH}" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@${SERVER_IP}" "echo ok" &>/dev/null; then
        log "Server is reachable"
        break
    fi
    echo -n "."
    sleep 10
done

# Wait for cloud-init to finish
info "Waiting for cloud-init..."
ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "root@${SERVER_IP}" "cloud-init status --wait" 2>/dev/null || true
log "Cloud-init complete"

# ── Generate Ansible inventory ───────────────
"${SCRIPT_DIR}/generate-inventory.sh"

# ── Run Ansible ──────────────────────────────
info "Deploying server with Ansible..."
cd "${PROJECT_DIR}/ansible"
ansible-playbook site.yml \
    -i inventory/hosts.ini \
    --extra-vars "modpack_name=${MODPACK_NAME} rcon_password=${RCON_PASSWORD} backup_s3_endpoint=${BACKUP_S3_ENDPOINT} backup_s3_bucket=${BACKUP_S3_BUCKET} backup_s3_access_key=${BACKUP_S3_ACCESS_KEY} backup_s3_secret_key=${BACKUP_S3_SECRET_KEY} restic_password=${RESTIC_PASSWORD}" \
    -v

RESOLVED_PLAN=$(cd "${PROJECT_DIR}/terraform" && terraform output -raw server_plan 2>/dev/null || echo "${SERVER_PLAN}")
RESOLVED_REGION=$(cd "${PROJECT_DIR}/terraform" && terraform output -raw region 2>/dev/null || echo "${REGION}")

echo ""
echo "═══════════════════════════════════════════════"
log "Setup complete!"
echo ""
echo "  Provider:           ${CLOUD_PROVIDER}"
echo "  Server IP:          ${SERVER_IP}"
echo "  Plan:               ${RESOLVED_PLAN}"
echo "  Region:             ${RESOLVED_REGION}"
if [[ -n "${DOMAIN_NAME}" ]]; then
    MC_ADDRESS="${DOMAIN_SUBDOMAIN}.${DOMAIN_NAME}"
    [[ "${DOMAIN_SUBDOMAIN}" == "@" ]] && MC_ADDRESS="${DOMAIN_NAME}"
    echo "  Minecraft address:  ${MC_ADDRESS}"
    echo "  (players connect with just the domain – no port needed)"
else
    echo "  Minecraft address:  ${SERVER_IP}:25565"
fi
echo "  SSH:                ssh -i ${SSH_KEY_PATH} root@${SERVER_IP}"
echo "  RCON password:      ${RCON_PASSWORD}"
echo "  Modpack:            ${MODPACK_NAME}"
echo ""
echo "  The server may take a few minutes to fully start."
echo "  Check status:  make status"
echo "  View logs:     make logs"
echo ""
echo "  IMPORTANT: Start/stop now creates/destroys the VM."
echo "  'make stop'  = backup + destroy VM"
echo "  'make start' = create VM + deploy"
echo "═══════════════════════════════════════════════"
