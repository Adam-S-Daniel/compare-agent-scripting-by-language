#!/usr/bin/env bash
# PR Label Assigner
# Applies labels to a PR based on configurable path-to-label mapping rules.
# Supports glob patterns (*, **), multiple labels per file, and priority ordering.

set -euo pipefail

# ── Built-in mock file list for testing ─────────────────────────────────────
MOCK_FILES=(
  "docs/README.md"
  "docs/api/guide.md"
  "src/api/routes.sh"
  "src/api/auth.sh"
  "src/util.test.sh"
  "lib/parser.test.js"
  "src/main.sh"
  ".github/workflows/ci.yml"
)

# ── Glob matching ─────────────────────────────────────────────────────────────
# Converts a glob pattern to an extended regex, then tests the path against it.
# Supports: * (single segment), ** (any depth), ? (single char)
glob_to_regex() {
  local pattern="$1"
  local regex=""
  local i=0
  local len="${#pattern}"

  while [ "$i" -lt "$len" ]; do
    local char="${pattern:$i:1}"
    case "$char" in
      '*')
        # Check for **
        if [ "${pattern:$i:2}" = "**" ]; then
          i=$((i + 2))
          # ** followed by / means "any path prefix including none"
          if [ "${pattern:$i:1}" = "/" ]; then
            regex+="(.+/)?"
            i=$((i + 1))
          else
            regex+=".*"
          fi
          continue
        else
          # Single * — match anything except /
          regex+="[^/]*"
        fi
        ;;
      '?')
        regex+="[^/]"
        ;;
      '.')
        regex+="[.]"
        ;;
      '+' | '(' | ')' | '{' | '}' | '^' | '$' | '|')
        regex+="[$char]"
        ;;
      '[')
        # Pass character classes through as-is until closing ]
        local rest="${pattern:$i}"
        local bracket_content="${rest%%]*}"
        local bracket="${bracket_content}]"
        regex+="$bracket"
        i=$((i + ${#bracket}))
        continue
        ;;
      *)
        regex+="$char"
        ;;
    esac
    i=$((i + 1))
  done

  printf '%s' "$regex"
}

glob_match() {
  local pattern="$1"
  local path="$2"
  local regex

  # If pattern contains no '/', match against the basename only.
  # This lets "*.test.*" match "src/util.test.sh" (common labeler convention).
  if [[ "$pattern" != */* ]]; then
    local basename="${path##*/}"
    regex=$(glob_to_regex "$pattern")
    [[ "$basename" =~ ^${regex}$ ]]
  else
    regex=$(glob_to_regex "$pattern")
    [[ "$path" =~ ^${regex}$ ]]
  fi
}

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat >&2 <<'EOF'
Usage: pr_label_assigner.sh --config <rules.conf> --files <files.txt> [--priority] [--mock]

Options:
  --config <file>   Path to rules config file (pattern:label, one per line)
  --files <file>    Path to file containing changed file paths (one per line)
  --mock            Use built-in mock file list instead of --files
  --priority        Output labels in rule-priority order (first rule = highest priority)
  --help            Show this help

Config file format:
  docs/**:documentation
  src/api/**:api
  *.test.*:tests
EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────
CONFIG_FILE=""
FILES_FILE=""
USE_MOCK=false
PRIORITY_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --files)
      FILES_FILE="$2"
      shift 2
      ;;
    --mock)
      USE_MOCK=true
      shift
      ;;
    --priority)
      # Priority mode: labels are output in rule definition order (first rule = highest priority).
      # This is the default behaviour; the flag is accepted for explicit documentation.
      PRIORITY_MODE=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
if [[ -z "$CONFIG_FILE" ]]; then
  echo "Error: --config is required" >&2
  usage
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

if [[ "$USE_MOCK" = false ]]; then
  if [[ -z "$FILES_FILE" ]]; then
    echo "Error: --files or --mock is required" >&2
    usage
    exit 1
  fi
  if [[ ! -f "$FILES_FILE" ]]; then
    echo "Error: Files list not found: $FILES_FILE" >&2
    exit 1
  fi
fi

# PRIORITY_MODE controls whether we note it in verbose output (always rule order)
if [[ "$PRIORITY_MODE" = true ]]; then
  : # Labels are inherently output in rule-definition (priority) order
fi

# ── Load rules (pattern:label lines, strip comments and blanks) ───────────────
declare -a RULE_PATTERNS=()
declare -a RULE_LABELS=()

while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip blank lines and comments
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  # Split on first colon
  pattern="${line%%:*}"
  label="${line#*:}"
  [[ -z "$pattern" || -z "$label" ]] && continue
  RULE_PATTERNS+=("$pattern")
  RULE_LABELS+=("$label")
done < "$CONFIG_FILE"

# ── Load file list ─────────────────────────────────────────────────────────────
declare -a CHANGED_FILES=()

if [[ "$USE_MOCK" = true ]]; then
  CHANGED_FILES=("${MOCK_FILES[@]}")
else
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    CHANGED_FILES+=("$line")
  done < "$FILES_FILE"
fi

# ── Match rules against files ─────────────────────────────────────────────────
# Collect labels in rule order (priority) and deduplicate while preserving order.

declare -A SEEN_LABELS=()
declare -a ORDERED_LABELS=()

for i in "${!RULE_PATTERNS[@]}"; do
  pattern="${RULE_PATTERNS[$i]}"
  label="${RULE_LABELS[$i]}"

  for file in "${CHANGED_FILES[@]}"; do
    if glob_match "$pattern" "$file"; then
      if [[ -z "${SEEN_LABELS[$label]+x}" ]]; then
        SEEN_LABELS[$label]=1
        ORDERED_LABELS+=("$label")
      fi
      break  # No need to check more files once the rule matches any file
    fi
  done
done

# ── Output ────────────────────────────────────────────────────────────────────
if [[ ${#ORDERED_LABELS[@]} -eq 0 ]]; then
  exit 0
fi

# Join with comma and output on a single line
(IFS=','; echo "${ORDERED_LABELS[*]}")
