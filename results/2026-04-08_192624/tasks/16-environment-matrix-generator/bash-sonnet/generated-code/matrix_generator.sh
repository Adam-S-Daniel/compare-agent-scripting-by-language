#!/usr/bin/env bash
# matrix_generator.sh - Generate GitHub Actions strategy.matrix JSON
#
# Usage: matrix_generator.sh <config.json>
#
# Config JSON fields:
#   os                (required) - array of OS names
#   language_versions (required) - array of language version strings
#   feature_flags     (required) - array of feature flag names
#   exclude           (optional) - array of partial objects to exclude from matrix
#   include_extra     (optional) - array of extra combinations to add
#   fail_fast         (optional) - boolean (default: omitted)
#   max_parallel      (optional) - integer max parallel jobs (default: omitted)
#   max_size          (optional) - integer max matrix size (default: 256)

set -euo pipefail

# Default maximum matrix size (GitHub Actions hard limit is 256)
DEFAULT_MAX_SIZE=256

# Print error message to stderr and exit with code 1
die() {
    echo "ERROR: $*" >&2
    exit 1
}

# Validate required argument
if [[ $# -ne 1 ]]; then
    die "Usage: $0 <config.json>"
fi

CONFIG_FILE="$1"

# Validate file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    die "Config file not found: $CONFIG_FILE"
fi

# Validate JSON is parseable
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    die "Invalid JSON in config file: $CONFIG_FILE"
fi

# Validate required fields exist
if ! jq -e 'has("os")' "$CONFIG_FILE" > /dev/null 2>&1; then
    die "Config missing required field: os"
fi

if ! jq -e 'has("language_versions")' "$CONFIG_FILE" > /dev/null 2>&1; then
    die "Config missing required field: language_versions"
fi

if ! jq -e 'has("feature_flags")' "$CONFIG_FILE" > /dev/null 2>&1; then
    die "Config missing required field: feature_flags"
fi

# Read optional max_size (default 256)
MAX_SIZE=$(jq -r "if has(\"max_size\") then .max_size else $DEFAULT_MAX_SIZE end" "$CONFIG_FILE")

# Generate the complete matrix using jq
# Uses inline approach (no function closures with arguments) to avoid jq scoping issues
MATRIX=$(jq -n \
    --slurpfile config "$CONFIG_FILE" \
    --argjson max_size "$MAX_SIZE" \
    '
    # Extract config
    $config[0] as $cfg |
    $cfg.os as $os_list |
    $cfg.language_versions as $lang_list |
    $cfg.feature_flags as $flag_list |
    ($cfg.exclude // []) as $excludes |
    ($cfg.include_extra // []) as $extras |
    ($cfg | if has("fail_fast") then .fail_fast else null end) as $fail_fast |
    ($cfg | if has("max_parallel") then .max_parallel else null end) as $max_parallel |

    # Generate Cartesian product: os x language_versions x feature_flags
    [
        $os_list[] as $os |
        $lang_list[] as $ver |
        $flag_list[] as $flag |
        {"os": $os, "language_version": $ver, "feature_flag": $flag}
    ] as $base_combos |

    # Apply exclude rules: remove any combination that matches ALL fields in an exclude entry
    [
        $base_combos[] |
        . as $combo |
        select(
            ($excludes | any(
                . as $exc |
                # A combination matches an exclude rule if ALL keys in the rule match
                ($exc | keys_unsorted | all(
                    . as $k |
                    $combo[$k] == $exc[$k]
                ))
            )) | not
        )
    ] as $filtered |

    # Append extra include entries
    ($filtered + $extras) as $all_combos |

    # Validate matrix size against maximum
    if ($all_combos | length) > $max_size then
        error("Matrix size \($all_combos | length) exceeds maximum allowed size of \($max_size)")
    else . end |

    # Build the output object with required include array
    {"include": $all_combos} |

    # Conditionally add fail-fast (use GitHub Actions hyphenated key name)
    if $fail_fast != null then . + {"fail-fast": $fail_fast} else . end |

    # Conditionally add max-parallel
    if $max_parallel != null then . + {"max-parallel": $max_parallel} else . end
    ')

echo "$MATRIX"
