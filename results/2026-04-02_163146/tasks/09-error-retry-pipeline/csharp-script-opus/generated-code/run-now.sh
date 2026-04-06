#!/bin/bash
export DOTNET_ROOT=/home/passp/.dotnet
export PATH=/home/passp/.dotnet:$PATH
echo "=== dotnet version ==="
dotnet --version
echo ""
echo "=== Running tests ==="
cd /home/passp/repos/compare-agent-scripting-by-language/workspaces/2026-04-02_163146/09-error-retry-pipeline/csharp-script-opus
dotnet test PipelineTests/PipelineTests.csproj --verbosity normal 2>&1
TEST_EXIT=$?
echo ""
echo "=== Test exit code: $TEST_EXIT ==="
echo ""
echo "=== Running pipeline.cs ==="
dotnet run pipeline.cs 2>&1
RUN_EXIT=$?
echo ""
echo "=== Run exit code: $RUN_EXIT ==="
