#!/usr/bin/env pwsh
# CLI wrapper: read a JSON config, print the matrix JSON, exit non-zero on error.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ConfigPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'MatrixGenerator.psm1') -Force

try {
    $config = Read-MatrixConfig -Path $ConfigPath
    $matrix = New-BuildMatrix -Config $config
    $json = $matrix | ConvertTo-MatrixJson
    if ($OutputPath) { Set-Content -LiteralPath $OutputPath -Value $json -NoNewline }
    Write-Output $json
} catch {
    Write-Error "matrix-generator: $($_.Exception.Message)"
    exit 1
}
