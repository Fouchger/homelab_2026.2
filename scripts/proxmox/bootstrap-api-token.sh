#!/usr/bin/env bash
# Project: homelab_2026.2
# -----------------------------------------------------------------------------
# Filename: scripts/proxmox/bootstrap-api-token.sh
# Created: 2026-01-18
# Description: Bootstrap a Proxmox API token for Terraform/Ansible automation (idempotent and safety guarded).
# Usage:
#   bash 03_ddployrr/ddployrr/scripts/bootstrap-api-token.sh
# Notes:
#   - Exits early if the local token output file exists, to avoid unintended changes.
# Maintainer: Gert
# Project: homelab_2026.2
# Contributors: ddployrr project contributors
# -----------------------------------------------------------------------------

set -euo pipefail

# Resolve repo root (prefer git when available)
if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  BASE_DIR="$git_root"
else
  BASE_DIR="$(pwd)"
fi

# Optional: load persisted settings (created via the questionnaires menu).
STATE_ENV="${HOME}/.config/homelab_2026_2/state.env"
if [[ -r "${STATE_ENV}" ]]; then
  # shellcheck disable=SC1090
  source "${STATE_ENV}"
fi

echo ""
echo "============================"
echo " Proxmox API Token Bootstrap"
echo "============================"
echo ""

# ======== Configure these ========
read -r -p "Enter your Proxmox Hostname or IP [192.168.88.250]: " input_proxmox_host
PROXMOX_HOST="${PROXMOX_HOST:-${input_proxmox_host:-192.168.88.250}}"

read -r -p "Enter your Proxmox SSH Username [root]: " input_proxmox_user
PROXMOX_SSH_USER="${PROXMOX_SSH_USER:-${input_proxmox_user:-root}}"

PROXMOX_SSH_PORT="${PROXMOX_SSH_PORT:-22}"

PVE_REALM="${PVE_REALM:-pve}"

PVE_USER_NAME="${PVE_USER_NAME:-homelab_automation}"
PVE_ROLE_NAME="${PVE_ROLE_NAME:-Homelab_Automation}"
PVE_TOKEN_ID="${PVE_TOKEN_ID:-homelab_automation_api}"

ACL_PATH="${ACL_PATH:-/}"
PROPAGATE="${PROPAGATE:-1}"
TOKEN_PRIVSEP="${TOKEN_PRIVSEP:-0}"

PVE_PRIVS="${PVE_PRIVS:-Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit,Pool.Allocate,Pool.Audit,SDN.Use,Sys.Audit,Sys.Console,Sys.Modify,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.Cloudinit,VM.Config.CPU,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Migrate,VM.PowerMgmt}"

TOKEN_OUT_DIR="${TOKEN_OUT_DIR:-$HOME/.proxmox}"
TOKEN_OUT_FILE="${TOKEN_OUT_FILE:-$TOKEN_OUT_DIR/${PROXMOX_HOST}_${PVE_USER_NAME}_${PVE_TOKEN_ID}.token}"

SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"
# =================================

PVE_USERID="${PVE_USER_NAME}@${PVE_REALM}"

say() { printf "%s\n" "$*"; }
die() { printf "Error: %s\n" "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

need_cmd ssh
need_cmd ssh-keygen

# ----------------------------
# HARD GUARD: do not run if token output already exists
# ----------------------------
if [[ -f "${TOKEN_OUT_FILE}" ]]; then
  say "Token file already exists. Skipping bootstrap to avoid unintended changes:"
  say "  ${TOKEN_OUT_FILE}"
  say "To rotate/recreate, delete this file and rerun the script."
  exit 0
fi

HAS_SSH_COPY_ID=0
if command -v ssh-copy-id >/dev/null 2>&1; then
  HAS_SSH_COPY_ID=1
fi

say "== Proxmox bootstrap starting =="
say "Target: ${PROXMOX_SSH_USER}@${PROXMOX_HOST}:${PROXMOX_SSH_PORT}"
say "Will recreate: user ${PVE_USERID}, role ${PVE_ROLE_NAME}, token ${PVE_TOKEN_ID}, ACL path ${ACL_PATH}"

# 1) Ensure SSH key exists
if [[ ! -f "${SSH_KEY_PATH}" ]]; then
  say ""
  say "No SSH key found at ${SSH_KEY_PATH}. Creating one (ed25519)..."
  mkdir -p "$(dirname "$SSH_KEY_PATH")"
  ssh-keygen -t ed25519 -a 64 -f "${SSH_KEY_PATH}" -N "" -C "${USER}@$(hostname)-proxmox-bootstrap"
else
  say ""
  say "SSH key exists: ${SSH_KEY_PATH}"
fi

PUBKEY="${SSH_KEY_PATH}.pub"
[[ -f "$PUBKEY" ]] || die "Public key missing: ${PUBKEY}"

# 2) Copy key to Proxmox
say ""
say "Adding workstation SSH key to Proxmox (you may be prompted)..."
if [[ "$HAS_SSH_COPY_ID" -eq 1 ]]; then
  ssh-copy-id -i "$PUBKEY" -p "$PROXMOX_SSH_PORT" "${PROXMOX_SSH_USER}@${PROXMOX_HOST}"
else
  say "ssh-copy-id not found; using fallback key install method."
  PUB="$(cat "$PUBKEY")"
  ssh -p "$PROXMOX_SSH_PORT" "${PROXMOX_SSH_USER}@${PROXMOX_HOST}" \
    "umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; grep -qxF '$PUB' ~/.ssh/authorized_keys || echo '$PUB' >> ~/.ssh/authorized_keys"
fi

# 3) Optional Proxmox user password
say ""
say "Now recreating Proxmox user/role/ACL and API token via SSH."
read -r -p "Set a password for ${PVE_USERID}? (y/N): " SETPW
SETPW="${SETPW:-N}"

PVE_PASSWORD=""
if [[ "$SETPW" =~ ^[Yy]$ ]]; then
  read -r -s -p "Enter password for ${PVE_USERID}: " PVE_PASSWORD
  echo
  read -r -s -p "Confirm password: " PVE_PASSWORD_CONFIRM
  echo
  [[ "$PVE_PASSWORD" == "$PVE_PASSWORD_CONFIRM" ]] || die "Passwords do not match."
fi

# Remote script to run on Proxmox
REMOTE_SCRIPT=$(cat <<'EOS'
set -euo pipefail

PVE_USERID="__PVE_USERID__"
PVE_ROLE_NAME="__PVE_ROLE_NAME__"
PVE_TOKEN_ID="__PVE_TOKEN_ID__"
ACL_PATH="__ACL_PATH__"
PROPAGATE="__PROPAGATE__"
TOKEN_PRIVSEP="__TOKEN_PRIVSEP__"
PVE_PRIVS="__PVE_PRIVS__"
PVE_PASSWORD="__PVE_PASSWORD__"

echo "== Running on Proxmox host: $(hostname) =="
command -v pveum >/dev/null 2>&1 || { echo "pveum not found. Are you on a Proxmox VE node?"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not found on Proxmox node. Installing..."; apt-get update -y && apt-get install -y jq; }

user_exists() {
  pveum user list --output-format json \
    | jq -e --arg u "${PVE_USERID}" '.[] | select(.userid == $u)' >/dev/null
}
role_exists() {
  pveum role list --output-format json \
    | jq -e --arg r "${PVE_ROLE_NAME}" '.[] | select(.roleid == $r)' >/dev/null
}
token_exists() {
  pveum user token list "${PVE_USERID}" --output-format json 2>/dev/null \
    | jq -e --arg t "${PVE_TOKEN_ID}" '.[] | select(.tokenid == $t)' >/dev/null
}
echo ""
echo "== Current state =="
user_exists && echo "User exists" || echo "User does not exist"
role_exists && echo "Role exists" || echo "Role does not exist"
token_exists && echo "Token exists" || echo "Token does not exist"

echo ""
echo "== Pre-clean: remove token/user/role if present =="

# 1) Remove token (only if user exists)
if user_exists; then
  if token_exists; then
    echo "Removing token: ${PVE_USERID}!${PVE_TOKEN_ID}"
    pveum user token remove "${PVE_USERID}" "${PVE_TOKEN_ID}"
    # verify token removal
    if token_exists; then
      echo "ERROR: Token still exists after removal attempt: ${PVE_USERID}!${PVE_TOKEN_ID}"
      exit 1
    fi
  else
    echo "Token not present - skipping"
  fi
else
  echo "User not present - skipping token removal"
fi

# 2) Remove user
if user_exists; then
  echo "Removing user: ${PVE_USERID}"
  pveum user delete "${PVE_USERID}"
  # verify user removal
  if user_exists; then
    echo "ERROR: User still exists after deletion attempt: ${PVE_USERID}"
    echo "Common causes: cluster filesystem (pmxcfs) not writable, lack of quorum, or another process recreating the user."
    exit 1
  fi
else
  echo "User not present - skipping"
fi

# 3) Remove role
if role_exists; then
  echo "Removing role: ${PVE_ROLE_NAME}"
  pveum role delete "${PVE_ROLE_NAME}"
  # verify role removal
  if role_exists; then
    echo "ERROR: Role still exists after deletion attempt: ${PVE_ROLE_NAME}"
    exit 1
  fi
else
  echo "Role not present - skipping"
fi

echo ""
echo "== Recreate user/role/ACL/token =="

echo "Creating user: ${PVE_USERID}"
if [[ -n "${PVE_PASSWORD}" ]]; then
  pveum user add "${PVE_USERID}" --comment "Automation user" --password "${PVE_PASSWORD}"
else
  pveum user add "${PVE_USERID}" --comment "Automation user"
fi

echo "Creating role: ${PVE_ROLE_NAME}"
pveum role add "${PVE_ROLE_NAME}" -privs "${PVE_PRIVS}"

echo "Assigning ACL: path=${ACL_PATH}, user=${PVE_USERID}, role=${PVE_ROLE_NAME}, propagate=${PROPAGATE}"
pveum aclmod "${ACL_PATH}" -user "${PVE_USERID}" -role "${PVE_ROLE_NAME}" -propagate "${PROPAGATE}"

echo "Creating API token: ${PVE_USERID}!${PVE_TOKEN_ID} (privsep=${TOKEN_PRIVSEP})"
pveum user token add "${PVE_USERID}" "${PVE_TOKEN_ID}" --privsep "${TOKEN_PRIVSEP}"
EOS
)

# Inject variables (simple replacement; assumes no newlines)
REMOTE_SCRIPT="${REMOTE_SCRIPT//__PVE_USERID__/${PVE_USERID}}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__PVE_ROLE_NAME__/${PVE_ROLE_NAME}}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__PVE_TOKEN_ID__/${PVE_TOKEN_ID}}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__ACL_PATH__/${ACL_PATH}}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__PROPAGATE__/${PROPAGATE}}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__TOKEN_PRIVSEP__/${TOKEN_PRIVSEP}}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__PVE_PRIVS__/${PVE_PRIVS}}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__PVE_PASSWORD__/${PVE_PASSWORD}}"


say ""
say "Connecting to Proxmox and running provisioning..."
TOKEN_OUTPUT="$(ssh -p "$PROXMOX_SSH_PORT" "${PROXMOX_SSH_USER}@${PROXMOX_HOST}" "bash -s" <<<"$REMOTE_SCRIPT")"

say ""
say "== Proxmox response =="
printf "%s\n" "$TOKEN_OUTPUT"

FULL_TOKENID="$(printf "%s\n" "$TOKEN_OUTPUT" | awk -F'│' '/full-tokenid/ {gsub(/ /,"",$3); print $3}' | tail -n1)"
TOKEN_VALUE="$(printf "%s\n" "$TOKEN_OUTPUT" | awk -F'│' '/│ value / {gsub(/ /,"",$3); print $3}' | tail -n1)"

# 4) Save token details locally
say ""
say "Saving token details to local file..."

# ---- Project handover (.env) ----
# Writes a deterministic handover file for deploy.py and other tooling.
# Does NOT include the token secret.
PROJECT_ROOT="$BASE_DIR"
ENV_OUT_FILE="${ENV_OUT_FILE:-$PROJECT_ROOT/generated_configs/.env}"
mkdir -p $PROJECT_ROOT/generated_configs

umask 077
cat > "$ENV_OUT_FILE" <<EOF
# Generated by scripts/bootstrap-api-token.sh on $(date -Iseconds)
PROXMOX_HOST=${PROXMOX_HOST}
PVE_USER_NAME=$PVE_USER_NAME
PVE_TOKEN_ID=${FULL_TOKENID}
PVE_TOKEN_SECRET=${TOKEN_VALUE}
AUTH_HEADER=Authorization: PVEAPIToken=${FULL_TOKENID}=${TOKEN_VALUE}
EOF

chmod 600 "$ENV_OUT_FILE" 2>/dev/null || true
echo "Wrote handover file: $ENV_OUT_FILE"

mkdir -p "$TOKEN_OUT_DIR"
chmod 700 "$TOKEN_OUT_DIR"

if [[ -n "${FULL_TOKENID}" && -n "${TOKEN_VALUE}" ]]; then
  umask 077
  {
    echo "PROXMOX_HOST=${PROXMOX_HOST}"
    echo "PVE_TOKEN_ID=${FULL_TOKENID}"
    echo "PVE_TOKEN_SECRET=${TOKEN_VALUE}"
    echo "AUTH_HEADER=Authorization: PVEAPIToken=${FULL_TOKENID}=${TOKEN_VALUE}"
  } > "$TOKEN_OUT_FILE"
  chmod 600 "$TOKEN_OUT_FILE"

  say ""
  say "Saved token details to: ${TOKEN_OUT_FILE}"
else
  say ""
  say "Could not reliably parse token fields from output."
  say "Copy the token secret from the Proxmox output above now (it is only shown once)."
  exit 1
fi

say ""
say "== Done =="
