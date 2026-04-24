#!/usr/bin/env bash
# mock-license-lookup.sh NAME
#
# Stand-in for a real license registry (e.g. libraries.io / deps.dev).
# Reads NAME as the first argument and prints an SPDX id on stdout.
# Resolution order:
#   1. An override file at $LICENSE_DB (default: ./license-db.tsv) with
#      lines of "name<TAB>spdx".
#   2. A small built-in map of common packages.
#   3. Empty output (callers treat this as UNKNOWN).
#
# Keeping the lookup pluggable lets tests swap in fixture-specific data
# without touching the checker.

set -u

name="${1:-}"
if [[ -z "$name" ]]; then
    exit 0
fi

db="${LICENSE_DB:-./license-db.tsv}"
if [[ -f "$db" ]]; then
    # Exact match on first TSV column.
    while IFS=$'\t' read -r key value; do
        if [[ "$key" == "$name" ]]; then
            printf '%s' "$value"
            exit 0
        fi
    done < "$db"
fi

# Built-in fallback so the script is useful without a DB file.
case "$name" in
    lodash|express|react|jquery) printf 'MIT' ;;
    requests|urllib3)            printf 'Apache-2.0' ;;
    flask|numpy|scipy)           printf 'BSD-3-Clause' ;;
    *) : ;;  # empty -> UNKNOWN
esac
