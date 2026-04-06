#!/bin/bash
cd "$(dirname "$0")"
pwsh -NoProfile -NonInteractive -File run-tests.ps1
