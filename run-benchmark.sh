#!/bin/bash
# run-benchmark.sh — Launch the full benchmark on a Sprite (sprites.dev) or any clean VM.
#
# Usage:
#   ./run-benchmark.sh                    # Fresh run, all tasks/models/modes
#   ./run-benchmark.sh --resume <dir>     # Resume a previous run
#
# Prerequisites: python3, claude CLI (with API key configured)

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
d = json.loads(sys.stdin.read())
if d.get('is_error'):
    print(f'ERROR: claude CLI failed: {d.get(\"result\",\"unknown\")}')
    sys.exit(1)
print(f'claude CLI OK: {d.get(\"result\",\"\")[:50]}')
" || { echo "ERROR: claude CLI test failed"; exit 1; }

echo ""
echo "=== Starting Benchmark ==="
echo "Tasks: 18 scripting tasks"
echo "Models: claude-opus-4-6, claude-sonnet-4-6"
echo "Modes: default, powershell, powershell-strict, csharp-script"
echo "Total runs: 144"
echo ""
echo "Results will be pushed to git every 60 seconds."
echo "Expected duration: ~12-20 hours"
echo "Expected cost: ~$100-200"
echo ""

# Run the benchmark
exec python3 runner.py \
    "$@" \
    --tasks all \
    --models opus,sonnet \
    --modes default,powershell,powershell-strict,csharp-script
