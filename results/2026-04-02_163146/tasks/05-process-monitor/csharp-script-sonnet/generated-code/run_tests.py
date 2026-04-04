#!/usr/bin/env python3
"""
Helper script to install .NET 10 if not available, then run tests.
Run with: python3 run_tests.py
"""
import os
import subprocess
import sys
import urllib.request


def find_dotnet():
    """Find dotnet binary, checking PATH and common install locations."""
    # Check PATH first
    for path in os.environ.get("PATH", "").split(":"):
        candidate = os.path.join(path, "dotnet")
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate

    # Common install locations
    home = os.path.expanduser("~")
    candidates = [
        os.path.join(home, ".dotnet", "dotnet"),
        "/usr/bin/dotnet",
        "/usr/local/bin/dotnet",
        "/snap/bin/dotnet",
    ]
    for c in candidates:
        if os.path.isfile(c) and os.access(c, os.X_OK):
            return c

    return None


def install_dotnet():
    """Download and run the official dotnet-install.sh script."""
    print("dotnet not found — installing .NET 10 SDK...")
    install_script = "/tmp/dotnet-install.sh"
    url = "https://dot.net/v1/dotnet-install.sh"

    print(f"Downloading {url}...")
    urllib.request.urlretrieve(url, install_script)
    os.chmod(install_script, 0o755)

    home = os.path.expanduser("~")
    result = subprocess.run(
        ["bash", install_script, "--channel", "10.0"],
        env={**os.environ, "DOTNET_INSTALL_DIR": os.path.join(home, ".dotnet")},
    )
    if result.returncode != 0:
        print("ERROR: dotnet installation failed", file=sys.stderr)
        sys.exit(1)

    dotnet_path = os.path.join(home, ".dotnet", "dotnet")
    if not os.path.isfile(dotnet_path):
        print(f"ERROR: expected dotnet at {dotnet_path}", file=sys.stderr)
        sys.exit(1)

    # Add to PATH for this process
    os.environ["PATH"] = os.path.join(home, ".dotnet") + ":" + os.environ.get("PATH", "")
    os.environ["DOTNET_ROOT"] = os.path.join(home, ".dotnet")
    return dotnet_path


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)

    dotnet = find_dotnet()
    if dotnet is None:
        dotnet = install_dotnet()

    print(f"Using dotnet: {dotnet}")
    version_result = subprocess.run([dotnet, "--version"], capture_output=True, text=True)
    print(f"Version: {version_result.stdout.strip()}")

    print("\nRunning tests...")
    test_result = subprocess.run(
        [dotnet, "test", "ProcessMonitor.Tests/ProcessMonitor.Tests.csproj",
         "--verbosity", "normal"],
    )
    sys.exit(test_result.returncode)


if __name__ == "__main__":
    main()
