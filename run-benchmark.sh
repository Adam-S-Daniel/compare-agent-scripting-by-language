#!/bin/bash
# run-benchmark.sh — Launch the full benchmark on a Sprite (sprites.dev) or any clean VM.
#
# Usage:
#   ./run-benchmark.sh                    # Fresh run, all tasks/models/modes
#   ./run-benchmark.sh --resume <dir>     # Resume a previous run
#
# Prerequisites: python3, claude CLI (with API key configured)
# This script will install: pwsh (PowerShell), .NET 10 SDK

set -eo pipefail
cd "$(dirname "$0")"

echo "=== Benchmark Runner Setup ==="

# Check prerequisites
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found"; exit 1; }
command -v claude >/dev/null 2>&1 || { echo "ERROR: claude CLI not found"; exit 1; }

# Check claude CLI works
echo "Testing claude CLI..."
claude -p "say ok" --model claude-sonnet-4-6 --output-format json 2>/dev/null | python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
# Output may be a list (stream-json) or dict
if isinstance(data, list):
    result_items = [e for e in data if e.get('type') == 'result']
    assistant_items = [e for e in data if e.get('type') == 'assistant']
    if result_items and result_items[0].get('is_error'):
        print(f'ERROR: claude CLI failed')
        sys.exit(1)
    msg = assistant_items[0]['message']['content'][0]['text'] if assistant_items else 'ok'
    print(f'claude CLI OK: {msg[:50]}')
elif isinstance(data, dict):
    if data.get('is_error'):
        print(f'ERROR: claude CLI failed')
        sys.exit(1)
    print(f'claude CLI OK: {data.get(\"result\",\"\")[:50]}')
" || { echo "ERROR: claude CLI test failed"; exit 1; }

echo ""
echo "=== Installing Runtime Prerequisites ==="

# Install PowerShell if not present
if ! command -v pwsh &>/dev/null; then
    echo "Installing PowerShell..."
    if command -v apt-get &>/dev/null; then
        # Ubuntu/Debian
        sudo apt-get update -qq
        sudo apt-get install -y -qq wget apt-transport-https software-properties-common
        source /etc/os-release
        wget -q "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb"
        sudo dpkg -i packages-microsoft-prod.deb
        rm packages-microsoft-prod.deb
        sudo apt-get update -qq
        sudo apt-get install -y -qq powershell
    else
        echo "WARNING: Cannot auto-install PowerShell on this OS. Install manually."
    fi
fi

if command -v pwsh &>/dev/null; then
    echo "PowerShell: $(pwsh --version)"
    # Install Pester if not present
    pwsh -Command "if (-not (Get-Module -ListAvailable -Name Pester | Where-Object Version -ge '5.0')) { Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser }" 2>/dev/null
    echo "Pester: $(pwsh -Command '(Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1).Version.ToString()' 2>/dev/null || echo 'not found')"
else
    echo "WARNING: PowerShell not available — PS modes will fail"
fi

# Install .NET 10 SDK if not present
if ! command -v dotnet &>/dev/null || ! dotnet --list-sdks 2>/dev/null | grep -q "^10\."; then
    echo "Installing .NET 10 SDK..."
    if [ -f /etc/os-release ]; then
        # Use the official install script
        wget -q https://dot.net/v1/dotnet-install.sh -O /tmp/dotnet-install.sh
        chmod +x /tmp/dotnet-install.sh
        /tmp/dotnet-install.sh --channel 10.0 --install-dir "$HOME/.dotnet"
        rm /tmp/dotnet-install.sh
        export DOTNET_ROOT="$HOME/.dotnet"
        export PATH="$DOTNET_ROOT:$PATH"
        # Persist for the agent subprocesses
        if ! grep -q 'DOTNET_ROOT' "$HOME/.bashrc" 2>/dev/null; then
            echo 'export DOTNET_ROOT="$HOME/.dotnet"' >> "$HOME/.bashrc"
            echo 'export PATH="$DOTNET_ROOT:$PATH"' >> "$HOME/.bashrc"
        fi
    else
        echo "WARNING: Cannot auto-install .NET SDK on this OS. Install manually."
    fi
fi

if command -v dotnet &>/dev/null; then
    echo ".NET SDK: $(dotnet --version)"
    # Verify file-based apps work
    echo 'Console.WriteLine("dotnet-ok");' > /tmp/_dotnet_test.cs
    if dotnet run /tmp/_dotnet_test.cs 2>/dev/null | grep -q "dotnet-ok"; then
        echo ".NET 10 file-based apps: OK"
    else
        echo "WARNING: dotnet run file.cs not working — C# mode may have issues"
    fi
    rm -f /tmp/_dotnet_test.cs
else
    echo "WARNING: .NET SDK not available — C# mode will fail"
fi

echo ""
echo "=== Starting Benchmark (v2) ==="
echo "Tasks: 18 scripting tasks"
echo "Models: claude-opus-4-6, claude-sonnet-4-6"
echo "Modes: default, powershell, powershell-strict, csharp-script"
echo "Total runs: 144"
echo "Permission mode: --dangerously-skip-permissions"
echo ""
echo "Results will be pushed to git every 60 seconds."
echo "Expected duration: ~8-16 hours"
echo "Expected cost: ~$80-160"
echo ""

# Run the benchmark
exec python3 runner.py \
    "$@" \
    --tasks all \
    --models opus,sonnet \
    --modes default,powershell,powershell-strict,csharp-script
