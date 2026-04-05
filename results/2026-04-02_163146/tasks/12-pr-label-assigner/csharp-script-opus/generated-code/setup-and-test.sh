#!/bin/bash
# Setup .NET 10 SDK and run tests
set -e

# Install .NET SDK if not present
if ! command -v dotnet &>/dev/null && [ ! -f "$HOME/.dotnet/dotnet" ]; then
    echo "Installing .NET 10 SDK..."
    curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
    chmod +x /tmp/dotnet-install.sh
    /tmp/dotnet-install.sh --channel 10.0 --install-dir "$HOME/.dotnet"
fi

export PATH="$HOME/.dotnet:$PATH"
echo "Using dotnet version: $(dotnet --version)"

# Run tests
echo ""
echo "=== Running Tests ==="
dotnet test PrLabelAssigner.Tests/ --verbosity normal

# Run the main app
echo ""
echo "=== Running Main App ==="
dotnet run PrLabelAssigner.cs
