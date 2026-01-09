#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# ----------------------
# wp-fix-hacked-prod.sh - Production-Ready WordPress Hack Cleanup
# ----------------------

readonly SCRIPT_NAME="$(basename "$0")"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log()        { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $*${NC}"; }
log_warn()   { echo -e "${YELLOW}⚠ $*${NC}"; }
log_error()  { echo -e "${RED}❌ $*${NC}" >&2; }
log_success(){ echo -e "${GREEN}✔ $*${NC}"; }

usage() {
cat <<EOF
Usage: sudo $SCRIPT_NAME [WP_ROOT_DIR]

WP_ROOT_DIR defaults to current directory.
Must be run as root/sudo.

Examples:
  sudo bash $SCRIPT_NAME
  sudo bash $SCRIPT_NAME /var/www/html
EOF
exit 1
}

# ----------------------
# Argument handling
# ----------------------
[[ $# -gt 1 ]] && usage
ROOT_DIR="${1:-$(pwd)}"

[[ ! -d "$ROOT_DIR" ]] && { log_error "Directory not found: $ROOT_DIR"; exit 1; }
[[ ! -f "$ROOT_DIR/wp-config.php" ]] && { log_error "No wp-config.php found in $ROOT_DIR"; exit 1; }

# ----------------------
# WP-CLI check
# ----------------------
command -v wp >/dev/null 2>&1 || {
  log_error "WP-CLI not found. Install from https://wp-cli.org"
  exit 1
}

# ----------------------
# Identify WordPress owner
# ----------------------
WP_OWNER="$(stat -c '%U' "$ROOT_DIR/wp-config.php")"
WP_GROUP="$(stat -c '%G' "$ROOT_DIR/wp-config.php")"

log "Target directory: $ROOT_DIR"
log "WordPress owner: $WP_OWNER:$WP_GROUP"

# ----------------------
# Confirmation
# ----------------------
cat <<EOF

${RED}DANGER – PRODUCTION CLEANUP${NC}

This script will:
• Kill all processes owned by $WP_OWNER
• Remove ELF binaries
• Scan PHP for malware
• Reinstall WordPress core (wp-content preserved)

BACKUP FIRST.

Type YES to continue:
EOF

read -r CONFIRM
[[ "$CONFIRM" != "YES" ]] && { log_warn "Aborted by user"; exit 0; }

# ----------------------
# Kill user processes safely
# ----------------------
log "Killing processes owned by $WP_OWNER..."

mapfile -t PIDS < <(
  ps -u "$WP_OWNER" -o pid= |
  awk -v self="$$" '$1 != 1 && $1 != self'
)

if (( ${#PIDS[@]} > 0 )); then
  kill -TERM "${PIDS[@]}" 2>/dev/null || true
  sleep 5
  kill -KILL "${PIDS[@]}" 2>/dev/null || true
  log_success "Killed ${#PIDS[@]} processes"
else
  log "No running processes found"
fi

cd "$ROOT_DIR"

# ----------------------
# Backup wp-config.php
# ----------------------
BACKUP="wp-config.php.bak.$(date +%Y%m%d_%H%M%S)"
cp -p wp-config.php "$BACKUP"
log_success "Backup created: $BACKUP"

# ----------------------
# Remove ELF binaries
# ----------------------
log "Scanning for ELF binaries..."

ELF_COUNT=0
while IFS= read -r -d '' file; do
  ((ELF_COUNT++))
  log_warn "Removing ELF binary: $file"
  rm -f "$file"
done < <(
  find . -type f -print0 |
  xargs -0 file |
  grep -i 'ELF' |
  cut -d: -f1 |
  tr '\n' '\0'
)

(( ELF_COUNT == 0 )) && log "No ELF binaries found"

# ----------------------
# Malware signature scan
# ----------------------
log "Scanning PHP files for malware patterns..."

grep -RIn \
  --include="*.php" \
  -E 'eval\(|base64_decode\(|gzinflate\(|str_rot13\(|assert\(|create_function\(' \
  . | head -n 10 || log "No obvious malware signatures detected"

# ----------------------
# Reinstall WordPress core
# ----------------------
log "Reinstalling WordPress core..."

wp core download --skip-content --force --quiet
wp core verify-checksums --quiet || log_warn "Checksum mismatch detected"

log_success "WordPress core reinstalled"

# ----------------------
# Post-cleanup checks
# ----------------------
log "Checking for updates..."

wp core check-update --quiet && log_warn "Core updates available"
wp plugin list --update=available --quiet | grep -q . && log_warn "Plugin updates available"
wp theme list --update=available --quiet | grep -q . && log_warn "Theme updates available"

# ----------------------
# Fix permissions
# ----------------------
log "Fixing permissions..."

find . -type d -exec chmod 755 {} +
find . -type f -exec chmod 644 {} +
chmod 600 wp-config.php 2>/dev/null || true

chown -R "$WP_OWNER:$WP_GROUP" . 2>/dev/null || log_warn "chown skipped"

cat <<EOF

${GREEN}✅ CLEANUP COMPLETE${NC}

${YELLOW}IMMEDIATE NEXT STEPS:${NC}
• Regenerate salts: https://api.wordpress.org/secret-key/1.1/salt/
• Scan uploads: find wp-content/uploads -name "*.php"
• Audit users: wp user list
• Change ALL passwords (FTP, DB, WP)
• Review server logs

Monitor for reinfection.
EOF
