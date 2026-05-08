#!/usr/bin/env pwsh
# Thin CLI wrapper around the PrLabelAssigner module.
# Reads JSON rules + JSON file list, prints labels (one per line by default,
# or as JSON when -Json is used).

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RulesPath,
    [Parameter(Mandatory)][string]$FilesPath,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/PrLabelAssigner.psm1" -Force

try {
    $labels = Invoke-LabelAssigner -RulesPath $RulesPath -FilesPath $FilesPath
} catch {
    Write-Error $_.Exception.Message
    exit 1
}

if ($Json) {
    # Force-array JSON even for 0 or 1 labels, so consumers can always parse.
    ConvertTo-Json -InputObject @($labels) -Compress -Depth 3
} else {
    foreach ($l in $labels) { Write-Output $l }
}
