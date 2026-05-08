#!/usr/bin/env pwsh
# CLI wrapper: read rules JSON + a list of changed files, write labels to stdout.
# Designed to be the entry point used by the GitHub Actions workflow.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $RulesFile,
    [Parameter(Mandatory)] [string] $FilesFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    if (-not (Test-Path -LiteralPath $RulesFile)) {
        throw "Rules file not found: $RulesFile"
    }
    if (-not (Test-Path -LiteralPath $FilesFile)) {
        throw "Files list not found: $FilesFile"
    }

    $here = Split-Path -Parent $PSCommandPath
    Import-Module (Join-Path $here 'LabelAssigner.psm1') -Force

    $rulesJson = Get-Content -LiteralPath $RulesFile -Raw
    $config    = $rulesJson | ConvertFrom-Json
    if ($null -eq $config.rules) {
        throw "Rules file must contain a top-level 'rules' array."
    }

    $files = Get-Content -LiteralPath $FilesFile |
        Where-Object { $_ -and -not [string]::IsNullOrWhiteSpace($_) }

    if (-not $files) {
        Write-Host "No changed files supplied; emitting empty label set."
        Write-Output 'LABELS='
        exit 0
    }

    $labels = Get-LabelsForFiles -Files @($files) -Rules @($config.rules)
    Write-Host "Changed files:"
    $files | ForEach-Object { Write-Host "  - $_" }
    Write-Host "Matched labels (priority desc):"
    if (@($labels).Count -eq 0) {
        Write-Host "  (none)"
    } else {
        $labels | ForEach-Object { Write-Host "  - $_" }
    }
    Write-Output ("LABELS=" + ($labels -join ','))
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
