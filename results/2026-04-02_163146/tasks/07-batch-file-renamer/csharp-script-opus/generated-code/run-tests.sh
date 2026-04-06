#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTNET_DIR="$SCRIPT_DIR/.dotnet"

# Install .NET 10 SDK if not present
if [ ! -f "$DOTNET_DIR/dotnet" ]; then
    echo "=== Installing .NET 10 SDK ==="
    curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 10.0 --install-dir "$DOTNET_DIR"
fi

export PATH="$DOTNET_DIR:$PATH"
export DOTNET_ROOT="$DOTNET_DIR"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1

echo "=== .NET version: $(dotnet --version) ==="

echo "=== Restoring and running tests ==="
cd "$SCRIPT_DIR"
dotnet test tests/tests.csproj --verbosity normal
