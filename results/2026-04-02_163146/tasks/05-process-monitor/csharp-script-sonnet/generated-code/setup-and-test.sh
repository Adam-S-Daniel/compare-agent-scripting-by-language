#!/bin/bash
# Setup and test script — installs .NET 10 if needed, then runs tests

set -e

# Install .NET 10 SDK if not present
if ! command -v dotnet &>/dev/null; then
    echo "Installing .NET 10 SDK..."
    curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0
    export PATH="$HOME/.dotnet:$PATH"
    export DOTNET_ROOT="$HOME/.dotnet"
fi

DOTNET=$(command -v dotnet 2>/dev/null || echo "$HOME/.dotnet/dotnet")
echo "Using dotnet: $DOTNET"
"$DOTNET" --version

# Run tests
"$DOTNET" test ProcessMonitor.Tests/ProcessMonitor.Tests.csproj --verbosity normal
