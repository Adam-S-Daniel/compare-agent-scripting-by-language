#!/bin/bash
set -e

# Install .NET 10 SDK if not present
if ! command -v dotnet &> /dev/null; then
    if [ ! -f "$HOME/.dotnet/dotnet" ]; then
        echo "Installing .NET 10 SDK..."
        curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 10.0 --install-dir "$HOME/.dotnet"
    fi
    export DOTNET_ROOT="$HOME/.dotnet"
    export PATH="$DOTNET_ROOT:$PATH"
fi

echo "dotnet version: $(dotnet --version)"

# Run tests
cd "$(dirname "$0")"
dotnet test PipelineTests/PipelineTests.csproj --verbosity normal

echo ""
echo "Running the main pipeline demo..."
dotnet run pipeline.cs
