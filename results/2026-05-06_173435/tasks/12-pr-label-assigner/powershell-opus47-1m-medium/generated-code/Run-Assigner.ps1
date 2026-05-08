# Thin CLI wrapper for the GitHub Actions workflow.
# Usage: pwsh -File Run-Assigner.ps1 -FilesPath files.json -RulesPath rules.json
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FilesPath,
    [Parameter(Mandatory)][string]$RulesPath
)

. $PSScriptRoot/PrLabelAssigner.ps1
$json = Invoke-PrLabelAssigner -FilesPath $FilesPath -RulesPath $RulesPath
Write-Output "LABELS_JSON=$json"
