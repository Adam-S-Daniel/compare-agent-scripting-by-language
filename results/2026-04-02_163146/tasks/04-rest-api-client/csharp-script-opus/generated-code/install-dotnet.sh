#!/bin/bash
# Install .NET 10 SDK and configure PATH
set -e

DOTNET_ROOT="$HOME/.dotnet"

if [ ! -x "$DOTNET_ROOT/dotnet" ]; then
    echo "Installing .NET 10 SDK to $DOTNET_ROOT..."
    curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0 --install-dir "$DOTNET_ROOT"
fi

export DOTNET_ROOT
export PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"
echo "dotnet version: $(dotnet --version)"
