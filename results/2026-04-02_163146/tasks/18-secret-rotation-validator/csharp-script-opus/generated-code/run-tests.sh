#!/bin/bash
# Run all tests for the Secret Rotation Validator
export PATH="$HOME/.dotnet:$PATH"
export DOTNET_ROOT="$HOME/.dotnet"
export DOTNET_CLI_TELEMETRY_OPTOUT=1

echo "=== Running Secret Rotation Validator Tests ==="
dotnet test SecretRotationValidator.Tests/ --verbosity normal
