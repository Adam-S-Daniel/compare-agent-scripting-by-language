#!/usr/bin/env pwsh
<#
.SYNOPSIS
    CLI entry point for environment matrix generation.
.DESCRIPTION
    Reads a JSON configuration file describing OS options, language versions,
    feature flags, include/exclude rules, and strategy settings. Outputs a
    complete GitHub Actions strategy.matrix JSON object.
.EXAMPLE
    ./Generate-Matrix.ps1 -ConfigPath ./fixtures/basic-config.json
#>
[CmdletBinding()]
param(
    # Path to a JSON configuration file.
    [Parameter(Mandatory)]
    [string]$ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import the matrix generator functions
. "$PSScriptRoot/MatrixGenerator.ps1"

# Validate the config file exists
if (-not (Test-Path -Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    exit 1
}

# Read and parse the JSON config
[string]$rawJson = Get-Content -Path $ConfigPath -Raw
$parsed = $rawJson | ConvertFrom-Json

# Convert PSCustomObject to hashtable (ConvertFrom-Json returns PSCustomObject)
function ConvertTo-Hashtable {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [psobject]$InputObject
    )

    [hashtable]$ht = @{}
    foreach ($prop in $InputObject.PSObject.Properties) {
        if ($prop.Value -is [System.Management.Automation.PSCustomObject]) {
            $ht[$prop.Name] = ConvertTo-Hashtable -InputObject $prop.Value
        }
        elseif ($prop.Value -is [System.Object[]]) {
            # Convert array elements — nested objects become hashtables
            [array]$arr = @()
            foreach ($item in $prop.Value) {
                if ($item -is [System.Management.Automation.PSCustomObject]) {
                    $arr += @(, (ConvertTo-Hashtable -InputObject $item))
                }
                else {
                    $arr += @(, $item)
                }
            }
            $ht[$prop.Name] = $arr
        }
        else {
            $ht[$prop.Name] = $prop.Value
        }
    }
    return $ht
}

[hashtable]$config = ConvertTo-Hashtable -InputObject $parsed

try {
    [hashtable]$result = New-BuildMatrix -Configuration $config
    [string]$json = $result | ConvertTo-Json -Depth 10
    Write-Output $json
}
catch {
    Write-Error "Matrix generation failed: $_"
    exit 1
}
