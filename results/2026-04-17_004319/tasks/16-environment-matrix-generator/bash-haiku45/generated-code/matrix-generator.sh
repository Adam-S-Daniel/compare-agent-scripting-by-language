#!/usr/bin/env bash
# GitHub Actions Matrix Generator
# Generates build matrices from configuration describing OS options, language versions, and feature flags

set -euo pipefail

main() {
    if [[ $# -ne 1 ]]; then
        echo "Error: Configuration JSON required as argument" >&2
        return 1
    fi

    local config="$1"

    # Validate JSON input
    if ! jq . <<< "$config" > /dev/null 2>&1; then
        echo "Error: Invalid JSON configuration" >&2
        return 1
    fi

    # Build the matrix
    local result
    result=$(build_matrix "$config" 2>&1) || {
        # Extract error message from jq output
        local error_msg
        error_msg=$(echo "$result" | grep -i "error\|exceeds\|required" | head -1)
        if [[ -n "$error_msg" ]]; then
            echo "$error_msg" >&2
        else
            echo "Unknown error" >&2
        fi
        return 1
    }

    echo "$result"
}

build_matrix() {
    local config="$1"

    jq -n \
        --argjson os "$(jq '.os // []' <<< "$config")" \
        --argjson version "$(jq '.version // []' <<< "$config")" \
        --argjson language "$(jq '.language // []' <<< "$config")" \
        --argjson include "$(jq '.include // []' <<< "$config")" \
        --argjson exclude "$(jq '.exclude // []' <<< "$config")" \
        --argjson failfast "$(jq 'if has("fail-fast") then .["fail-fast"] else null end' <<< "$config")" \
        --argjson maxparallel "$(jq 'if has("max-parallel") then .["max-parallel"] else null end' <<< "$config")" \
        --argjson maxsize "$(jq '.["max-matrix-size"] // 256' <<< "$config")" \
        '
        # Validate required fields
        if (($os | length) == 0 and ($include | length) == 0) then
            error("os field is required when include is empty")
        else . end |

        # Generate cartesian product with nulls for empty arrays
        [
            ($os | if length == 0 then [null] else . end)[] as $o |
            ($version | if length == 0 then [null] else . end)[] as $v |
            ($language | if length == 0 then [null] else . end)[] as $l |

            # Build combination
            (
                {} |
                (if ($o | type) == "null" then . else .os = $o end) |
                (if ($v | type) == "null" then . else .version = $v end) |
                (if ($l | type) == "null" then . else .language = $l end)
            ) as $combo |

            # Filter out excluded combinations
            if ($exclude | map(
                ((.os // null) as $eo |
                 (.version // null) as $ev |
                 (.language // null) as $el |
                 (($combo.os // null) == $eo or $eo == null) and
                 (($combo.version // null) == $ev or $ev == null) and
                 (($combo.language // null) == $el or $el == null)
                )
            ) | any) then
                empty
            else
                $combo
            end
        ] as $cartesian |

        # Build result with include array
        {include: ($cartesian + $include)} |

        # Validate size
        if ((.include | length) > $maxsize) then
            error("Matrix size \(.include | length) exceeds maximum \($maxsize)")
        else . end |

        # Add configuration if not null
        if $failfast != null then
            .["fail-fast"] = $failfast
        else . end |
        if $maxparallel != null then
            .["max-parallel"] = $maxparallel
        else . end
        '
}

main "$@"
