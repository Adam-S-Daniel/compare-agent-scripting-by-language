#!/usr/bin/env pwsh
# Entry-point script: read a JSON config from disk and emit the matrix JSON.
# Usage: pwsh ./Generate-Matrix.ps1 -ConfigPath ./config.json [-OutputPath ./out.json] [-Compress]
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ConfigPath,
    [string] $OutputPath,
    [switch] $Compress
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here 'MatrixGenerator.psm1') -Force

try {
    $json = Invoke-MatrixGenerator -ConfigPath $ConfigPath -Compress:$Compress
} catch {
    Write-Error "Matrix generation failed: $($_.Exception.Message)"
    exit 1
}

if ($OutputPath) {
    Set-Content -LiteralPath $OutputPath -Value $json -Encoding UTF8
    Write-Host "Wrote matrix to $OutputPath"
}

# Always emit to stdout so callers (CI) can capture it.
Write-Output $json
