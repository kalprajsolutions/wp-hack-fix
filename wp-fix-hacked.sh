#!/usr/bin/env bash
set -euo pipefail

# ----------------------
# wp-fix-hacked.sh
# ----------------------
# Usage: wp-fix-hacked.sh [ROOT_DIR]
# Default ROOT_DIR: /var/www
# ----------------------

ROOT_DIR="${1:-/var/www}"
USER="$(whoami)"

echo "🛑  Stopping all processes for user '$USER'..."
pkill -u "$USER" || true

echo "🔍  Searching for WordPress installations in $ROOT_DIR..."
mapfile -t INSTALL_DIRS < <(find "$ROOT_DIR" -type f -name wp-config.php -printf '%h
')

if [ ${#INSTALL_DIRS[@]} -eq 0 ]; then
  echo "⚠️  No wp-config.php found under $ROOT_DIR. Exiting."
  exit 1
fi

for DIR in "${INSTALL_DIRS[@]}"; do
  echo -e "
📂  Cleaning installation at: $DIR"

  # 1. Delete everything except wp-config.php & wp-content/
  find "$DIR" -mindepth 1 \
    ! -path "$DIR/wp-config.php" \
    ! -path "$DIR/wp-content*" \
    -exec rm -rf {} +

  # 2. Remove ELF binaries
  echo "   • Removing ELF binaries..."
  find "$DIR" -type f -exec sh -c \
    'file "$1" | grep -q ELF && echo "     ↳ Deleting $1" && rm -f "$1"' sh {} \;

  # 3. Flag suspicious PHP code
  echo "   • Checking for eval() injections:"
  grep -iR --include="*.php" "eval(" "$DIR" || echo "     (none found)"
  echo "   • Checking for base64_decode() use:"
  grep -iR --include="*.php" "base64_decode(" "$DIR" || echo "     (none found)"
  echo "     → Manually inspect any hits, remove payloads if malicious."

  # 4. Reinstall WP core
  echo "   • Re-downloading WordPress core..."
  wp core download --path="$DIR" --skip-content --force \
    && echo "     ✔ Core reinstalled successfully."
done

echo -e "
✅  All done! Review grep hits above, then secure your sites (change passwords, update plugins/themes)."
