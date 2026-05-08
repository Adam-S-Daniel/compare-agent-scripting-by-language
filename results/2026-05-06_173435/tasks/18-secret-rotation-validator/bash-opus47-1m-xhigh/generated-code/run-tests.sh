#!/usr/bin/env bash
#
# Convenience entry point: runs the full bats suite from the project root
# so that tests/test_integration.bats can drop act-result.txt next to it.

set -euo pipefail

cd "$(dirname "$0")"

bats tests/
