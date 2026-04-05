#!/usr/bin/env bash
set -euo pipefail
DOTNET_ROOT="$HOME/.dotnet"
PATH="$DOTNET_ROOT:$PATH"
export DOTNET_ROOT PATH DOTNET_CLI_TELEMETRY_OPTOUT=1

if ! command -v dotnet &>/dev/null; then
    curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0 --install-dir "$DOTNET_ROOT"
fi

cd "$(dirname "$0")"
dotnet test SearchReplace.Tests --verbosity normal
