#!/usr/bin/env python3
"""Download and install .NET 10 SDK."""
import urllib.request
import os
import subprocess
import stat

INSTALL_SCRIPT = "/tmp/dotnet-install.sh"
DOTNET_DIR = os.path.expanduser("~/.dotnet")

print("Downloading .NET install script...")
urllib.request.urlretrieve("https://dot.net/v1/dotnet-install.sh", INSTALL_SCRIPT)
os.chmod(INSTALL_SCRIPT, os.stat(INSTALL_SCRIPT).st_mode | stat.S_IEXEC)
print("Running installer...")
subprocess.run([INSTALL_SCRIPT, "--channel", "10.0", "--install-dir", DOTNET_DIR], check=True)
dotnet = os.path.join(DOTNET_DIR, "dotnet")
result = subprocess.run([dotnet, "--version"], capture_output=True, text=True)
print(f".NET SDK installed: {result.stdout.strip()}")
