#!/usr/bin/env bash
# Generate Ansible inventory from Terraform output
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SSH_KEY_PATH="${HOME}/.ssh/mc_server"

cd "${PROJECT_DIR}/terraform"

SERVER_IP=$(terraform output -raw server_ip 2>/dev/null || cat "${PROJECT_DIR}/server_ip.txt" 2>/dev/null || echo "")

if [[ -z "${SERVER_IP}" ]]; then
    echo "ERROR: Cannot determine server IP. Run terraform apply first."
    exit 1
fi

cat > "${PROJECT_DIR}/ansible/inventory/hosts.ini" <<EOF
[minecraft]
${SERVER_IP} ansible_user=root ansible_ssh_private_key_file=${SSH_KEY_PATH}
EOF

echo "Inventory written: ${SERVER_IP}"
