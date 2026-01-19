#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/core/questionnaires.sh
# Created: 2026-01-18
# Updated: 2026-01-19
# Description: Collect and persist configuration using interactive questionnaires.
# Usage:
#   scripts/core/questionnaires.sh
# Developer notes:
#   - All answers are stored in ~/.config/homelab_2026_2/state.env.
#   - Avoid storing sensitive values here. Use Vaultwarden + SOPS for secrets.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"
source "${REPO_ROOT}/lib/run.sh"
source "${REPO_ROOT}/lib/state.sh"
source "${REPO_ROOT}/lib/ui.sh"

run_init "questionnaires"
state_init
ui_ensure_ui_deps

prompt_proxmox() {
  local host user port realm node
  host="$(state_get proxmox_host "192.168.88.250")"
  user="$(state_get proxmox_ssh_user "root")"
  port="$(state_get proxmox_ssh_port "22")"
  realm="$(state_get pve_realm "pve")"
  node="$(state_get proxmox_node "pve01")"

  host="$(ui_input "Proxmox" "Proxmox host (IP or DNS)" "$host")"
  user="$(ui_input "Proxmox" "SSH user (typically root)" "$user")"
  port="$(ui_input "Proxmox" "SSH port" "$port")"
  realm="$(ui_input "Proxmox" "Proxmox realm" "$realm")"
  node="$(ui_input "Proxmox" "Proxmox node name" "$node")"

  state_set proxmox_host "$host"
  state_set proxmox_ssh_user "$user"
  state_set proxmox_ssh_port "$port"
  state_set pve_realm "$realm"
  state_set proxmox_node "$node"

  ok "Saved Proxmox connection settings."
}

prompt_mikrotik() {
  local host user port key_path
  local retention
  host="$(state_get mikrotik_host "192.168.88.1")"
  user="$(state_get mikrotik_ssh_user "admin")"
  port="$(state_get mikrotik_ssh_port "22")"
  key_path="$(state_get mikrotik_ssh_key_path "${HOME}/.ssh/id_ed25519")"
  retention="$(state_get mikrotik_backup_retention_count "30")"

  host="$(ui_input "MikroTik" "MikroTik host (RouterOS)" "$host")"
  user="$(ui_input "MikroTik" "SSH user" "$user")"
  port="$(ui_input "MikroTik" "SSH port" "$port")"
  key_path="$(ui_input "MikroTik" "SSH key path (recommended)" "$key_path")"
  retention="$(ui_input "MikroTik" "Backup retention (keep last N sets, 0 disables pruning)" "$retention")"

  state_set mikrotik_host "$host"
  state_set mikrotik_ssh_user "$user"
  state_set mikrotik_ssh_port "$port"
  state_set mikrotik_ssh_key_path "$key_path"
  state_set mikrotik_backup_retention_count "$retention"

  ok "Saved MikroTik connection settings."
}

prompt_alerting() {
  local webhook smtp_to smtp_from throttle_seconds throttle_key_mode schema_version
  webhook="$(state_get alert_webhook_url \"\")"
  smtp_to="$(state_get alert_smtp_to \"\")"
  smtp_from="$(state_get alert_smtp_from \"\")"
  throttle_seconds="$(state_get alert_throttle_seconds \"900\")"
  throttle_key_mode="$(state_get alert_throttle_key_mode \"component_severity\")"
  schema_version="$(state_get alert_schema_version \"1.0\")"

  webhook="$(ui_input \"Alerting\" \"Optional webhook URL for alerts (leave blank to disable)\" \"$webhook\")"
  smtp_to="$(ui_input \"Alerting\" \"Optional SMTP 'To' address (leave blank to disable email alerts)\" \"$smtp_to\")"
  smtp_from="$(ui_input \"Alerting\" \"Optional SMTP 'From' address\" \"$smtp_from\")"

  throttle_seconds="$(ui_input \"Alerting\" \"Throttle window in seconds for webhook/SMTP (0 disables throttling)\" \"$throttle_seconds\")"
  ui_menu \"Alerting\" \"Throttling key (controls what counts as the same alert)\" throttle_key_mode \
    component \"Component only\" \
    component_severity \"Component + severity\"
  schema_version="$(ui_input \"Alerting\" \"Alert payload schema version (advanced)\" \"$schema_version\")"

  state_set alert_webhook_url \"$webhook\"
  state_set alert_smtp_to \"$smtp_to\"
  state_set alert_smtp_from \"$smtp_from\"
  state_set alert_throttle_seconds \"$throttle_seconds\"
  state_set alert_throttle_key_mode \"$throttle_key_mode\"
  state_set alert_schema_version \"$schema_version\"

  ok \"Saved alerting settings.\"
}

prompt_dns_provider() {
  local provider
  provider="$(state_get dns_provider "bind9")"

  ui_menu "DNS" "Choose your DNS stack (you can change anytime)" provider \
    bind9 "🟣 BIND9 (classic, reliable)" \
    adguard "🛡️ AdGuard Home (DNS + filtering)" \
    coredns "☸️ CoreDNS (Kubernetes aligned)" \
    technitium "🧠 Technitium (feature-rich, UI-driven)"

  state_set dns_provider "$provider"
  ok "Saved DNS provider: ${provider}"
}

prompt_dhcp_mode() {
  local mode
  mode="$(state_get dhcp_mode "mikrotik")"

  ui_menu "DHCP" "Where should DHCP run?" mode \
    mikrotik "📡 MikroTik (recommended starting point)" \
    proxmox "🖥️ Proxmox (dedicated DHCP service)"

  state_set dhcp_mode "$mode"
  ok "Saved DHCP mode: ${mode}"
}

prompt_network() {
  local cidr gateway bridge domain
  cidr="$(state_get lan_cidr "192.168.88.0/24")"
  gateway="$(state_get lan_gateway "192.168.88.1")"
  bridge="$(state_get proxmox_bridge "vmbr0")"
  domain="$(state_get lan_domain "home.arpa")"

  cidr="$(ui_input "Network" "LAN CIDR" "$cidr")"
  gateway="$(ui_input "Network" "Default gateway (MikroTik)" "$gateway")"
  bridge="$(ui_input "Network" "Proxmox bridge" "$bridge")"
  domain="$(ui_input "Network" "Local DNS search domain" "$domain")"

  state_set lan_cidr "$cidr"
  state_set lan_gateway "$gateway"
  state_set proxmox_bridge "$bridge"
  state_set lan_domain "$domain"

  ok "Saved network settings."
}

prompt_storage() {
  local storage
  storage="$(state_get proxmox_storage "local-lvm")"
  storage="$(ui_input "Storage" "Default Proxmox storage ID (e.g. local-lvm, local, zfs, nfs)" "$storage")"
  state_set proxmox_storage "$storage"
  ok "Saved storage: ${storage}"
}

prompt_theme() {
  local flavour
  flavour="$(state_get catppuccin_flavour "MOCHA")"

  ui_menu "Theme" "Choose Catppuccin flavour" flavour \
    LATTE "☕ Latte (light)" \
    FRAPPE "🥤 Frappé" \
    MACCHIATO "🍮 Macchiato" \
    MOCHA "🍫 Mocha"

  state_set catppuccin_flavour "$flavour"
  ok "Saved theme: $flavour"
}

prompt_secrets() {
  local mode
  mode="$(state_get secrets_mode "vaultwarden_sops")"

  ui_menu "Secrets" "How do you want to handle secrets?" mode \
    none "🚫 None (not recommended)" \
    vaultwarden_sops "🔐 Vaultwarden + SOPS (recommended)" \
    sops_only "🗝️ SOPS only (you manage the AGE key)"

  state_set secrets_mode "$mode"
  ok "Saved secrets mode: ${mode}"
}

prompt_targets() {
  local selected
  local dhcp_default

  if [ "$(state_get dhcp_mode "mikrotik")" = "proxmox" ]; then
    dhcp_default="on"
  else
    dhcp_default="off"
  fi

  ui_checklist "Services" "Select what you plan to run (you can change anytime)" selected \
    mikrotik "📡 MikroTik CHR (backup router)" off \
    dhcp "🛜 DHCP Server" "$dhcp_default" \
    dns "🌐 DNS Server" on \
    ad "🧩 Active Directory" off \
    talos "☸️ Talos Kubernetes" off \
    udms "🧱 UDMS" off \
    admin "🧑‍💻 Admin node (Code Server)" on

  state_set desired_services "${selected}"
  ok "Saved service selection: ${selected}"
}

main() {
  local choice
  while true; do
    ui_menu "Questionnaires" "What do you want to configure?" choice \
      1 "🖧 Proxmox connection" \
      2 "📡 MikroTik connection" \
      3 "🗺️  Network" \
      4 "💾 Storage" \
      5 "🎨 Theme" \
      6 "🌐 DNS provider" \
      7 "🛜 DHCP location" \
      8 "🔐 Secrets management" \
      9 "🧩 Services to build" \
      10 "🚨 Alerting" \
      11 "⬅️ Back"

    case "$choice" in
      1) prompt_proxmox ;;
      2) prompt_mikrotik ;;
      3) prompt_network ;;
      4) prompt_storage ;;
      5) prompt_theme ;;
      6) prompt_dns_provider ;;
      7) prompt_dhcp_mode ;;
      8) prompt_secrets ;;
      9) prompt_targets ;;
      10) prompt_alerting ;;
      11|"") break ;;
    esac
  done
}

main
