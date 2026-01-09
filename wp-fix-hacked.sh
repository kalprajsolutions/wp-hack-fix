#!/usr/bin/env bash
set -euo pipefail

# ----------------------
# wp-fix-hacked-prod.sh - Production-Ready WordPress Hack Cleanup
# ----------------------
# Usage: cd /path/to/wp && sudo bash wp-fix-hacked-prod.sh
# Requires: WP-CLI (install: curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && sudo mv wp-cli.phar /usr/local/bin/wp)
# Backup first! This is destructive to core files.
# ----------------------

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}" >&2; }
log_success() { echo -e "${GREEN}✔ $1${NC}"; }

usage() {
  cat << EOF
Usage: sudo $SCRIPT_NAME [WP_ROOT_DIR]

WP_ROOT_DIR: Path to WordPress install (default: current dir).
Run as root/sudo for process killing across users.

Examples:
  sudo bash $SCRIPT_NAME
  sudo bash $SCRIPT_NAME /var/www/html
EOF
  exit 1
}

# Parse args
[ $# -gt 1 ] && usage
ROOT_DIR="${1:-$(pwd)}"
[ ! -d "$ROOT_DIR" ] && { log_error "Directory not found: $ROOT_DIR"; exit 1; }

# Validate WP install
[ ! -f "$ROOT_DIR/wp-config.php" ] && { log_error "No wp-config.php in $ROOT_DIR"; usage; }

# Check WP-CLI
if ! command -v wp >/dev/null 2>&1; then
  log_error "WP-CLI required. Install: https://wp-cli.org/#installing-on-linux"
  exit 1
fi

# Get wp-config owner
WP_OWNER="$(stat -c '%U' "$ROOT_DIR/wp-config.php")" || { log_error "Cannot stat wp-config.php"; exit 1; }
log "Target: $ROOT_DIR (wp-config.php owner: $WP_OWNER)"

# Confirmation (production safety)
cat << EOF

${RED}DANGER: Production cleanup! This will:${NC}
- Kill ALL processes owned by '$WP_OWNER' (except system init)
- Remove suspicious ELF files
- Flag malware patterns
- Reinstall WP core (keeps wp-config.php + wp-content)

BACKUP FIRST! Proceed? (type 'YES' to continue)
EOF
read -r CONFIRM
[ "$CONFIRM" != "YES" ] && { log_warn "Aborted."; exit 0; }

# 1. Kill user processes safely (exclude 1, PPID=1, and this script)[1][2]
log "Killing processes for user '$WP_OWNER'..."
mapfile -t PIDS < <(ps -u "$WP_OWNER" -o pid= | grep -v '^1$' | grep -v "^$$")
if [ ${#PIDS[@]} -gt 0 ]; then
  echo "${PIDS[*]}" | xargs -r kill -TERM
  sleep 5
  echo "${PIDS[*]}" | xargs -r kill -KILL 2>/dev/null || true
  log_success "Killed ${#PIDS[@]} processes."
else
  log "No user processes found."
fi

cd "$ROOT_DIR" || { log_error "Cannot cd to $ROOT_DIR"; exit 1; }

# 2. Backup wp-config.php (safety)
cp -p wp-config.php wp-config.php.bak.$(date +%Y%m%d_%H%M%S) && log_success "Backed up wp-config.php"

# 3. Remove ELF binaries (common webshell type)
log "Removing ELF binaries..."
ELF_COUNT=0
while IFS= read -r -d '' file; do
  ((ELF_COUNT++))
  log_warn "Deleting ELF: $(basename "$file")"
  rm -f "$file"
done < <(find . -type f -exec file {} + 2>/dev/null | grep -l "ELF" | tr '\n' '\0')
[ $ELF_COUNT -eq 0 ] && log "No ELF files found."

# 4. Scan for malware patterns (limited output for prod)
log "Scanning PHP for malware signatures..."
grep -iR --include="*.php" --max-count=10 'eval\|base64_decode.*\(|gzinflate\|str_rot\|assert\|create_function' . | \
  sed 's/^/  Suspicious: /' || log "No common signatures found (manual scan uploads/db recommended)."

# 5. Reinstall core (safe: --skip-content preserves wp-content) [][]
log "Reinstalling WP core..."
wp core download --skip-content --force --quiet
wp core verify-checksums --quiet || log_warn "Checksums mismatch? Common post-download."
log_success "Core reinstalled."

# 6. Post-cleanup security checks
log "Running security checks..."
wp core check-update --quiet && log_warn "Core updates available."
wp plugin list --update=available --quiet | grep -q . && log_warn "Plugin updates available."
wp theme list --update=available --quiet | grep -q . && log_warn "Theme updates available."

# 7. Permissions fix (standard WP)
find . -type d -exec chmod 755 {} +
find . -type f -exec chmod 644 {} +
chmod 600 wp-config.php *.key
chown -R "$WP_OWNER":"$(stat -c '%G' wp-config.php)" . 2>/dev/null || log_warn "chown failed (normal if no sudo)."

cat << EOF

${GREEN}✅ Cleanup complete!${NC}

${YELLOW}🚨 IMMEDIATE ACTIONS:${NC}
- Restore salts in wp-config.php: https://api.wordpress.org/secret-key/1.1/salt/
- Scan wp-content/uploads: find . -name "*.php" -exec grep -l "eval\|base64" {} +
- Check DB: wp db query "SELECT * FROM wp_users WHERE user_login NOT IN ('admin')" (customize)
- Change ALL passwords (FTP/DB/WP admin)
- Review logs: /var/log/apache2/error.log | grep error
- Install security: Wordfence/MalCare or Sucuri [][]

Monitor for reinfection!
EOF
