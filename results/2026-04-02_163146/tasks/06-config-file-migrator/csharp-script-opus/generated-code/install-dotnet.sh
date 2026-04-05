#!/usr/bin/env bash
set -e

export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1

if ! command -v dotnet &> /dev/null; then
    echo "=== Installing .NET SDK ==="

    # Try .NET 10 preview first, fall back to .NET 9
    if curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0 --quality preview --install-dir "$DOTNET_ROOT" 2>/dev/null; then
        echo "Installed .NET 10 preview"
    else
        echo ".NET 10 preview not available, falling back to .NET 9..."
        curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 9.0 --install-dir "$DOTNET_ROOT"

        # Update csproj to target net9.0
        sed -i 's/net10\.0/net9.0/g' ConfigMigrator.Tests/ConfigMigrator.Tests.csproj
        echo "Updated target framework to net9.0"
    fi
fi

echo ""
echo "dotnet version: $(dotnet --version)"
echo ""

echo "=== Running tests ==="
dotnet test ConfigMigrator.Tests/ --verbosity normal
echo ""
echo "=== Done ==="
