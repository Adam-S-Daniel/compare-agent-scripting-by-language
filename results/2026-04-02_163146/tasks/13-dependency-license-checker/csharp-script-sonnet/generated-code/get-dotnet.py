#!/usr/bin/env python3
"""
Install .NET 10 SDK using Python's urllib (no curl/wget needed).
Run: python3 get-dotnet.py
"""
import urllib.request
import os
import stat
import subprocess
import sys

INSTALL_SCRIPT_URL = "https://dot.net/v1/dotnet-install.sh"
SCRIPT_PATH = "/tmp/dotnet-install.sh"
CHANNEL = "10.0"
DOTNET_ROOT = os.path.expanduser("~/.dotnet")


def download_install_script():
    print(f"Downloading from {INSTALL_SCRIPT_URL} ...", flush=True)
    headers = {"User-Agent": "Mozilla/5.0"}
    req = urllib.request.Request(INSTALL_SCRIPT_URL, headers=headers)
    with urllib.request.urlopen(req, timeout=60) as response:
        data = response.read()
    with open(SCRIPT_PATH, "wb") as f:
        f.write(data)
    os.chmod(SCRIPT_PATH, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP)
    print(f"Script saved to {SCRIPT_PATH}", flush=True)


def install_dotnet():
    print(f"Installing .NET {CHANNEL} SDK to {DOTNET_ROOT} ...", flush=True)
    result = subprocess.run(
        ["/bin/bash", SCRIPT_PATH, "--channel", CHANNEL, "--install-dir", DOTNET_ROOT],
        stdout=sys.stdout,
        stderr=sys.stderr,
    )
    return result.returncode


def main():
    if os.path.exists(os.path.join(DOTNET_ROOT, "dotnet")):
        print(f".NET already installed at {DOTNET_ROOT}", flush=True)
        return 0

    try:
        download_install_script()
    except Exception as e:
        print(f"Failed to download: {e}", file=sys.stderr)
        return 1

    rc = install_dotnet()
    if rc == 0:
        dotnet_bin = os.path.join(DOTNET_ROOT, "dotnet")
        print(f"\nSuccess! dotnet installed at: {dotnet_bin}", flush=True)
        print(f"Add to PATH: export PATH=\"{DOTNET_ROOT}:$PATH\"", flush=True)
    else:
        print(f"Installation failed (exit code {rc})", file=sys.stderr)
    return rc


if __name__ == "__main__":
    sys.exit(main())
