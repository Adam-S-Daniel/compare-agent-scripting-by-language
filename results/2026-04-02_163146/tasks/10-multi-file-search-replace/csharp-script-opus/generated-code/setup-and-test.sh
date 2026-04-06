#!/bin/bash
# Install .NET 10 SDK and run tests
set -e

export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"

# Install .NET SDK if not present
if ! command -v dotnet &>/dev/null; then
    echo "Installing .NET 10 SDK..."
    curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0 --install-dir "$DOTNET_ROOT"
fi

echo "Using dotnet: $(dotnet --version)"

# Run tests
cd "$(dirname "$0")"
dotnet test SearchReplace.Tests --verbosity normal
