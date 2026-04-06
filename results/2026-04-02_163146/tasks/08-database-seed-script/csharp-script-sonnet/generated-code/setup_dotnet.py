#!/usr/bin/env python3
"""
setup_dotnet.py — Downloads and installs the .NET 10 SDK.
Run with: python3 setup_dotnet.py
"""
import urllib.request
import subprocess
import os
import stat
import sys

INSTALL_DIR = os.path.expanduser("~/.dotnet")
CHANNEL = "10.0"
INSTALL_SCRIPT_URL = "https://dot.net/v1/dotnet-install.sh"
INSTALL_SCRIPT_PATH = "/tmp/dotnet-install.sh"

def main():
    print(f"Downloading .NET install script from {INSTALL_SCRIPT_URL}...")
    urllib.request.urlretrieve(INSTALL_SCRIPT_URL, INSTALL_SCRIPT_PATH)

    # Make executable
    os.chmod(INSTALL_SCRIPT_PATH, os.stat(INSTALL_SCRIPT_PATH).st_mode | stat.S_IEXEC)

    print(f"Installing .NET {CHANNEL} to {INSTALL_DIR}...")
    result = subprocess.run(
        ["bash", INSTALL_SCRIPT_PATH, "--channel", CHANNEL, "--install-dir", INSTALL_DIR],
        check=True
    )

    dotnet_path = os.path.join(INSTALL_DIR, "dotnet")
    result = subprocess.run([dotnet_path, "--version"], capture_output=True, text=True)
    print(f"Installed .NET version: {result.stdout.strip()}")
    print()
    print("Add to PATH:")
    print(f"  export PATH=\"{INSTALL_DIR}:$PATH\"")
    print(f"  export DOTNET_ROOT=\"{INSTALL_DIR}\"")

if __name__ == "__main__":
    main()
