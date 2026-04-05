#!/usr/bin/env python3
"""
run_tests.py — Installs .NET 10 if not available, then runs dotnet test.
Usage: python3 run_tests.py
"""
import os
import subprocess
import sys
import urllib.request


def find_dotnet():
    """Search PATH and common install locations for the dotnet binary."""
    for dir_ in os.environ.get("PATH", "").split(":"):
        candidate = os.path.join(dir_, "dotnet")
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    home = os.path.expanduser("~")
    for candidate in [
        os.path.join(home, ".dotnet", "dotnet"),
        "/usr/bin/dotnet",
        "/usr/local/bin/dotnet",
        "/snap/bin/dotnet",
    ]:
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return None


def install_dotnet():
    """Download and run the official dotnet-install.sh script for .NET 10."""
    print("dotnet not found — installing .NET 10 SDK...")
    install_script = "/tmp/dotnet-install.sh"
    print("Downloading dotnet-install.sh ...")
    urllib.request.urlretrieve("https://dot.net/v1/dotnet-install.sh", install_script)
    os.chmod(install_script, 0o755)

    home = os.path.expanduser("~")
    install_dir = os.path.join(home, ".dotnet")
    result = subprocess.run(
        ["bash", install_script, "--channel", "10.0", "--install-dir", install_dir],
        env={**os.environ},
    )
    if result.returncode != 0:
        print("ERROR: dotnet installation failed", file=sys.stderr)
        sys.exit(1)

    dotnet_path = os.path.join(install_dir, "dotnet")
    if not os.path.isfile(dotnet_path):
        print(f"ERROR: expected dotnet at {dotnet_path}", file=sys.stderr)
        sys.exit(1)

    # Update environment for this process
    os.environ["PATH"] = install_dir + ":" + os.environ.get("PATH", "")
    os.environ["DOTNET_ROOT"] = install_dir
    return dotnet_path


def main():
    # Run from the directory containing this script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)

    dotnet = find_dotnet()
    if dotnet is None:
        dotnet = install_dotnet()

    print(f"Using dotnet at: {dotnet}")
    ver = subprocess.run([dotnet, "--version"], capture_output=True, text=True)
    print(f".NET version: {ver.stdout.strip()}")

    print("\n=== Running tests ===")
    result = subprocess.run(
        [dotnet, "test", "ConfigMigrator.Tests/ConfigMigrator.Tests.csproj",
         "--verbosity", "normal"],
    )
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
