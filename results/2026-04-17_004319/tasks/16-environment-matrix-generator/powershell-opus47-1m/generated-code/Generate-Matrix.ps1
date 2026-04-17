#!/usr/bin/env pwsh
<#
.SYNOPSIS
Generate a GitHub Actions build matrix from a configuration file.

.DESCRIPTION
Reads a JSON configuration describing dimensions, optional include/exclude
rules, max-parallel, fail-fast, and a maxSize guard. Emits the resulting
matrix as JSON to stdout.

The script exits 0 on success and 1 on any error (invalid input, missing
file, maxSize exceeded, etc.).

.PARAMETER ConfigPath
Path to a JSON config file. Mutually exclusive with -ConfigJson.

.PARAMETER ConfigJson
Inline JSON config string. Useful for CI pipelines that pass data via env.

.PARAMETER Depth
JSON ConvertTo-Json -Depth value. Default 10.

.EXAMPLE
./Generate-Matrix.ps1 -ConfigPath ./fixtures/basic.json

.EXAMPLE
$env:MATRIX_CONFIG = '{"dimensions":{"os":["linux"]}}'
./Generate-Matrix.ps1 -ConfigJson $env:MATRIX_CONFIG
#>
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Path')]
    [string] $ConfigPath,

    [Parameter(Mandatory, ParameterSetName = 'Json')]
    [string] $ConfigJson,

    [int] $Depth = 10
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Import the module that contains the actual logic. Kept separate so it can be
# unit-tested independently of the CLI wrapper.
$modulePath = Join-Path $PSScriptRoot 'MatrixGenerator.psm1'
Import-Module $modulePath -Force

try {
    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        $json = Invoke-MatrixGenerator -Path $ConfigPath -JsonDepth $Depth
    } else {
        $json = Invoke-MatrixGenerator -Json $ConfigJson -JsonDepth $Depth
    }
    # Write JSON to stdout, no extra formatting — downstream tools may parse it.
    Write-Output $json
    exit 0
} catch {
    # Meaningful error message on stderr, non-zero exit so CI fails loudly.
    [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
    exit 1
}
