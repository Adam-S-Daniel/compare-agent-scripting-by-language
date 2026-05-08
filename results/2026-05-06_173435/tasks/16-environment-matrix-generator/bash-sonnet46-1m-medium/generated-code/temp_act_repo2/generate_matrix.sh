#!/usr/bin/env bash
# generate_matrix.sh
# Generate a GitHub Actions strategy.matrix JSON from a configuration file.
#
# Usage: ./generate_matrix.sh <config.json>
#
# Config format:
#   {
#     "os": [...],            # required: list of OS values
#     "version": [...],       # optional: list of version values
#     "feature_flags": [...], # optional: list of feature flag values
#     "<key>": [...],         # any additional dimension
#     "include": [...],       # optional: extra combinations with additional fields
#     "exclude": [...],       # optional: combinations to remove
#     "max_parallel": <int>,  # optional: GitHub Actions max-parallel
#     "fail_fast": <bool>,    # optional: GitHub Actions fail-fast
#     "max_size": <int>       # optional: max allowed matrix combinations (default 256)
#   }
#
# Output: JSON with keys: include, fail-fast (optional), max-parallel (optional)

set -euo pipefail

main() {
    local config_file="${1:-}"

    # Validate argument
    if [[ -z "$config_file" ]]; then
        echo "Error: config file argument required" >&2
        echo "Usage: $0 <config.json>" >&2
        exit 1
    fi

    if [[ ! -f "$config_file" ]]; then
        echo "Error: config file not found: $config_file" >&2
        exit 1
    fi

    # Delegate all logic to Python for robust JSON handling
    python3 - "$config_file" <<'PYEOF'
import sys
import json
import itertools

RESERVED = {"include", "exclude", "max_parallel", "fail_fast", "max_size"}

def is_reserved(key):
    return key in RESERVED

def load_config(path):
    with open(path) as f:
        return json.load(f)

def get_dimensions(config):
    """Extract matrix dimension keys and their value lists."""
    dims = {}
    for key, val in config.items():
        if not is_reserved(key) and isinstance(val, list):
            dims[key] = val
    return dims

def cartesian_product(dims):
    """Generate all combinations of dimension values."""
    if not dims:
        return [{}]
    keys = list(dims.keys())
    values = [dims[k] for k in keys]
    combos = []
    for combo in itertools.product(*values):
        combos.append(dict(zip(keys, combo)))
    return combos

def matches_exclude(combo, exclude_rule):
    """True if combo matches all fields in exclude_rule."""
    for key, val in exclude_rule.items():
        if str(combo.get(key, "")) != str(val):
            return False
    return True

def apply_excludes(combos, excludes):
    """Remove combinations matching any exclude rule."""
    result = []
    for combo in combos:
        excluded = any(matches_exclude(combo, rule) for rule in excludes)
        if not excluded:
            result.append(combo)
    return result

def merge_includes(combos, includes):
    """
    GitHub Actions include semantics:
    - If an include matches an existing combo on all its keys, merge extra fields in.
    - If it doesn't match any existing combo, add it as a new entry.
    """
    result = [dict(c) for c in combos]

    for inc in includes:
        # Find combos that match all keys present in the include
        merged = False
        for combo in result:
            if all(str(combo.get(k)) == str(v) for k, v in inc.items() if k in combo):
                combo.update(inc)
                merged = True
        if not merged:
            result.append(dict(inc))

    return result

def main():
    config_path = sys.argv[1]
    try:
        config = load_config(config_path)
    except (json.JSONDecodeError, OSError) as e:
        print(f"Error: failed to read config: {e}", file=sys.stderr)
        sys.exit(1)

    # Extract settings
    max_size = int(config.get("max_size", 256))
    max_parallel = config.get("max_parallel")
    fail_fast = config.get("fail_fast")
    excludes = config.get("exclude", [])
    includes = config.get("include", [])

    # Build cartesian product of all dimension keys
    dims = get_dimensions(config)
    combos = cartesian_product(dims)

    # Apply excludes
    combos = apply_excludes(combos, excludes)

    # Merge includes
    combos = merge_includes(combos, includes)

    # Validate size
    if len(combos) > max_size:
        print(
            f"Error: matrix size {len(combos)} exceeds max_size {max_size}. "
            "Reduce dimensions or add exclude rules.",
            file=sys.stderr
        )
        sys.exit(1)

    # Build output
    output = {"include": combos}

    # Preserve exclude rules in output for documentation/auditability
    if excludes:
        output["exclude"] = excludes

    if fail_fast is not None:
        output["fail-fast"] = fail_fast

    if max_parallel is not None:
        output["max-parallel"] = int(max_parallel)

    print(json.dumps(output, indent=2))

main()
PYEOF
}

main "$@"
