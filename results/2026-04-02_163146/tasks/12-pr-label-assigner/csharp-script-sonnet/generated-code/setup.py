#!/usr/bin/env python3
"""Download and install .NET 10 SDK"""
import urllib.request
import os
import subprocess
import sys

# Download dotnet install script
print("Downloading .NET install script...")
urllib.request.urlretrieve(
    'https://dot.net/v1/dotnet-install.sh',
    '/tmp/dotnet-install.sh'
)
os.chmod('/tmp/dotnet-install.sh', 0o755)

# Install .NET 10
dotnet_dir = os.path.expanduser('~/.dotnet')
print(f"Installing .NET 10 to {dotnet_dir}...")
result = subprocess.run(
    ['bash', '/tmp/dotnet-install.sh', '--channel', '10.0', '--install-dir', dotnet_dir],
    capture_output=False
)
if result.returncode != 0:
    print("Installation failed", file=sys.stderr)
    sys.exit(1)

dotnet_path = os.path.join(dotnet_dir, 'dotnet')
print(f"Testing dotnet at {dotnet_path}...")
result = subprocess.run([dotnet_path, '--version'], capture_output=True, text=True)
print(f"Installed: {result.stdout.strip()}")
