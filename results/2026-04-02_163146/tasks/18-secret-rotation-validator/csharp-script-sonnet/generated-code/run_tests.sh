#!/bin/bash
set -e

WORKSPACE="/home/passp/repos/compare-agent-scripting-by-language/workspaces/2026-04-02_163146/18-secret-rotation-validator/csharp-script-sonnet"
cd "$WORKSPACE"

# Find or install dotnet
DOTNET=""
if command -v dotnet &>/dev/null; then
    DOTNET="dotnet"
elif [ -f "$HOME/.dotnet/dotnet" ]; then
    DOTNET="$HOME/.dotnet/dotnet"
    export PATH="$HOME/.dotnet:$PATH"
fi

if [ -z "$DOTNET" ]; then
    echo "dotnet not found, cannot run tests"
    exit 1
fi

echo "=== dotnet version ==="
$DOTNET --version

echo ""
echo "=== dotnet test ==="
$DOTNET test tests/SecretRotation.Tests/ -v normal 2>&1

echo ""
echo "=== dotnet run run.cs (markdown) ==="
$DOTNET run run.cs 2>&1

echo ""
echo "=== dotnet run run.cs -- --format json ==="
$DOTNET run run.cs -- --format json 2>&1
