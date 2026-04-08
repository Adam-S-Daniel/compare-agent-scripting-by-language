#!/usr/bin/env python3
"""PostToolUse hook: runs syntax/type checking after Write/Edit on code files.

Receives JSON on stdin from Claude Code's hook system.
Outputs JSON with 'additionalContext' if compilation errors are found,
so the agent sees diagnostics before its next turn.
"""

import json
import os
import subprocess
import sys


def main():
    data = json.load(sys.stdin)

    tool_name = data.get("tool_name", "")
    if tool_name not in ("Write", "Edit"):
        return

    tool_input = data.get("tool_input") or {}
    file_path = tool_input.get("file_path", "")
    if not file_path or not os.path.isfile(file_path):
        return

    ext = file_path.rsplit(".", 1)[-1].lower() if "." in file_path else ""

    errors = ""

    if ext == "py":
        # Python — py_compile catches syntax errors
        try:
            result = subprocess.run(
                ["python3", "-m", "py_compile", file_path],
                capture_output=True, text=True, timeout=10,
            )
            if result.returncode != 0:
                errors = result.stderr.strip()
                # Limit to first 10 lines
                errors = "\n".join(errors.splitlines()[:10])
        except Exception:
            pass

    elif ext == "sh":
        # Shell — bash -n for syntax, shellcheck for lint
        try:
            result = subprocess.run(
                ["bash", "-n", file_path],
                capture_output=True, text=True, timeout=10,
            )
            if result.returncode != 0:
                errors = result.stderr.strip()
        except Exception:
            pass

        if not errors:
            try:
                result = subprocess.run(
                    ["shellcheck", "-f", "gcc", file_path],
                    capture_output=True, text=True, timeout=10,
                )
                error_lines = [
                    l for l in result.stdout.splitlines()
                    if ": error:" in l or ": warning:" in l
                ]
                errors = "\n".join(error_lines[:10])
            except FileNotFoundError:
                pass  # shellcheck not installed — skip lint
            except Exception:
                pass

    elif ext in ("yml", "yaml"):
        # YAML — actionlint for GitHub Actions workflow files only
        if ".github/workflows/" in file_path or ".github\\workflows\\" in file_path:
            try:
                result = subprocess.run(
                    ["actionlint", file_path],
                    capture_output=True, text=True, timeout=10,
                )
                if result.returncode != 0:
                    errors = result.stdout.strip() or result.stderr.strip()
                    errors = "\n".join(errors.splitlines()[:10])
            except FileNotFoundError:
                pass  # actionlint not installed — skip
            except Exception:
                pass

    elif ext == "cs":
        # C# file-based apps — dotnet build catches compile errors
        try:
            result = subprocess.run(
                ["dotnet", "build", file_path],
                capture_output=True, text=True, timeout=15,
            )
            error_lines = [
                l for l in result.stderr.splitlines() + result.stdout.splitlines()
                if "error CS" in l
            ]
            errors = "\n".join(error_lines[:10])
        except Exception:
            pass

    elif ext in ("ts", "tsx"):
        # TypeScript — bun strips types, so use tsc for real checking
        try:
            result = subprocess.run(
                ["bunx", "tsc", "--noEmit", file_path],
                capture_output=True, text=True, timeout=15,
            )
            error_lines = [
                l for l in result.stdout.splitlines() + result.stderr.splitlines()
                if "error TS" in l
            ]
            errors = "\n".join(error_lines[:10])
        except Exception:
            pass

    elif ext == "fsx":
        # F# script — dotnet fsi shows compile errors
        try:
            result = subprocess.run(
                ["dotnet", "fsi", file_path],
                capture_output=True, text=True, timeout=15,
            )
            error_lines = [
                l for l in result.stderr.splitlines() + result.stdout.splitlines()
                if "error FS" in l
            ]
            errors = "\n".join(error_lines[:10])
        except Exception:
            pass

    elif ext in ("ps1", "psm1"):
        # PowerShell — PSScriptAnalyzer
        try:
            ps_cmd = (
                "if (Get-Module -ListAvailable PSScriptAnalyzer -EA SilentlyContinue) {"
                f"  Invoke-ScriptAnalyzer -Path '{file_path}' -Severity Error,Warning |"
                "    ForEach-Object { \"$($_.Severity): $($_.Message) (Line $($_.Line))\" } |"
                "    Select-Object -First 10"
                "}"
            )
            result = subprocess.run(
                ["pwsh", "-NoProfile", "-Command", ps_cmd],
                capture_output=True, text=True, timeout=15,
            )
            errors = result.stdout.strip()
        except Exception:
            pass

    if errors:
        output = {
            "additionalContext": (
                "⚠️ SYNTAX/TYPE ERRORS detected in the file you just wrote. "
                "Fix these before running:\n" + errors
            )
        }
        json.dump(output, sys.stdout)


if __name__ == "__main__":
    main()
