# CLI entry point for the PR label assigner.
#
# Reads the list of changed files from either:
#   - a file whose path is given via -ChangedFilesPath, or
#   - stdin (one path per line)
#
# Rules come from -RulesPath (JSON, see rules.example.json).
#
# Output: one label per line on stdout, priority-descending.
[CmdletBinding()]
param(
    [string]$ChangedFilesPath,
    [Parameter(Mandatory)][string]$RulesPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'PRLabelAssigner.psm1') -Force

if ($ChangedFilesPath) {
    if (-not (Test-Path -LiteralPath $ChangedFilesPath)) {
        throw "Changed files list not found: $ChangedFilesPath"
    }
    $files = @(Get-Content -LiteralPath $ChangedFilesPath |
        Where-Object { $_ -and $_.Trim().Length -gt 0 })
} else {
    $files = @($input | Where-Object { $_ -and $_.Trim().Length -gt 0 })
}

$rules = Get-RulesFromFile -Path $RulesPath
$labels = @(Invoke-PRLabelAssigner -ChangedFiles $files -Rules $rules)

$output = $labels -join [Environment]::NewLine
if ($OutputPath) {
    Set-Content -LiteralPath $OutputPath -Value $output
}
# Also emit to stdout for piping / workflow capture.
$labels | ForEach-Object { Write-Output $_ }
