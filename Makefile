# ═══════════════════════════════════════════════
# Minecraft Server – Makefile
# ═══════════════════════════════════════════════
# Multi-provider: Hetzner, Vultr (AWS, OCI planned).
# The server VM is EPHEMERAL. Start creates it, stop destroys it.
# World data lives on a persistent volume and in S3 backups.
#
# Usage:
#   make bootstrap    – Full initial setup (interactive)
#   make start        – Create VM + deploy + start server
#   make stop         – Backup + destroy VM (saves money)
#   make restart      – Stop + start (new VM, same world)
#   make deploy       – Re-deploy config to running server
#   make status       – Check if server is running
#   make logs         – Tail server logs
#   make backup       – Take manual backup
#   make restore      – Restore from backup (interactive)
#   make rcon CMD="say hello" – Run RCON command
#   make ssh          – SSH into server
#   make destroy-all  – Tear down EVERYTHING (DANGEROUS)

SHELL := /bin/bash
.DEFAULT_GOAL := help

SSH_KEY := ~/.ssh/mc_server
SERVER_IP := $(shell cat server_ip.txt 2>/dev/null | tr -d '[:space:]')
SSH := ssh -i $(SSH_KEY) root@$(SERVER_IP)
PROVIDER := $(shell cd terraform && terraform output -raw cloud_provider 2>/dev/null || echo "unknown")

# ── Setup ────────────────────────────────────
.PHONY: bootstrap
bootstrap: ## Full initial setup (interactive)
	@chmod +x scripts/*.sh
	@bash scripts/bootstrap.sh

.PHONY: provision
provision: ## First-time: create persistent resources + VM
	@cd terraform && terraform init && terraform apply -var "server_enabled=true"
	@bash scripts/generate-inventory.sh

.PHONY: plan
plan: ## Preview infrastructure changes
	@cd terraform && terraform init && terraform plan -var "server_enabled=true"

.PHONY: deploy
deploy: ## Re-deploy config to running server
	@if [ -z "$(SERVER_IP)" ]; then echo "No server running. Use 'make start' first."; exit 1; fi
	@bash scripts/generate-inventory.sh
	@cd ansible && ansible-playbook site.yml -i inventory/hosts.ini -v

.PHONY: deploy-modpack
deploy-modpack: ## Deploy specific modpack: make deploy-modpack MODPACK=prominence-2-rpg
	@if [ -z "$(SERVER_IP)" ]; then echo "No server running. Use 'make start' first."; exit 1; fi
	@bash scripts/generate-inventory.sh
	@cd ansible && ansible-playbook site.yml -i inventory/hosts.ini \
		--extra-vars "modpack_name=$(MODPACK)" -v

# ── Server Control (creates/destroys VM) ─────
.PHONY: start
start: ## Create VM + deploy + start server (~3 min)
	@echo "═══ Starting server (creating VM)... ═══"
	@cd terraform && terraform init && terraform apply -var "server_enabled=true" -auto-approve
	@cd terraform && terraform output -raw server_ip > ../server_ip.txt
	@echo "VM created at $$(cat server_ip.txt). Waiting for SSH..."
	@for i in $$(seq 1 30); do \
		if ssh -i $(SSH_KEY) -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$$(cat server_ip.txt) "echo ok" 2>/dev/null; then break; fi; \
		sleep 10; \
	done
	@ssh -i $(SSH_KEY) -o StrictHostKeyChecking=no root@$$(cat server_ip.txt) "cloud-init status --wait" 2>/dev/null || true
	@bash scripts/generate-inventory.sh
	@cd ansible && ansible-playbook site.yml -i inventory/hosts.ini -v
	@echo ""
	@echo "═══ Server ready! ═══"
	@echo "  Provider: $$(cd terraform && terraform output -raw cloud_provider)"
	@echo "  IP:       $$(cat server_ip.txt)"
	@echo "  Plan:     $$(cd terraform && terraform output -raw server_plan)"
	@echo "  Address:  $$(cd terraform && terraform output -raw minecraft_address)"
	@echo "  SSH:      ssh -i $(SSH_KEY) root@$$(cat server_ip.txt)"

.PHONY: stop
stop: ## Backup + graceful stop + destroy VM (saves ~€45/mo)
	@if [ -z "$(SERVER_IP)" ]; then echo "Server already stopped."; exit 0; fi
	@echo "═══ Stopping server (will destroy VM)... ═══"
	@echo "Taking backup before shutdown..."
	@$(SSH) "sudo -u minecraft /opt/minecraft/backups/scripts/backup.sh" 2>/dev/null || echo "Warning: backup may have failed"
	@echo "Graceful Minecraft shutdown..."
	@$(SSH) "mcrcon -H 127.0.0.1 -P 25575 -p \"\$$(grep rcon.password /opt/minecraft/server/server.properties | cut -d= -f2)\" 'say §c[Server] Shutting down. See you next time!' && sleep 10 && mcrcon -H 127.0.0.1 -P 25575 -p \"\$$(grep rcon.password /opt/minecraft/server/server.properties | cut -d= -f2)\" 'save-all' && sleep 5 && mcrcon -H 127.0.0.1 -P 25575 -p \"\$$(grep rcon.password /opt/minecraft/server/server.properties | cut -d= -f2)\" 'stop'" 2>/dev/null || true
	@sleep 10
	@echo "Destroying VM..."
	@cd terraform && terraform apply -var "server_enabled=false" -auto-approve
	@echo "" > server_ip.txt
	@echo ""
	@echo "═══ Server stopped. VM destroyed. ═══"
	@echo "  Volume + backups preserved."
	@echo "  Run 'make start' to play again."

.PHONY: restart
restart: ## Stop + Start (new VM, same world data)
	@$(MAKE) stop
	@$(MAKE) start

.PHONY: status
status: ## Check if server VM exists + Minecraft status
	@echo "═══ Server Status ═══"
	@echo "  Provider: $(PROVIDER)"
	@if [ -z "$(SERVER_IP)" ]; then \
		echo "  VM: STOPPED (no server_ip.txt)"; \
		echo "  Cost: ~€3/mo (volume + backups only)"; \
		echo "  Run 'make start' to create VM and play."; \
	else \
		echo "  VM: RUNNING at $(SERVER_IP)"; \
		echo "  Address: $$(cd terraform && terraform output -raw minecraft_address 2>/dev/null || echo '$(SERVER_IP):25565')"; \
		$(SSH) "systemctl status minecraft --no-pager 2>/dev/null || echo 'Service not found'; echo '---'; mcrcon -H 127.0.0.1 -P 25575 -p \"\$$(grep rcon.password /opt/minecraft/server/server.properties | cut -d= -f2)\" 'list' 2>/dev/null || echo 'RCON unavailable'" 2>/dev/null || echo "  SSH connection failed"; \
	fi

.PHONY: logs
logs: ## Tail server logs (live)
	@if [ -z "$(SERVER_IP)" ]; then echo "Server not running."; exit 1; fi
	@$(SSH) "tail -f /opt/minecraft/logs/server.log"

.PHONY: logs-100
logs-100: ## Show last 100 lines of server log
	@if [ -z "$(SERVER_IP)" ]; then echo "Server not running."; exit 1; fi
	@$(SSH) "tail -100 /opt/minecraft/logs/server.log"

# ── Backup ───────────────────────────────────
.PHONY: backup
backup: ## Take a manual backup now
	@if [ -z "$(SERVER_IP)" ]; then echo "Server not running. Nothing to backup."; exit 1; fi
	@echo "Starting backup..."
	@$(SSH) "sudo -u minecraft /opt/minecraft/backups/scripts/backup.sh"

.PHONY: list-backups
list-backups: ## List available backup snapshots
	@if [ -z "$(SERVER_IP)" ]; then echo "Server not running. Use GitHub Actions to list backups."; exit 1; fi
	@$(SSH) "sudo -u minecraft bash -c 'source /opt/minecraft/backups/.restic-env && restic snapshots'"

.PHONY: restore
restore: ## Restore from backup (interactive)
	@if [ -z "$(SERVER_IP)" ]; then echo "Server not running. Start it first: make start"; exit 1; fi
	@$(SSH) "sudo -u minecraft /opt/minecraft/backups/scripts/restore.sh"

.PHONY: verify-backup
verify-backup: ## Verify backup integrity
	@if [ -z "$(SERVER_IP)" ]; then echo "Server not running."; exit 1; fi
	@$(SSH) "sudo -u minecraft /opt/minecraft/backups/scripts/verify-backup.sh"

# ── RCON ─────────────────────────────────────
.PHONY: rcon
rcon: ## Run RCON command: make rcon CMD="say hello"
	@if [ -z "$(SERVER_IP)" ]; then echo "Server not running."; exit 1; fi
	@$(SSH) "mcrcon -H 127.0.0.1 -P 25575 -p \"\$$(grep rcon.password /opt/minecraft/server/server.properties | cut -d= -f2)\" '$(CMD)'"

.PHONY: players
players: ## List online players
	@if [ -z "$(SERVER_IP)" ]; then echo "Server not running."; exit 1; fi
	@$(SSH) "mcrcon -H 127.0.0.1 -P 25575 -p \"\$$(grep rcon.password /opt/minecraft/server/server.properties | cut -d= -f2)\" 'list'"

# ── Access ───────────────────────────────────
.PHONY: ssh
ssh: ## SSH into the server
	@if [ -z "$(SERVER_IP)" ]; then echo "Server not running."; exit 1; fi
	@$(SSH)

.PHONY: ip
ip: ## Show server IP + domain + status
	@if [ -z "$(SERVER_IP)" ]; then \
		echo "Server: STOPPED (VM destroyed, volume preserved)"; \
	else \
		echo "Server: RUNNING"; \
		echo "IP: $(SERVER_IP)"; \
		echo "Address: $$(cd terraform && terraform output -raw minecraft_address 2>/dev/null || echo '$(SERVER_IP):25565')"; \
		echo "Domain: $$(cd terraform && terraform output -raw domain 2>/dev/null || echo 'none')"; \
	fi

# ── Cleanup ──────────────────────────────────
.PHONY: destroy-all
destroy-all: ## DESTROY everything including volume (requires confirmation)
	@echo "⚠️  This will DESTROY the server, volume, and ALL world data!"
	@echo "   Backups in S3 will be preserved."
	@read -p "Type 'DESTROY-ALL' to confirm: " confirm; \
	if [ "$$confirm" = "DESTROY-ALL" ]; then \
		$(MAKE) backup 2>/dev/null || true; \
		cd terraform && find modules/ -name '*.tf' -exec sed -i.bak 's/prevent_destroy = true/prevent_destroy = false/' {} + && \
		terraform destroy && \
		find modules/ -name '*.tf.bak' -exec sh -c 'mv "$$1" "$${1%.bak}"' _ {} \; ; \
		echo "" > server_ip.txt; \
	else \
		echo "Cancelled."; \
	fi

# ── Help ─────────────────────────────────────
.PHONY: help
help: ## Show this help
	@echo "═══════════════════════════════════════════════"
	@echo "  Minecraft Server Management"
	@echo "═══════════════════════════════════════════════"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Server: $(SERVER_IP)"
