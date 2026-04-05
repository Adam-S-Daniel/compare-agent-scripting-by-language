#!/usr/bin/env bash
# install-dotnet.sh
# Installs the .NET 10 SDK to ~/.dotnet and adds it to PATH for the current session.
# Run this once before running `dotnet test` or `dotnet run DatabaseSeeder.cs`.

set -euo pipefail

INSTALL_DIR="${DOTNET_INSTALL_DIR:-$HOME/.dotnet}"
CHANNEL="10.0"

echo "Installing .NET $CHANNEL SDK to $INSTALL_DIR..."
curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- \
    --channel "$CHANNEL" \
    --install-dir "$INSTALL_DIR"

export PATH="$INSTALL_DIR:$PATH"
export DOTNET_ROOT="$INSTALL_DIR"

echo ""
echo "Installed: $(dotnet --version)"
echo ""
echo "Add the following to your shell profile for permanent access:"
echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
echo "  export DOTNET_ROOT=\"$INSTALL_DIR\""
