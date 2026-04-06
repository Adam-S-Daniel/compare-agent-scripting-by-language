#!/bin/bash
# Install .NET 10 if not available, then run tests

set -e

# Check if dotnet is available
if ! command -v dotnet &>/dev/null; then
    echo "Installing .NET 10 SDK..."
    # Try via Microsoft's official install script
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
    bash /tmp/dotnet-install.sh --channel 10.0 --install-dir "$HOME/.dotnet"
    export DOTNET_ROOT="$HOME/.dotnet"
    export PATH="$HOME/.dotnet:$PATH"
fi

echo "Using .NET version: $(dotnet --version)"

# Run the tests
echo ""
echo "=== Running tests ==="
dotnet test MatrixGenerator.Tests/ -v normal

echo ""
echo "=== Running demo ==="
dotnet run generate-matrix.cs
