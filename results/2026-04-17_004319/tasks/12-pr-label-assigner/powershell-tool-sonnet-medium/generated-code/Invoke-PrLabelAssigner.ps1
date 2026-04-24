# Invoke-PrLabelAssigner.ps1
# CLI entry point for the PR label assigner.
# Reads a label rules config and outputs JSON array of labels for the given changed files.

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$ChangedFiles,

    [string]$RulesConfig = "$PSScriptRoot/label-rules.json"
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/PrLabelAssigner.ps1"

$rules  = Import-LabelRules -Path $RulesConfig
$labels = Get-LabelsForFiles -Files $ChangedFiles -Rules $rules

# Output as JSON array so callers can parse it reliably
$labels | ConvertTo-Json -Compress
