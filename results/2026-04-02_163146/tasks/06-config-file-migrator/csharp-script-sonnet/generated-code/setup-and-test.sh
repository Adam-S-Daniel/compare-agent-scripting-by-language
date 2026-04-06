#!/bin/bash
# setup-and-test.sh
# Installs .NET 10 SDK if not present, then runs the test suite.
# Usage: bash setup-and-test.sh

set -e

# ── Install .NET if not available ──────────────────────────────────────────────
if ! command -v dotnet &>/dev/null; then
    echo "dotnet not in PATH — checking ~/.dotnet..."
    if [ -x "$HOME/.dotnet/dotnet" ]; then
        export PATH="$HOME/.dotnet:$PATH"
        export DOTNET_ROOT="$HOME/.dotnet"
        echo "Found existing install at $HOME/.dotnet"
    else
        echo "Installing .NET 10 SDK..."
        curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0
        export PATH="$HOME/.dotnet:$PATH"
        export DOTNET_ROOT="$HOME/.dotnet"
    fi
fi

DOTNET=$(command -v dotnet)
echo "Using dotnet: $DOTNET"
"$DOTNET" --version

# ── Run tests ─────────────────────────────────────────────────────────────────
cd "$(dirname "$0")"
"$DOTNET" test ConfigMigrator.Tests/ConfigMigrator.Tests.csproj --verbosity normal
