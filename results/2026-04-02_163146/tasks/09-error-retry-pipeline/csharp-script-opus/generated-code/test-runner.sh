#!/usr/bin/env bash
set -euo pipefail
export DOTNET_ROOT=/home/passp/.dotnet
export PATH=/home/passp/.dotnet:$PATH
export DOTNET_CLI_TELEMETRY_OPTOUT=1
cd "$(dirname "$0")"
echo "=== dotnet version ==="
dotnet --version
echo ""
echo "=== Running tests ==="
dotnet test PipelineTests/PipelineTests.csproj --verbosity normal
echo ""
echo "=== Running pipeline.cs ==="
dotnet run pipeline.cs
