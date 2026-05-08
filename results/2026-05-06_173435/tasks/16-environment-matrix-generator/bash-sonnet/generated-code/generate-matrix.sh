#!/usr/bin/env bash
# generate-matrix.sh — Environment Matrix Generator
# Reads a JSON config and outputs a GitHub Actions strategy.matrix JSON.
#
# Config keys:
#   os               : array of OS strings
#   language_versions: object mapping language -> array of version strings
#   feature_flags    : object mapping flag -> array of values (any JSON type)
#   include          : array of extra entry objects appended after filtering
#   exclude          : array of objects; any combo matching ALL keys is removed
#   max_parallel     : integer (forwarded to output as "max-parallel")
#   fail_fast        : boolean (forwarded to output as "fail-fast")
#   max_size         : integer, default 256; error if final matrix exceeds this

set -euo pipefail

usage() {
  echo "Usage: $0 <config.json>" >&2
  echo "" >&2
  echo "Generates GitHub Actions strategy.matrix JSON." >&2
  exit 1
}

main() {
  local config_file="${1:-}"

  if [[ -z "$config_file" ]]; then
    echo "Error: config file required" >&2
    usage
  fi

  if [[ ! -f "$config_file" ]]; then
    echo "Error: config file not found: $config_file" >&2
    exit 1
  fi

  if ! jq empty "$config_file" 2>/dev/null; then
    echo "Error: invalid JSON in config file: $config_file" >&2
    exit 1
  fi

  generate_matrix "$config_file"
}

generate_matrix() {
  local config_file="$1"

  # Validate max_size before the heavy jq pass so we can give a clean message.
  local max_size
  max_size=$(jq '.max_size // 256' "$config_file")

  # Compute the final entry count without building the full output.
  local final_count
  final_count=$(jq --argjson max_size "$max_size" '
    # Flatten all dimension sources into one object of arrays.
    (
      (if has("os") then {"os": .os} else {} end) +
      (if has("language_versions") then .language_versions else {} end) +
      (if has("feature_flags") then .feature_flags else {} end)
    ) as $dims |

    (.exclude // []) as $excludes |
    (.include // []) as $includes |

    # Cartesian product via reduce over dimension entries.
    (if ($dims | length) == 0 then [{}]
     else
       reduce ($dims | to_entries)[] as $dim (
         [{}];
         [.[] as $combo | $dim.value[] as $v | $combo + {($dim.key): $v}]
       )
     end) as $all |

    # Remove entries matched by any exclude rule.
    # A rule matches when every key-value pair in the rule equals the combo.
    ($all | map(
      . as $combo |
      select(
        [ $excludes[] |
          . as $rule |
          ($rule | to_entries | all(.value == $combo[.key]))
        ] | any | not
      )
    )) as $filtered |

    ($filtered + $includes) | length
  ' "$config_file")

  if [[ "$final_count" -gt "$max_size" ]]; then
    echo "Error: Matrix size $final_count exceeds maximum allowed size $max_size" >&2
    exit 1
  fi

  # Build and emit the full output JSON.
  jq '
    def is_excluded(excludes):
      . as $combo |
      if (excludes | length) == 0 then false
      else
        [ excludes[] |
          . as $rule |
          ($rule | to_entries | all(.value == $combo[.key]))
        ] | any
      end;

    # Flatten dimension sources.
    (
      (if has("os") then {"os": .os} else {} end) +
      (if has("language_versions") then .language_versions else {} end) +
      (if has("feature_flags") then .feature_flags else {} end)
    ) as $dims |

    (.include // []) as $includes |
    (.exclude // []) as $excludes |
    # Use has() instead of // for booleans: false // null wrongly yields null.
    (if has("max_parallel") then .max_parallel else null end) as $max_parallel |
    (if has("fail_fast")    then .fail_fast    else null end) as $fail_fast |

    # Generate Cartesian product.
    (if ($dims | length) == 0 then [{}]
     else
       reduce ($dims | to_entries)[] as $dim (
         [{}];
         [.[] as $combo | $dim.value[] as $v | $combo + {($dim.key): $v}]
       )
     end) as $all_combos |

    # Apply exclude rules.
    ($all_combos | map(select(is_excluded($excludes) | not))) as $filtered |

    # Append explicit include entries.
    ($filtered + $includes) as $final |

    # Assemble output.
    {
      "matrix": {
        "include": $final
      }
    }
    + (if $max_parallel != null then {"max-parallel": $max_parallel} else {} end)
    + (if $fail_fast != null    then {"fail-fast": $fail_fast}       else {} end)
  ' "$config_file"
}

main "$@"
