#!/usr/bin/env bash
set -euo pipefail

# Generates a GitHub Actions strategy.matrix JSON from a configuration file.
# Usage: matrix-generator.sh <config.json>

readonly DEFAULT_MAX_COMBINATIONS=256

usage() {
  echo "Usage: $0 <config.json>" >&2
  echo "  Generates a GitHub Actions strategy.matrix JSON from a configuration file." >&2
  exit 1
}

validate_config() {
  local config_file="$1"

  if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file not found: $config_file" >&2
    return 1
  fi

  if ! jq empty "$config_file" 2>/dev/null; then
    echo "Error: Invalid JSON in configuration file: $config_file" >&2
    return 1
  fi

  local has_axes
  has_axes=$(jq '[.os, .language_version, .feature_flags] | map(select(. != null)) | length' "$config_file")
  if [[ "$has_axes" -eq 0 ]]; then
    echo "Error: Configuration must define at least one matrix axis (os, language_version, feature_flags)" >&2
    return 1
  fi

  local axis_name
  for axis_name in os language_version feature_flags; do
    local axis_val
    axis_val=$(jq -r ".$axis_name // \"null\"" "$config_file")
    if [[ "$axis_val" != "null" ]]; then
      local axis_len
      axis_len=$(jq ".$axis_name | length" "$config_file")
      if [[ "$axis_len" -eq 0 ]]; then
        echo "Error: Matrix axis '$axis_name' is empty" >&2
        return 1
      fi
    fi
  done

  return 0
}

compute_cross_product() {
  local config_file="$1"

  jq -c '
    (.os // ["_none"]) as $os_list |
    (.language_version // ["_none"]) as $lv_list |
    (.feature_flags // ["_none"]) as $ff_list |
    [
      $os_list[] as $os |
      $lv_list[] as $lv |
      $ff_list[] as $ff |
      (
        {}
        | if $os != "_none" then . + {"os": $os} else . end
        | if $lv != "_none" then . + {"language_version": $lv} else . end
        | if $ff != "_none" then . + {"feature_flags": $ff} else . end
      )
    ]
  ' "$config_file"
}

apply_excludes() {
  local combos="$1"
  local config_file="$2"

  local excludes
  excludes=$(jq -c '.exclude // []' "$config_file")

  if [[ "$excludes" == "[]" ]]; then
    echo "$combos"
    return
  fi

  jq -c --argjson excludes "$excludes" '
    [
      .[] | . as $combo |
      if (
        [$excludes[] | . as $excl |
          if ([$excl | to_entries[] | select($combo[.key] == .value)] | length) == ($excl | length)
          then 1 else 0 end
        ] | add // 0
      ) > 0
      then empty
      else .
      end
    ]
  ' <<< "$combos"
}

apply_includes() {
  local combos="$1"
  local config_file="$2"

  local includes
  includes=$(jq -c '.include // []' "$config_file")

  if [[ "$includes" == "[]" ]]; then
    echo "$combos"
    return
  fi

  jq -c --argjson includes "$includes" '. + $includes' <<< "$combos"
}

check_matrix_size() {
  local combos="$1"
  local config_file="$2"

  local max_combos
  max_combos=$(jq -r ".max_combinations // $DEFAULT_MAX_COMBINATIONS" "$config_file")

  local actual_size
  actual_size=$(jq 'length' <<< "$combos")

  if [[ "$actual_size" -gt "$max_combos" ]]; then
    echo "Error: Matrix size ($actual_size) exceeds maximum allowed combinations ($max_combos)" >&2
    return 1
  fi
}

build_strategy() {
  local combos="$1"
  local config_file="$2"

  local fail_fast max_parallel
  fail_fast=$(jq 'if has("fail_fast") then .fail_fast else true end' "$config_file")
  max_parallel=$(jq -r '.max_parallel // "null"' "$config_file")

  local strategy
  strategy=$(jq -n \
    --argjson matrix "$combos" \
    --argjson fail_fast "$fail_fast" \
    '{
      "fail-fast": $fail_fast,
      matrix: {
        include: $matrix
      }
    }')

  if [[ "$max_parallel" != "null" ]]; then
    strategy=$(jq --argjson mp "$max_parallel" '.["max-parallel"] = $mp' <<< "$strategy")
  fi

  echo "$strategy"
}

main() {
  if [[ $# -ne 1 ]]; then
    usage
  fi

  local config_file="$1"

  validate_config "$config_file"

  local combos
  combos=$(compute_cross_product "$config_file")

  combos=$(apply_excludes "$combos" "$config_file")

  combos=$(apply_includes "$combos" "$config_file")

  check_matrix_size "$combos" "$config_file"

  build_strategy "$combos" "$config_file"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
