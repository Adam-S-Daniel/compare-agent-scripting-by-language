#!/usr/bin/env pwsh
# CLI wrapper around New-BuildMatrix.
# Usage: Generate-Matrix.ps1 -ConfigPath <path-to-config.json>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'MatrixGenerator.psm1') -Force

try {
    Invoke-MatrixGenerator -ConfigPath $ConfigPath
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
