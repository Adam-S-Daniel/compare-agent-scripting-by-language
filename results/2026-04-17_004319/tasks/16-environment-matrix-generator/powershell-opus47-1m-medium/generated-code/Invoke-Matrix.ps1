# Invoke-Matrix.ps1
# CLI entry point. Reads a config JSON file and emits the generated matrix JSON.

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ConfigPath,
    [int]$Depth = 20,
    [switch]$Compress
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'MatrixGenerator.ps1')

try {
    $cfg = ConvertFrom-MatrixConfigFile -Path $ConfigPath
    $matrix = New-BuildMatrix -Config $cfg
    $json = $matrix | ConvertTo-Json -Depth $Depth -Compress:$Compress
    Write-Output $json
}
catch {
    Write-Error "Matrix generation failed: $($_.Exception.Message)"
    exit 1
}
