#!/bin/bash
set -e

# Ensure .NET SDK is available
if ! command -v dotnet &>/dev/null; then
    if [ -f "$HOME/.dotnet/dotnet" ]; then
        export PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"
        export DOTNET_ROOT="$HOME/.dotnet"
    else
        echo "Installing .NET 10 SDK..."
        wget -q -O /tmp/dotnet-install.sh https://dot.net/v1/dotnet-install.sh
        chmod +x /tmp/dotnet-install.sh
        /tmp/dotnet-install.sh --channel 10.0 --install-dir "$HOME/.dotnet"
        export PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"
        export DOTNET_ROOT="$HOME/.dotnet"
    fi
fi

echo "Using dotnet version: $(dotnet --version)"

# Run the test project
cd "$(dirname "$0")"
dotnet test LicenseChecker.Tests/ --verbosity normal
