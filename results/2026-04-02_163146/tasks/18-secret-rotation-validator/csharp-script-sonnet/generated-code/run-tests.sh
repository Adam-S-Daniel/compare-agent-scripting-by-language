#!/bin/bash
# Run tests and show output
export DOTNET_ROOT="/home/passp/.dotnet"
export PATH="/home/passp/.dotnet:$PATH"
cd "$(dirname "$0")"
dotnet test tests/SecretRotation.Tests/ --logger "console;verbosity=normal"
