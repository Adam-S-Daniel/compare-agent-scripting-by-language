#!/bin/bash
# Install .NET 10 SDK and run tests
# This script installs dotnet if not present, then runs the test suite

set -e

# Install dotnet if not available
if ! command -v dotnet &>/dev/null; then
    echo "dotnet not found, installing..."
    # Try apt-get first (Debian/Ubuntu)
    if command -v apt-get &>/dev/null; then
        # Add Microsoft package repository
        wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
        sudo dpkg -i /tmp/packages-microsoft-prod.deb
        sudo apt-get update
        sudo apt-get install -y dotnet-sdk-10.0
    else
        # Fall back to the official install script
        curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
        bash /tmp/dotnet-install.sh --channel 10.0 --install-dir "$HOME/.dotnet"
        export DOTNET_ROOT="$HOME/.dotnet"
        export PATH="$HOME/.dotnet:$PATH"
    fi
fi

echo "dotnet version: $(dotnet --version)"

# Run tests
echo ""
echo "=== Running Tests ==="
dotnet test SearchReplace.Tests/ -v normal

echo ""
echo "=== All tests passed! ==="
