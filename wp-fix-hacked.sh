#!/usr/bin/env bash
set -euo pipefail

# ----------------------
# wp-fix-hacked.sh
# ----------------------
# Usage: cd /path/to/your/wp-install && bash wp-fix-hacked.sh
# Or: bash wp-fix-hacked.sh /path/to/your/wp-install
# Default: current directory
# ----------------------

# Determine target directory
if [ $# -gt 0 ]; then
  ROOT_DIR="$1"
else
  ROOT_DIR="$(pwd)"
fi

# Ensure we’re in a WP install
if [ ! -f "$ROOT_DIR/wp-config.php" ]; then
  echo "⚠️  No wp-config.php found in $ROOT_DIR. Please run this from a WordPress install directory."
  exit 1
fi

USER="$(whoami)"
echo "🛑  Stopping all processes for user '$USER'..."
pkill -u "$USER" || true

echo "📂  Cleaning WordPress install at: $ROOT_DIR"

# 1. Delete everything except wp-config.php & wp-content/
find "$ROOT_DIR" -mindepth 1 \
  ! -path "$ROOT_DIR/wp-config.php" \
  ! -path "$ROOT_DIR/wp-content/*" \
  -exec rm -rf {} +

# 2. Remove ELF binaries
echo "   • Removing ELF binaries..."
find "$ROOT_DIR" -type f -exec sh -c \
  'file "$1" | grep -q ELF && echo "     ↳ Deleting $1" && rm -f "$1"' sh {} \;

# 3. Flag suspicious PHP code
echo "   • Checking for eval() injections:"
grep -iR --include="*.php" "eval(" "$ROOT_DIR" || echo "     (none found)"

echo "   • Checking for base64_decode() use:"
grep -iR --include="*.php" "base64_decode(" "$ROOT_DIR" || echo "     (none found)"

echo "     → Manually inspect any hits and remove malicious code."

# 4. Reinstall WP core
echo "   • Re-downloading WordPress core..."
wp core download --path="$ROOT_DIR" --skip-content --force \
  && echo "     ✔ Core reinstalled successfully."

echo -e "\n✅  Done! Review grep hits above, then secure your site (update credentials, plugins, themes)."
