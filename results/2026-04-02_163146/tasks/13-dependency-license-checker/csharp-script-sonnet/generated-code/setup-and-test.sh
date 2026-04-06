#!/bin/bash
# Install .NET 10 SDK and run tests

set -e

echo "=== Checking for dotnet ==="
if command -v dotnet &>/dev/null; then
    echo "dotnet found: $(dotnet --version)"
else
    echo "dotnet not found, installing..."

    # Try apt first (works on Ubuntu/Debian)
    if command -v apt-get &>/dev/null; then
        # Add Microsoft package repository
        wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
        dpkg -i packages-microsoft-prod.deb
        rm packages-microsoft-prod.deb
        apt-get update
        apt-get install -y dotnet-sdk-10.0
    else
        # Use install script
        curl -fsSL https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh
        chmod +x dotnet-install.sh
        ./dotnet-install.sh --channel 10.0
        export PATH="$HOME/.dotnet:$PATH"
    fi
fi

echo ""
echo "=== Running tests ==="
dotnet test tests/LicenseChecker.Tests/LicenseChecker.Tests.csproj --verbosity normal

echo ""
echo "=== Running demo with package.json fixture ==="
dotnet run --project check-licenses.csproj -- fixtures/package.json

echo ""
echo "=== Running demo with requirements.txt fixture ==="
dotnet run --project check-licenses.csproj -- fixtures/requirements.txt
