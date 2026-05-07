#requires -Version 7.0
<#
    Invoke-MatrixGenerator
    ----------------------
    Thin command-line wrapper around New-EnvironmentMatrix.ps1 suitable for use
    inside a GitHub Actions step. Reads a JSON configuration from a file and
    writes the generated matrix JSON to stdout (and optionally to a file or
    GitHub Actions output).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [int]$MaxSize = 256,

    # Optional output file path for the generated matrix JSON.
    [string]$OutputFile,

    # Optional name to write into $env:GITHUB_OUTPUT as <Name>=<json>.
    [string]$GitHubOutputName,

    # Print as a single line for easier parsing in CI logs.
    [switch]$SingleLine
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'New-EnvironmentMatrix.ps1')

try {
    $matrixJson = New-EnvironmentMatrix -Path $Path -MaxSize $MaxSize
}
catch {
    # Surface a single line, machine-friendly error to stderr.
    [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
    exit 1
}

if ($SingleLine) {
    # Re-serialize compactly so callers that grep stdout get one line.
    $matrixJson = ($matrixJson | ConvertFrom-Json) | ConvertTo-Json -Depth 12 -Compress
}

# Emit to stdout with a clear delimiter so the test harness can extract it.
Write-Host '----- BEGIN MATRIX -----'
Write-Output $matrixJson
Write-Host '----- END MATRIX -----'

if ($OutputFile) {
    $matrixJson | Set-Content -LiteralPath $OutputFile -Encoding utf8
    Write-Host "Wrote matrix to $OutputFile"
}

if ($GitHubOutputName -and $env:GITHUB_OUTPUT) {
    # Re-serialize compact for the GH-Actions output line. Note: the local switch
    # parameter previously called "$Compact" was renamed to "$SingleLine" to avoid
    # a name-prefix collision with ConvertTo-Json's `-Compress` switch when the
    # script later invoked ConvertTo-Json — PowerShell's parameter binder in 7.x
    # surprisingly mis-binds in that scenario.
    $compact = ($matrixJson | ConvertFrom-Json) | ConvertTo-Json -Depth 12 -Compress
    "$GitHubOutputName=$compact" | Add-Content -LiteralPath $env:GITHUB_OUTPUT
}
