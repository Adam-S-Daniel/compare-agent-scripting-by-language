#!/usr/bin/env python3
"""Download and install .NET 10 SDK, then run tests."""
import os
import subprocess
import urllib.request

# Download dotnet install script
print("Downloading .NET install script...")
urllib.request.urlretrieve(
    "https://dot.net/v1/dotnet-install.sh",
    "/tmp/dotnet-install.sh"
)
os.chmod("/tmp/dotnet-install.sh", 0o755)

# Install .NET 10
print("Installing .NET 10 SDK...")
result = subprocess.run(
    ["/tmp/dotnet-install.sh", "--channel", "10.0"],
    capture_output=True, text=True
)
print(result.stdout[-500:] if len(result.stdout) > 500 else result.stdout)
if result.returncode != 0:
    print("ERROR:", result.stderr[-200:])
    exit(1)

# Set PATH
dotnet_root = os.path.expanduser("~/.dotnet")
os.environ["DOTNET_ROOT"] = dotnet_root
os.environ["PATH"] = f"{dotnet_root}:{os.environ['PATH']}"

# Verify installation
ver = subprocess.run(["dotnet", "--version"], capture_output=True, text=True)
print(f"dotnet version: {ver.stdout.strip()}")

# Run tests
print("\n=== Running Tests ===")
test_result = subprocess.run(
    ["dotnet", "test", "DirSync.Tests/", "--logger", "console;verbosity=normal"],
    capture_output=False
)
exit(test_result.returncode)
