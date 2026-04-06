#!/bin/bash
cd /home/passp/repos/compare-agent-scripting-by-language/workspaces/2026-04-02_163146/17-artifact-cleanup-script/powershell-sonnet/
/snap/bin/pwsh -NoProfile -Command "if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { [version]\$_.Version -ge [version]'5.0' })) { Install-Module Pester -Force -SkipPublisherCheck -Scope CurrentUser }"
/snap/bin/pwsh -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0; Invoke-Pester './ArtifactCleanup.Tests.ps1' -Output Detailed"
