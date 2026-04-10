# New-BuildMatrix.ps1
# CLI wrapper that reads a JSON config and outputs the GitHub Actions strategy.matrix JSON.
#
# Usage:
#   ./New-BuildMatrix.ps1 -ConfigFile config.json
#   ./New-BuildMatrix.ps1 -ConfigFile config.json -MaxMatrixSize 100

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ConfigFile,

    # Override the max matrix size (default comes from the config or falls back to 256)
    [int]$MaxMatrixSize = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve the module alongside this script (supports running from any working dir)
$moduleDir = $PSScriptRoot
Import-Module "$moduleDir/MatrixGenerator.psm1" -Force

# --- Read and parse the config file ---
if (-not (Test-Path $ConfigFile)) {
    Write-Error "Config file not found: $ConfigFile"
    exit 1
}

$rawJson = Get-Content $ConfigFile -Raw
$jsonObj  = $rawJson | ConvertFrom-Json

# Convert the PSCustomObject tree from ConvertFrom-Json into a plain hashtable
# so Invoke-MatrixGeneration can use ContainsKey() throughout.
function ConvertTo-Hashtable {
    param([Parameter(ValueFromPipeline)] $InputObject)
    process {
        if ($null -eq $InputObject)                { return $null }
        if ($InputObject -is [System.Collections.IEnumerable] -and
            $InputObject -isnot [string]) {
            # Arrays: convert each element
            return @($InputObject | ForEach-Object { ConvertTo-Hashtable $_ })
        }
        if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
            $ht = @{}
            foreach ($prop in $InputObject.PSObject.Properties) {
                $ht[$prop.Name] = ConvertTo-Hashtable $prop.Value
            }
            return $ht
        }
        return $InputObject
    }
}

$config = ConvertTo-Hashtable $jsonObj

# Allow CLI override of max_matrix_size
if ($MaxMatrixSize -gt 0) {
    $config['max_matrix_size'] = $MaxMatrixSize
}

# --- Generate the matrix ---
try {
    $result = Invoke-MatrixGeneration -Config $config
}
catch {
    Write-Error "Matrix generation failed: $_"
    exit 1
}

# --- Output the JSON ---
$json = $result | ConvertTo-Json -Depth 10
Write-Output $json

# Write a summary to the GitHub Actions step summary if running in a workflow
if ($env:GITHUB_STEP_SUMMARY) {
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value "## Build Matrix`n"
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value '```json'
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $json
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value '```'
}
