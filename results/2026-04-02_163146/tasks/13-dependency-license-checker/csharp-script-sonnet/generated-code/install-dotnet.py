#!/usr/bin/env python3
"""Download and install .NET 10 SDK using Python."""
import urllib.request
import os
import stat
import subprocess
import sys

print("Downloading .NET install script...")
url = "https://dot.net/v1/dotnet-install.sh"
script_path = "/tmp/dotnet-install.sh"

try:
    urllib.request.urlretrieve(url, script_path)
    os.chmod(script_path, stat.S_IRWXU)
    print("Installing .NET 10 SDK...")
    result = subprocess.run(
        [script_path, "--channel", "10.0"],
        capture_output=False
    )
    if result.returncode == 0:
        print("Installation successful!")
        dotnet_path = os.path.expanduser("~/.dotnet")
        print(f"dotnet installed to: {dotnet_path}")
    else:
        print(f"Installation failed with code: {result.returncode}", file=sys.stderr)
        sys.exit(1)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
