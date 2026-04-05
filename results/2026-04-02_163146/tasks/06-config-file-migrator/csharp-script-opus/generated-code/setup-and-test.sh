#!/bin/bash
set -e

# Install .NET SDK 10 if not available
if ! command -v dotnet &> /dev/null; then
    echo "Installing .NET SDK..."
    curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
    chmod +x /tmp/dotnet-install.sh
    /tmp/dotnet-install.sh --channel 10.0 --quality preview
    export DOTNET_ROOT="$HOME/.dotnet"
    export PATH="$DOTNET_ROOT:$PATH"
fi

echo "dotnet version: $(dotnet --version)"
echo ""

# Run tests
echo "=== Running tests ==="
dotnet test ConfigMigrator.Tests/ --verbosity normal
