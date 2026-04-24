#!/usr/bin/env pwsh
# CLI wrapper around the PRLabelAssigner module.
# Usage:
#   ./Invoke-PRLabelAssigner.ps1 -RulesPath rules.json -FilesPath changed.txt
# Prints:
#   === PR Labels ===
#   <label1>
#   ...
#   === End PR Labels ===
# Exits 1 on any error, 0 otherwise.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RulesPath,
    [Parameter(Mandatory)][string]$FilesPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'PRLabelAssigner.psm1') -Force

try {
    $rules = Get-LabelRules -Path $RulesPath

    if (-not (Test-Path -LiteralPath $FilesPath)) {
        throw "Changed-files list not found: $FilesPath"
    }
    $files = Get-Content -LiteralPath $FilesPath |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' }
    if ($null -eq $files) { $files = @() }

    $labels = Get-PRLabels -ChangedFiles @($files) -Rules $rules

    Write-Host '=== PR Labels ==='
    foreach ($l in $labels) { Write-Host $l }
    Write-Host '=== End PR Labels ==='
    exit 0
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 1
}
