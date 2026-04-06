#!/usr/bin/env python3
"""Download and install .NET 10 SDK in the local workspace directory."""

import os
import subprocess
import sys
import urllib.request

WORKSPACE = os.path.dirname(os.path.abspath(__file__))
DOTNET_DIR = os.path.join(WORKSPACE, ".dotnet")
INSTALL_SCRIPT = os.path.join(WORKSPACE, "dotnet-install.sh")

def main():
    # Check if already installed
    dotnet_bin = os.path.join(DOTNET_DIR, "dotnet")
    if os.path.exists(dotnet_bin):
        result = subprocess.run([dotnet_bin, "--version"], capture_output=True, text=True)
        print(f".NET already installed: {result.stdout.strip()}")
        return

    # Download install script
    print("Downloading .NET install script...")
    url = "https://dot.net/v1/dotnet-install.sh"
    urllib.request.urlretrieve(url, INSTALL_SCRIPT)
    os.chmod(INSTALL_SCRIPT, 0o755)

    # Install .NET 10
    print(f"Installing .NET 10 to {DOTNET_DIR}...")
    result = subprocess.run(
        ["bash", INSTALL_SCRIPT, "--channel", "10.0", "--install-dir", DOTNET_DIR],
        capture_output=False
    )
    if result.returncode != 0:
        print("Installation failed!", file=sys.stderr)
        sys.exit(1)

    # Verify
    result = subprocess.run([dotnet_bin, "--version"], capture_output=True, text=True)
    print(f"Installed .NET: {result.stdout.strip()}")

if __name__ == "__main__":
    main()
