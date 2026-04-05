#!/bin/bash
# Install .NET SDK using Microsoft's official install script
# This installs to ~/.dotnet by default (no sudo needed)

set -e

# Download the install script
curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
chmod +x /tmp/dotnet-install.sh

# Install .NET 10.0 (preview) - fall back to 9.0 if not available
/tmp/dotnet-install.sh --channel 10.0 || /tmp/dotnet-install.sh --channel 9.0

# Add to PATH
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"

echo "dotnet installed at: $(which dotnet)"
dotnet --version
