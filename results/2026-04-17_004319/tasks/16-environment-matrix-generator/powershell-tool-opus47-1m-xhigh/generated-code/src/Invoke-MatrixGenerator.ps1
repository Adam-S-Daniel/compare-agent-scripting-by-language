[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FixtureDir,
    [switch]$Compress
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'New-BuildMatrix.ps1')

if (-not (Test-Path -Path $FixtureDir -PathType Container)) {
    throw "Fixture directory not found: $FixtureDir"
}

$fixtures = Get-ChildItem -Path $FixtureDir -Filter '*.json' | Sort-Object Name
if ($fixtures.Count -eq 0) {
    throw "No fixtures (*.json) found in $FixtureDir"
}

# Each fixture gets its own delimited block so the harness can parse results per test case.
# Errors are captured as ===ERROR blocks instead of aborting, so the workflow always
# produces a complete report over all fixtures.
foreach ($fx in $fixtures) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($fx.Name)
    Write-Host "===FIXTURE:${name}:START==="
    try {
        $matrix = New-BuildMatrixFromFile -Path $fx.FullName
        $json = $matrix | ConvertTo-Json -Depth 10 -Compress:$Compress
        Write-Host '===JSON:START==='
        Write-Host $json
        Write-Host '===JSON:END==='
        Write-Host "===STATUS:OK==="
    } catch {
        Write-Host '===ERROR:START==='
        Write-Host $_.Exception.Message
        Write-Host '===ERROR:END==='
        Write-Host "===STATUS:FAILED==="
    }
    Write-Host "===FIXTURE:${name}:END==="
}
