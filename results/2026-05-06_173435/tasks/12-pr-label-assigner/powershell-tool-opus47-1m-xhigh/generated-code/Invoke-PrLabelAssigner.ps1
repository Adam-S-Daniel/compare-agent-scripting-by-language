<#
.SYNOPSIS
  Command-line driver for Get-PrLabels.

.DESCRIPTION
  Reads a list of changed files (one per line) from -ChangedFilesPath (or
  stdin when the path is '-'), runs them through the label assigner using
  the rules in -ConfigPath, and prints the result.

  The output format is intended to be machine-parseable by the act-based
  test harness:

      LABELS_BEGIN
      label-1
      label-2
      LABELS_END

  When the script is invoked from inside a GitHub Actions runner ($env:GITHUB_OUTPUT
  is set), it also writes:

      labels=label-1,label-2,...
      labels-json=["label-1","label-2",...]

  to $GITHUB_OUTPUT so downstream steps can consume the result.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ChangedFilesPath,

    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [switch]$EmitJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Locate and import the module that lives next to this script.
$scriptDir = Split-Path -Parent $PSCommandPath
$modulePath = Join-Path $scriptDir 'Get-PrLabels.psm1'
if (-not (Test-Path -LiteralPath $modulePath)) {
    Write-Error "Could not find Get-PrLabels.psm1 next to Invoke-PrLabelAssigner.ps1 (looked in '$scriptDir')."
    exit 2
}
Import-Module $modulePath -Force

# Read the changed-files fixture. '-' means stdin.
if ($ChangedFilesPath -eq '-') {
    $rawLines = @($input)
}
else {
    if (-not (Test-Path -LiteralPath $ChangedFilesPath)) {
        Write-Error "Changed-files file not found: $ChangedFilesPath"
        exit 2
    }
    $rawLines = Get-Content -LiteralPath $ChangedFilesPath
}

# Trim, drop blank lines and '#' comments. Keep an empty array (not $null)
# so Get-PrLabels' AllowEmptyCollection contract is honored.
$changedFiles = @(
    $rawLines |
        ForEach-Object { ([string]$_).Trim() } |
        Where-Object   { $_ -and -not $_.StartsWith('#') }
)

try {
    # Get-PrLabels returns a [string[]] (or empty array). Do NOT wrap in @()
    # here: combined with the comma-prefix that Get-PrLabels uses to preserve
    # array shape on empty/single results, an outer @() would double-wrap and
    # collapse the inner array to one space-joined string when later coerced.
    $labels = Get-PrLabels -ChangedFiles $changedFiles -ConfigPath $ConfigPath
    if ($null -eq $labels) { $labels = @() }
}
catch {
    Write-Error "Failed to compute labels: $($_.Exception.Message)"
    exit 1
}

# Stable, machine-parseable framing in stdout.
Write-Output 'LABELS_BEGIN'
foreach ($l in $labels) { Write-Output $l }
Write-Output 'LABELS_END'

function ConvertTo-LabelsJson {
    # Force a JSON array shape even for 0/1-element inputs. The pipeline form
    # plus -AsArray gives us [] / ["x"] / ["x","y"] consistently;
    # -InputObject + -AsArray would double-wrap an existing array.
    param([string[]]$Labels)
    if ($null -eq $Labels -or $Labels.Count -eq 0) { return '[]' }
    return ($Labels | ConvertTo-Json -Compress -AsArray)
}

if ($EmitJson) {
    Write-Output 'LABELS_JSON_BEGIN'
    Write-Output (ConvertTo-LabelsJson -Labels $labels)
    Write-Output 'LABELS_JSON_END'
}

# Optionally publish to GITHUB_OUTPUT for downstream Actions steps.
if ($env:GITHUB_OUTPUT -and (Test-Path -LiteralPath $env:GITHUB_OUTPUT)) {
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value ("labels=" + ($labels -join ','))
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value ("labels-json=" + (ConvertTo-LabelsJson -Labels $labels))
}

exit 0
