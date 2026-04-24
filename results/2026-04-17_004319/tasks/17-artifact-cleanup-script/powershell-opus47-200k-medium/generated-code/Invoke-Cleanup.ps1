# Thin CLI wrapper so the workflow can shell out to a single file.
# Usage: pwsh -File Invoke-Cleanup.ps1 -FixturePath ./fixture.json [-DryRun]
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FixturePath,
    [switch]$DryRun
)
. (Join-Path $PSScriptRoot 'Cleanup.ps1')
Invoke-Cli -FixturePath $FixturePath -DryRun:$DryRun | Out-Null
