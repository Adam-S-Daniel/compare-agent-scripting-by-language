#!/usr/bin/env bash
set -euo pipefail

DN="$HOME/.dotnet"
export DOTNET_ROOT="$DN"
export PATH="$DN:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1

WORKDIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== dotnet version ==="
"$DN/dotnet" --version
echo ""

echo "=== Running tests ==="
"$DN/dotnet" test "$WORKDIR/PipelineTests/PipelineTests.csproj" --verbosity normal
TEST_EXIT=$?
echo ""
echo "=== Test exit code: $TEST_EXIT ==="
echo ""

echo "=== Running pipeline.cs ==="
cd "$WORKDIR"
"$DN/dotnet" run pipeline.cs
RUN_EXIT=$?
echo ""
echo "=== Run exit code: $RUN_EXIT ==="
