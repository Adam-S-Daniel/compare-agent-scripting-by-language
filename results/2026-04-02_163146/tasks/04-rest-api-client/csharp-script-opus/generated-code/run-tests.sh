#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTNET_ROOT="${DOTNET_ROOT:-$HOME/.dotnet}"

# Install .NET 10 SDK if not available
if ! command -v dotnet &> /dev/null && [ ! -x "$DOTNET_ROOT/dotnet" ]; then
    echo "Installing .NET 10 SDK..."
    curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0 --install-dir "$DOTNET_ROOT"
fi

# Ensure dotnet is on PATH
if ! command -v dotnet &> /dev/null; then
    export DOTNET_ROOT
    export PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"
fi

echo "dotnet version: $(dotnet --version)"

# Run tests from the project directory
cd "$SCRIPT_DIR"
echo "Restoring packages and running tests..."
dotnet test tests/ApiTests.csproj --verbosity normal
echo ""
echo "All tests passed!"
