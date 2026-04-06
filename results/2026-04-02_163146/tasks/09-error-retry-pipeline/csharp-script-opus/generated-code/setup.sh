#!/usr/bin/env bash
# Setup script: installs .NET 10 SDK if needed, then runs tests and the demo.
set -euo pipefail

# Install .NET 10 SDK if not present
if ! command -v dotnet &>/dev/null && [ ! -f "$HOME/.dotnet/dotnet" ]; then
    echo "Installing .NET 10 SDK..."
    curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 10.0 --install-dir "$HOME/.dotnet"
fi

# Ensure dotnet is in PATH
if ! command -v dotnet &>/dev/null; then
    export DOTNET_ROOT="$HOME/.dotnet"
    export PATH="$DOTNET_ROOT:$PATH"
fi

echo "Using .NET SDK: $(dotnet --version)"

cd "$(dirname "$0")"

echo ""
echo "=== Running tests ==="
dotnet test PipelineTests/PipelineTests.csproj --verbosity normal

echo ""
echo "=== Running pipeline demo ==="
dotnet run pipeline.cs
