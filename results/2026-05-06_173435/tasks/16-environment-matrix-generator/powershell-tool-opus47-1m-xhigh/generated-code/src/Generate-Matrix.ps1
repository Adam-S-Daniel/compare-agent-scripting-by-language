#Requires -Version 7

<#
.SYNOPSIS
    CLI wrapper around MatrixGenerator. Reads a JSON config, builds the
    GitHub Actions strategy.matrix, prints the JSON to stdout.

.PARAMETER ConfigPath
    Path to the JSON config file.

.PARAMETER OutputPath
    Optional file path. When provided, the matrix JSON is also written there.

.EXAMPLE
    pwsh -File src/Generate-Matrix.ps1 -ConfigPath fixtures/case1.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ConfigPath,

    [string] $OutputPath
)

$ErrorActionPreference = 'Stop'

# Dot-source the library next to this script so paths are stable in CI.
. (Join-Path $PSScriptRoot 'MatrixGenerator.ps1')

try {
    $config = Read-MatrixConfig -Path $ConfigPath
    $matrix = New-BuildMatrix -Config $config
    $json = ConvertTo-MatrixJson -Matrix $matrix

    if ($OutputPath) {
        $json | Set-Content -Path $OutputPath -NoNewline
    }

    # Always emit to stdout so callers (and CI) can parse it.
    Write-Output $json
    exit 0
} catch {
    # Friendlier failure: send a one-line summary to stderr, full record to host.
    [Console]::Error.WriteLine("Matrix generation failed: $($_.Exception.Message)")
    Write-Error $_ -ErrorAction Continue
    exit 1
}
