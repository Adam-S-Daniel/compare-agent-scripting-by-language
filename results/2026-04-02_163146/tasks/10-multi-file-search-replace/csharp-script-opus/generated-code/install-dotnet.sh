#!/usr/bin/env bash
set -euo pipefail
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"
if ! command -v dotnet &>/dev/null; then
    echo "Installing .NET 10 SDK..."
    curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0 --install-dir "$DOTNET_ROOT"
fi
echo "dotnet version: $(dotnet --version)"
