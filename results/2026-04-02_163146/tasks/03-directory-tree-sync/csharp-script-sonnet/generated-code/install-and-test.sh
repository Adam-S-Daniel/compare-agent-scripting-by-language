#!/usr/bin/env bash
# Install .NET 10 SDK and run tests

set -e

# Install .NET 10 if not available
if ! command -v dotnet &>/dev/null; then
    echo "Installing .NET 10 SDK..."
    wget -q https://dot.net/v1/dotnet-install.sh -O /tmp/dotnet-install.sh
    chmod +x /tmp/dotnet-install.sh
    /tmp/dotnet-install.sh --channel 10.0
    export PATH="$HOME/.dotnet:$PATH"
    export DOTNET_ROOT="$HOME/.dotnet"
fi

echo "dotnet version: $(dotnet --version)"

# Run tests
echo ""
echo "=== Running Tests ==="
dotnet test DirSync.Tests/ --logger "console;verbosity=normal"

echo ""
echo "=== Test run complete ==="
