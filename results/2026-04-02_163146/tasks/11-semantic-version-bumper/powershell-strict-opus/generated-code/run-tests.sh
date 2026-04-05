#!/bin/bash
cd "$(dirname "$0")"
/snap/bin/pwsh -NoProfile -NonInteractive -File run-tests.ps1
