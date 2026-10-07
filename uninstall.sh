#!/usr/bin/env bash
# ==============================================================================
# TV Atlas - Uninstaller Script
# Removes TV Atlas desktop app, binary launcher, and installed icons
# ==============================================================================

set -euo pipefail

echo "=== TV Atlas Uninstaller ==="

if [ "$(id -u)" -eq 0 ]; then
  INSTALL_DIR="/opt/tv-atlas"
  BIN_DIR="/usr/local/bin"
  APPS_DIR="/usr/share/applications"
  ICONS_BASE="/usr/share/icons/hicolor"
else
  INSTALL_DIR="${HOME}/.local/share/tv-atlas-app"
  BIN_DIR="${HOME}/.local/bin"
  APPS_DIR="${HOME}/.local/share/applications"
  ICONS_BASE="${HOME}/.local/share/icons/hicolor"
fi

echo "[*] Removing launcher binary..."
rm -f "${BIN_DIR}/tv-atlas"

echo "[*] Removing desktop entry..."
rm -f "${APPS_DIR}/tv-atlas.desktop"

echo "[*] Removing icons..."
rm -f "${ICONS_BASE}/scalable/apps/tv-atlas.svg"
rm -f "${ICONS_BASE}/512x512/apps/tv-atlas.png"
rm -f "${ICONS_BASE}/256x256/apps/tv-atlas.png"
rm -f "${ICONS_BASE}/128x128/apps/tv-atlas.png"
rm -f "${ICONS_BASE}/64x64/apps/tv-atlas.png"
rm -f "${ICONS_BASE}/48x48/apps/tv-atlas.png"

echo "[*] Removing deployed application files..."
rm -rf "${INSTALL_DIR}"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${APPS_DIR}" 2>/dev/null || true
fi

echo "[SUCCESS] TV Atlas has been uninstalled."
