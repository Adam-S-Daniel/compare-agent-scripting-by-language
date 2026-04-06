#!/bin/bash
# Run all tests for the Environment Matrix Generator
# Usage: bash run-tests.sh
set -e

export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"

echo "=== .NET Version ==="
dotnet --version

echo ""
echo "=== Running Unit Tests ==="
dotnet test MatrixGenerator.Tests --verbosity normal

echo ""
echo "=== Running Main Script with Sample Config ==="
dotnet run MatrixGenerator.cs sample-config.json
