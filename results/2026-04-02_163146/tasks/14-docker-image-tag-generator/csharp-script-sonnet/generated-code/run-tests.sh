#!/usr/bin/env bash
# Script to install .NET 10 (if needed) and run the tests

set -e

DOTNET_DIR="$HOME/.dotnet"
DOTNET_CMD="$DOTNET_DIR/dotnet"

# Install .NET 10 if not already present
if [ ! -f "$DOTNET_CMD" ]; then
    echo "Installing .NET 10 SDK..."
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
    chmod +x /tmp/dotnet-install.sh
    /tmp/dotnet-install.sh --channel 10.0 --install-dir "$DOTNET_DIR"
fi

export PATH="$DOTNET_DIR:$PATH"
echo ".NET version: $($DOTNET_CMD --version)"

# Run tests
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "Running tests..."
"$DOTNET_CMD" test DockerTagGenerator.Tests/DockerTagGenerator.Tests.csproj --verbosity normal

echo ""
echo "Testing file-based app..."
"$DOTNET_CMD" run generate-tags.cs -- --branch main --sha abc1234567890 --tag v1.2.3
echo ""
"$DOTNET_CMD" run generate-tags.cs -- --branch feature/my-feature --sha def5678 --pr 42
echo ""
"$DOTNET_CMD" run generate-tags.cs -- --branch feature/my-feature --sha def5678
