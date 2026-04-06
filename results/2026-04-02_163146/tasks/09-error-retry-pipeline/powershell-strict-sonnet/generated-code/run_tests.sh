#!/usr/bin/env bash
# Run Pester tests for the Pipeline module
pwsh -NoProfile -c "Invoke-Pester './Pipeline.Tests.ps1' -Output Normal"
