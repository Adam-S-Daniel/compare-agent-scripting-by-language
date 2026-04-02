#!/bin/bash
cd "$(dirname "$0")"
pwsh -NoProfile -Command "Invoke-Pester -Path './tests' -Output Detailed"
