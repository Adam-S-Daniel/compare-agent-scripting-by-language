#!/usr/bin/env bash
set -euo pipefail

export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1

if ! command -v dotnet &>/dev/null; then
    echo "==> Installing .NET 10 SDK..."
    curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0 --install-dir "$DOTNET_ROOT"
fi

echo "==> .NET version: $(dotnet --version)"

cd "$(dirname "$0")"

echo "==> Restoring packages..."
dotnet restore DirectorySync.Tests/DirectorySync.Tests.csproj

echo "==> Running tests..."
dotnet test DirectorySync.Tests/DirectorySync.Tests.csproj --verbosity normal

echo "==> All done!"
