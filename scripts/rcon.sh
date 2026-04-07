#!/usr/bin/env bash
# Quick RCON command helper
# Usage: ./scripts/rcon.sh "say Hello"
#        ./scripts/rcon.sh list
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SSH_KEY_PATH="${HOME}/.ssh/mc_server"
SERVER_IP=$(cat "${PROJECT_DIR}/server_ip.txt" 2>/dev/null || echo "")

if [[ -z "${SERVER_IP}" ]]; then
    echo "ERROR: No server IP. Run bootstrap or provision first."
    exit 1
fi

COMMAND="${*:-list}"

ssh -i "${SSH_KEY_PATH}" "root@${SERVER_IP}" \
    "mcrcon -H 127.0.0.1 -P 25575 -p \"\$(grep rcon.password /opt/minecraft/server/server.properties | cut -d= -f2)\" '${COMMAND}'"
