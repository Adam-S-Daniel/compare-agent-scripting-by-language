#!/bin/bash
# syntax-check.sh — PostToolUse hook for Claude Code
# Runs a syntax/type checker after Write/Edit operations on code files.
# Outputs JSON with additionalContext if errors are found.

set -euo pipefail

# Parse stdin JSON using Python (jq not guaranteed available)
eval "$(python3 -c "
import json, sys
data = json.load(sys.stdin)
tool = data.get('tool_name', '')
fp = (data.get('tool_input') or {}).get('file_path', '')
print(f'TOOL_NAME={tool!r}')
print(f'FILE_PATH={fp!r}')
")"

# Only check Write and Edit operations
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
    exit 0
fi

# Skip if no file path or file doesn't exist
if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
    exit 0
fi

EXT="${FILE_PATH##*.}"
ERRORS=""

case "$EXT" in
    cs)
        # C# file-based app — dotnet run compiles first, so we can catch errors
        # Use a subshell to avoid polluting environment
        ERRORS=$(dotnet build "$FILE_PATH" 2>&1 | grep -E "error CS" | head -10) || true
        ;;
    ts|tsx)
        # TypeScript — bun strips types, so use tsc for real type checking
        ERRORS=$(bunx tsc --noEmit --strict "$FILE_PATH" 2>&1 | grep -E "error TS" | head -10) || true
        ;;
    fsx)
        # F# script — dotnet fsi will show compilation errors
        ERRORS=$(dotnet fsi "$FILE_PATH" 2>&1 | grep -E "error FS" | head -10) || true
        ;;
    ps1|psm1)
        # PowerShell — PSScriptAnalyzer if available
        ERRORS=$(pwsh -NoProfile -Command "
            if (Get-Module -ListAvailable PSScriptAnalyzer -EA SilentlyContinue) {
                Invoke-ScriptAnalyzer -Path '$FILE_PATH' -Severity Error,Warning |
                    ForEach-Object { \"\$(\$_.Severity): \$(\$_.Message) (Line \$(\$_.Line))\" } |
                    Select-Object -First 10
            }
        " 2>&1) || true
        ;;
    *)
        exit 0
        ;;
esac

# If errors found, output as additionalContext JSON
if [[ -n "$ERRORS" ]]; then
    python3 -c "
import json
errors = '''$ERRORS'''
print(json.dumps({
    'additionalContext': '⚠️ SYNTAX/TYPE ERRORS detected in the file you just wrote. Fix these before running:\n' + errors
}))
"
fi

exit 0
