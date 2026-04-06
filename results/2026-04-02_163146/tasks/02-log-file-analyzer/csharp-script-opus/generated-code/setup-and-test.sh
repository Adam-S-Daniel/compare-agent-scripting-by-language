#!/bin/bash
# Setup script: installs .NET 10 SDK and runs all tests.
# Run this script to set up and verify the Log Analyzer.

set -e

# Install .NET 10 SDK if not already installed
if ! command -v dotnet &>/dev/null; then
    echo "Installing .NET 10 SDK..."
    curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0 --install-dir "$HOME/.dotnet"
    export PATH="$HOME/.dotnet:$PATH"
    export DOTNET_ROOT="$HOME/.dotnet"
fi

echo ".NET version: $(dotnet --version)"

# Restore and run tests
echo ""
echo "Running tests..."
cd tests
dotnet test --verbosity normal

echo ""
echo "All tests passed!"

# Demo: run the standalone script on the sample log
echo ""
echo "--- Demo: Running LogAnalyzer on sample-mixed.log ---"
cd ..
dotnet run LogAnalyzer.cs -- tests/fixtures/sample-mixed.log --json analysis-output.json
