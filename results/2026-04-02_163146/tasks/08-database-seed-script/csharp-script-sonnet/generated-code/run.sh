#!/usr/bin/env bash
# run.sh — Install .NET 10 SDK (if needed) and run tests + main script.

set -e

DOTNET_INSTALL_DIR="${DOTNET_INSTALL_DIR:-$HOME/.dotnet}"
DOTNET="$DOTNET_INSTALL_DIR/dotnet"

# ── Install .NET 10 if not already present ─────────────────────────────────
if ! "$DOTNET" --version 2>/dev/null | grep -q "^10\." && ! dotnet --version 2>/dev/null | grep -q "^10\."; then
    echo "Installing .NET 10 SDK..."
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
    bash /tmp/dotnet-install.sh --channel 10.0 --install-dir "$DOTNET_INSTALL_DIR"
    export PATH="$DOTNET_INSTALL_DIR:$PATH"
    echo "Installed: $($DOTNET --version)"
else
    # dotnet might be on PATH already
    DOTNET=$(which dotnet 2>/dev/null || echo "$DOTNET")
    export PATH="$DOTNET_INSTALL_DIR:$PATH"
    echo "Using .NET: $($DOTNET --version)"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Run tests (TDD — verifies all functionality) ───────────────────────────
echo ""
echo "=== Running tests ==="
"$DOTNET" test DatabaseSeeder.Tests/ --verbosity normal

echo ""
echo "=== Running standalone script ==="
# Run the file-based app (creates seed.db in the current directory)
"$DOTNET" run --project DatabaseSeeder.Library/ 2>/dev/null || \
    "$DOTNET" run DatabaseSeeder.cs 2>/dev/null || \
    echo "Note: Use 'dotnet run' from the DatabaseSeeder.Library directory to run the seeder."
