#!/usr/bin/env bash
set -e
export DOTNET_ROOT="/home/passp/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
dotnet --version
dotnet test ConfigMigrator.Tests/ --verbosity normal
