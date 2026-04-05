#!/bin/bash
# Install .NET 10 SDK locally
DOTNET_DIR="$(cd "$(dirname "$0")" && pwd)/.dotnet"
curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 10.0 --install-dir "$DOTNET_DIR"
echo "Installed to: $DOTNET_DIR"
"$DOTNET_DIR/dotnet" --version
