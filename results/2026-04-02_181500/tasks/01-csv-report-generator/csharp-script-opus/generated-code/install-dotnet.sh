#!/bin/bash
# Install .NET 10 SDK
curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 10.0 --install-dir /home/user/.dotnet
export PATH="$PATH:/home/user/.dotnet"
dotnet --version
