#!/usr/bin/env python3
"""Run dotnet tests via Python to work around PATH issues."""

import subprocess
import os
import sys

DOTNET = "/home/passp/.dotnet/dotnet"
env = dict(os.environ)
env["DOTNET_ROOT"] = "/home/passp/.dotnet"
env["PATH"] = "/home/passp/.dotnet:" + env.get("PATH", "")

print("=== Running dotnet test ===")
r = subprocess.run(
    [DOTNET, "test", "MatrixGenerator.Tests/", "-v", "normal"],
    env=env,
    text=True
)
if r.returncode != 0:
    print("Tests FAILED", file=sys.stderr)
    sys.exit(r.returncode)

print()
print("=== Running demo (generate-matrix.cs) ===")
r2 = subprocess.run(
    [DOTNET, "run", "generate-matrix.cs"],
    env=env,
    text=True
)
sys.exit(r2.returncode)
