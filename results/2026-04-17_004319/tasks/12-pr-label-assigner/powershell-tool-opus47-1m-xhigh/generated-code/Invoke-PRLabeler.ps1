#requires -Version 7.0
<#
.SYNOPSIS
  CLI wrapper around PRLabeler for use in CI.

.DESCRIPTION
  Reads a JSON file containing the changed file list (mocked PR data) and a JSON
  config file containing the label rules, then prints the resulting label set.

  Input JSON (-FilesPath) shape:
    { "files": ["docs/readme.md", "src/api/users.js"] }
  OR a bare array:
    ["docs/readme.md", "src/api/users.js"]

  Config JSON (-ConfigPath) shape:
    { "rules": [
        { "pattern": "docs/**", "labels": ["documentation"], "priority": 1 },
        ...
    ] }

.PARAMETER FilesPath
  Path to JSON file listing the changed files.

.PARAMETER ConfigPath
  Path to JSON file with the label rules.

.PARAMETER OutputFormat
  'text' (default) prints one label per line.
  'json' prints a JSON array.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $FilesPath,

    [Parameter(Mandatory)]
    [string] $ConfigPath,

    [ValidateSet('text', 'json')]
    [string] $OutputFormat = 'text'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

try {
    $here = Split-Path -Parent $PSCommandPath
    Import-Module (Join-Path $here 'src' 'PRLabeler.psm1') -Force

    if (-not (Test-Path -LiteralPath $FilesPath)) {
        throw "Files list not found: $FilesPath"
    }

    $raw = Get-Content -LiteralPath $FilesPath -Raw
    $parsed = $raw | ConvertFrom-Json -ErrorAction Stop

    # Accept either { "files": [...] } or a bare array.
    if ($parsed -is [System.Array]) {
        $files = @($parsed)
    } elseif ($parsed.PSObject.Properties['files']) {
        $files = @($parsed.files)
    } else {
        throw "Input JSON must be an array or an object with a 'files' field."
    }

    $labels = Get-PRLabels -Files $files -ConfigPath $ConfigPath

    Write-Host "=== PR Label Assigner ==="
    Write-Host "Input files: $($files.Count)"
    foreach ($f in $files) { Write-Host "  - $f" }
    Write-Host "Assigned labels: $($labels.Count)"

    if ($OutputFormat -eq 'json') {
        # ConvertTo-Json on empty array would print 'null'; force array output.
        Write-Output (,@($labels) | ConvertTo-Json -Compress)
    } else {
        foreach ($l in $labels) { Write-Output "LABEL: $l" }
    }

    exit 0
}
catch {
    Write-Error "PR labeler failed: $($_.Exception.Message)"
    exit 1
}
