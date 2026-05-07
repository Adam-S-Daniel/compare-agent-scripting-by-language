#!/usr/bin/env bash
# Mock license database mapping package names to SPDX license identifiers.
# In production this would query a real registry (npm, PyPI, etc.).

lookup_license() {
  local package="$1"
  case "$package" in
    express)         echo "MIT" ;;
    lodash)          echo "MIT" ;;
    react)           echo "MIT" ;;
    axios)           echo "MIT" ;;
    moment)          echo "MIT" ;;
    request)         echo "Apache-2.0" ;;
    flask)           echo "BSD-3-Clause" ;;
    django)          echo "BSD-3-Clause" ;;
    requests)        echo "Apache-2.0" ;;
    numpy)           echo "BSD-3-Clause" ;;
    pandas)          echo "BSD-3-Clause" ;;
    mysql-connector) echo "GPL-2.0" ;;
    gpl-package)     echo "GPL-3.0" ;;
    left-pad)        echo "WTFPL" ;;
    *)               echo "UNKNOWN" ;;
  esac
}
