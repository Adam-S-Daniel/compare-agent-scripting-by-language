#!/bin/bash
# Run Pester tests for the REST API Client
cd "$(dirname "$0")"
pwsh -NoProfile -NonInteractive -Command "Invoke-Pester -Path 'ApiClient.Tests.ps1' -Output Detailed"
