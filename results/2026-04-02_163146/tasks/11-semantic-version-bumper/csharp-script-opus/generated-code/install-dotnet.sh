#!/bin/bash
# Install .NET 10 SDK for file-based apps support
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"

if command -v dotnet &>/dev/null && dotnet --version 2>/dev/null | grep -q "^10\."; then
    echo "dotnet 10 already installed"
    dotnet --version
    exit 0
fi

echo "Installing .NET 10 SDK..."
curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 10.0 --quality preview
echo "export DOTNET_ROOT=\"\$HOME/.dotnet\"" >> ~/.bashrc
echo "export PATH=\"\$DOTNET_ROOT:\$PATH\"" >> ~/.bashrc
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"
dotnet --version
