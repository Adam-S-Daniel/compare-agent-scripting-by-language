#!/bin/bash
# run.sh — Install .NET 10 if needed, run tests, then run the analyzer on the sample log.
set -e

WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTNET_DIR="$WORKSPACE/.dotnet"
DOTNET="$DOTNET_DIR/dotnet"

# ── 1. Find or install .NET 10 ────────────────────────────────────────────────

if command -v dotnet &>/dev/null; then
    DOTNET="dotnet"
    echo "Found dotnet in PATH: $(dotnet --version)"
elif [ -f "$DOTNET" ]; then
    echo "Found local .NET: $($DOTNET --version)"
else
    echo "Installing .NET 10 SDK to $DOTNET_DIR ..."
    curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- \
        --channel 10.0 \
        --install-dir "$DOTNET_DIR"
    echo "Installed: $($DOTNET --version)"
fi

# ── 2. Run tests ──────────────────────────────────────────────────────────────

echo ""
echo "=== Running tests ==="
"$DOTNET" test "$WORKSPACE/LogAnalyzer.Tests/" --verbosity normal

# ── 3. Run the analyzer on the sample log ────────────────────────────────────

SAMPLE="$WORKSPACE/LogAnalyzer.Tests/Fixtures/sample.log"
OUTPUT="$WORKSPACE/sample.log.report.json"

echo ""
echo "=== Running analyzer on sample.log ==="
# .NET 10 file-based app: dotnet run <file>.cs [-- args]
"$DOTNET" run "$WORKSPACE/LogAnalyzer.cs" -- "$SAMPLE" "$OUTPUT"

echo ""
echo "Done. JSON report: $OUTPUT"
