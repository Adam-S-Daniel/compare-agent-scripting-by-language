#!/bin/bash
# Install .NET 10 SDK for the log file analyzer task
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTNET_DIR="$SCRIPT_DIR/.dotnet"

# Check if already installed
if [ -f "$DOTNET_DIR/dotnet" ]; then
    echo ".NET already installed at $DOTNET_DIR"
    "$DOTNET_DIR/dotnet" --version
    exit 0
fi

echo "Downloading .NET install script..."
curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
chmod +x /tmp/dotnet-install.sh

echo "Installing .NET 10..."
bash /tmp/dotnet-install.sh --channel 10.0 --install-dir "$DOTNET_DIR"

echo "Done! .NET version:"
"$DOTNET_DIR/dotnet" --version
