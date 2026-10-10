#!/usr/bin/env bash
# ==============================================================================
# TV Atlas - Installer Script
# Installs TV Atlas desktop app, launcher binary, and high-res system icons
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== TV Atlas Installer ==="
echo "[*] Source directory: ${SCRIPT_DIR}"

# Determine target directories
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

# Ensure directories exist
mkdir -p "${INSTALL_DIR}"
mkdir -p "${BIN_DIR}"
mkdir -p "${APPS_DIR}"
mkdir -p "${ICONS_BASE}/scalable/apps"
mkdir -p "${ICONS_BASE}/512x512/apps"
mkdir -p "${ICONS_BASE}/256x256/apps"
mkdir -p "${ICONS_BASE}/128x128/apps"
mkdir -p "${ICONS_BASE}/64x64/apps"
mkdir -p "${ICONS_BASE}/48x48/apps"

echo "[*] Deploying application files to ${INSTALL_DIR}..."
cp -r "${SCRIPT_DIR}/main.py" "${INSTALL_DIR}/"
cp -r "${SCRIPT_DIR}/tv_backend.py" "${INSTALL_DIR}/"
cp -r "${SCRIPT_DIR}/web_server.py" "${INSTALL_DIR}/"
cp -r "${SCRIPT_DIR}/qml" "${INSTALL_DIR}/"
cp -r "${SCRIPT_DIR}/assets" "${INSTALL_DIR}/"
cp -r "${SCRIPT_DIR}/tv-atlas" "${INSTALL_DIR}/"
chmod +x "${INSTALL_DIR}/tv-atlas"

echo "[*] Installing launcher to ${BIN_DIR}/tv-atlas..."
ln -sf "${INSTALL_DIR}/tv-atlas" "${BIN_DIR}/tv-atlas"

echo "[*] Installing application icons..."
cp "${SCRIPT_DIR}/assets/tv-atlas.svg" "${ICONS_BASE}/scalable/apps/tv-atlas.svg"
if [ -f "${SCRIPT_DIR}/assets/icons/tv-atlas-512.png" ]; then
  cp "${SCRIPT_DIR}/assets/icons/tv-atlas-512.png" "${ICONS_BASE}/512x512/apps/tv-atlas.png"
  cp "${SCRIPT_DIR}/assets/icons/tv-atlas-256.png" "${ICONS_BASE}/256x256/apps/tv-atlas.png"
  cp "${SCRIPT_DIR}/assets/icons/tv-atlas-128.png" "${ICONS_BASE}/128x128/apps/tv-atlas.png"
  cp "${SCRIPT_DIR}/assets/icons/tv-atlas-64.png"  "${ICONS_BASE}/64x64/apps/tv-atlas.png"
  cp "${SCRIPT_DIR}/assets/icons/tv-atlas-48.png"  "${ICONS_BASE}/48x48/apps/tv-atlas.png"
elif [ -f "${SCRIPT_DIR}/assets/tv-atlas.png" ]; then
  cp "${SCRIPT_DIR}/assets/tv-atlas.png" "${ICONS_BASE}/512x512/apps/tv-atlas.png"
fi

echo "[*] Installing desktop entry..."
cp "${SCRIPT_DIR}/tv-atlas.desktop" "${APPS_DIR}/tv-atlas.desktop"

# Update desktop databases if available
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${APPS_DIR}" 2>/dev/null || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "${ICONS_BASE}" 2>/dev/null || true
fi

echo ""
echo "=========================================================="
echo " [SUCCESS] TV Atlas has been installed successfully!"
echo " - Desktop Entry: ${APPS_DIR}/tv-atlas.desktop"
echo " - Command line:  ${BIN_DIR}/tv-atlas"
echo "=========================================================="
echo " You can now launch TV Atlas from your application menu or"
echo " by typing: tv-atlas"
echo "=========================================================="
