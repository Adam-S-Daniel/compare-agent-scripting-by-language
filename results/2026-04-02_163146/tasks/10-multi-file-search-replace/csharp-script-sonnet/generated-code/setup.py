#!/usr/bin/env python3
"""
Install .NET 10 SDK and run tests.
"""
import os
import subprocess
import sys
import urllib.request

def run(cmd, **kwargs):
    print(f">>> {' '.join(cmd)}", flush=True)
    result = subprocess.run(cmd, **kwargs)
    if result.returncode != 0:
        sys.exit(f"Command failed with code {result.returncode}")
    return result

# Check if dotnet is already installed
dotnet = None
for candidate in [
    "dotnet",
    os.path.expanduser("~/.dotnet/dotnet"),
    "/usr/bin/dotnet",
    "/usr/local/bin/dotnet",
]:
    try:
        r = subprocess.run([candidate, "--version"], capture_output=True, text=True)
        if r.returncode == 0:
            dotnet = candidate
            print(f"Found dotnet at: {candidate} (version {r.stdout.strip()})")
            break
    except FileNotFoundError:
        continue

if dotnet is None:
    print("dotnet not found, installing via dotnet-install.sh ...")
    script_path = "/tmp/dotnet-install.sh"
    install_dir = os.path.expanduser("~/.dotnet")

    # Download the install script
    url = "https://dot.net/v1/dotnet-install.sh"
    print(f"Downloading {url} ...")
    urllib.request.urlretrieve(url, script_path)
    os.chmod(script_path, 0o755)

    # Run the install script
    run(["bash", script_path, "--channel", "10.0", "--install-dir", install_dir])

    dotnet = os.path.join(install_dir, "dotnet")
    os.environ["DOTNET_ROOT"] = install_dir
    os.environ["PATH"] = install_dir + os.pathsep + os.environ.get("PATH", "")
    print(f"dotnet installed at {dotnet}")

# Run tests
workspace = os.path.dirname(os.path.abspath(__file__))
test_project = os.path.join(workspace, "SearchReplace.Tests")

print(f"\n=== Running: dotnet test {test_project} ===")
run([dotnet, "test", test_project, "-v", "normal"])
print("\nAll tests passed!")
