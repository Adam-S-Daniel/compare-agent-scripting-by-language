#!/usr/bin/env bash
# Setup and test runner for PR Label Assigner (C# / .NET 10)
# Usage: bash run-tests.sh

set -euo pipefail

DOTNET_DIR="$HOME/.dotnet"
DOTNET="$DOTNET_DIR/dotnet"

# Install .NET 10 if not present
if [ ! -f "$DOTNET" ]; then
    echo "Installing .NET 10 SDK..."
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
    bash /tmp/dotnet-install.sh --channel 10.0 --install-dir "$DOTNET_DIR"
fi

export PATH="$DOTNET_DIR:$DOTNET_DIR/tools:$PATH"

echo ".NET version: $($DOTNET --version)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "Running tests..."
"$DOTNET" test PrLabelAssigner.Tests/ --logger "console;verbosity=detailed"

echo ""
echo "Running standalone demo..."
"$DOTNET" run label-assigner.cs
