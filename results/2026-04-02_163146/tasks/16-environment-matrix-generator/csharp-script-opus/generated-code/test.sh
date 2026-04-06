#!/usr/bin/env bash
set -e
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"
dotnet test MatrixGenerator.Tests -v n
