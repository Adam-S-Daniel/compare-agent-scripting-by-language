#!/bin/bash
# Run all Pester tests for the Dependency License Checker
cd "$(dirname "$0")"
pwsh -noprofile -c 'Invoke-Pester -Output Detailed'
