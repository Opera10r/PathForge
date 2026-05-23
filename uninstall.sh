#!/bin/bash
# PathForge Uninstaller

set -euo pipefail

echo "Uninstalling PathForge..."

# Remove Quick Actions
rm -rf "$HOME/Library/Services/PathForge —"*.workflow 2>/dev/null || true

# Remove core script
rm -rf "$HOME/.local/share/PathForge" 2>/dev/null || true

# Remove app data (keep config for reinstalls? ask user)
read -p "Remove settings and usage data? (y/N): " remove_data
if [[ "$remove_data" =~ ^[Yy]$ ]]; then
    rm -rf "$HOME/Library/Application Support/PathForge" 2>/dev/null || true
    echo "  ✓ Settings removed"
fi

# Refresh
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
killall Finder 2>/dev/null || true

echo ""
echo "PathForge has been uninstalled."
