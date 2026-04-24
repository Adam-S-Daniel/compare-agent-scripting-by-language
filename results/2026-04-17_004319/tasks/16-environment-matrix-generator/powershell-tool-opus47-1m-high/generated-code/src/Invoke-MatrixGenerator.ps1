# Invoke-MatrixGenerator.ps1
#
# Thin entry-point script that loads a JSON config file and prints the
# generated GitHub Actions matrix JSON to stdout.

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [Parameter()]
    [int]$Depth = 10
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'MatrixGenerator.psm1') -Force

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

$raw = Get-Content -LiteralPath $ConfigPath -Raw
if ([string]::IsNullOrWhiteSpace($raw)) {
    throw "Config file '$ConfigPath' is empty."
}

try {
    $config = $raw | ConvertFrom-Json -AsHashtable
} catch {
    throw "Failed to parse config '$ConfigPath' as JSON: $($_.Exception.Message)"
}

$matrix = New-BuildMatrix -Config $config
$matrix | ConvertTo-Json -Depth $Depth
