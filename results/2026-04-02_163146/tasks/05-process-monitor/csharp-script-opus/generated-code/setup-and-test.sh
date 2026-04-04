#!/bin/bash
# Setup script: installs .NET 10 SDK if needed, then runs tests
set -e

# Check if dotnet is available
if ! command -v dotnet &>/dev/null; then
    echo "Installing .NET 10 SDK..."
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
    bash /tmp/dotnet-install.sh --channel 10.0
    export PATH="$HOME/.dotnet:$PATH"
    export DOTNET_ROOT="$HOME/.dotnet"
fi

echo "Using dotnet: $(dotnet --version)"
echo ""

cd "$(dirname "$0")"
echo "Running tests..."
dotnet test ProcessMonitor.Tests/ --verbosity normal
