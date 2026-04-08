# demo.ps1
# Demonstrates the Environment Matrix Generator
# Run with: pwsh ./demo.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'MatrixGenerator.psm1') -Force

Write-Host '=== Environment Matrix Generator Demo ===' -ForegroundColor Cyan
Write-Host ''

# Example configuration for a Python project CI matrix
[hashtable]$inputConfig = @{
    os               = @('ubuntu-latest', 'windows-latest', 'macos-latest')
    language_versions = @('3.9', '3.10', '3.11')
    feature_flags    = @('with-cache', 'no-cache')
    exclude_rules    = @(
        # Skip the oldest Python on Windows (known flaky)
        @{ os = 'windows-latest'; language = '3.9' },
        # No need to test no-cache on macOS
        @{ os = 'macos-latest'; feature = 'no-cache' }
    )
    include_rules    = @(
        # Add an experimental combination: latest Python on ubuntu with extra flag
        @{ os = 'ubuntu-latest'; language = '3.12'; feature = 'experimental' }
    )
    max_parallel     = 6
    fail_fast        = $false
    max_size         = 50
}

[string]$json = Invoke-MatrixGenerator -InputConfig $inputConfig -OutputPath (Join-Path $PSScriptRoot 'matrix-output.json')

Write-Host 'Generated GitHub Actions strategy.matrix JSON:' -ForegroundColor Green
Write-Host ''
Write-Host $json
Write-Host ''

# Count effective combinations (cartesian product minus excludes)
[object]$parsed = $json | ConvertFrom-Json
[int]$osCount = ([object[]]$parsed.matrix.os).Count
[int]$langCount = ([object[]]$parsed.matrix.language).Count
[int]$featureCount = ([object[]]$parsed.matrix.feature).Count

Write-Host "Matrix dimensions: $osCount OS x $langCount languages x $featureCount features" -ForegroundColor Yellow
Write-Host "Exclude rules: $(([object[]]$parsed.matrix.exclude).Count)" -ForegroundColor Yellow
Write-Host "Include rules: $(([object[]]$parsed.matrix.include).Count)" -ForegroundColor Yellow
Write-Host "Max parallel: $($parsed.'max-parallel')" -ForegroundColor Yellow
Write-Host "Fail fast: $($parsed.'fail-fast')" -ForegroundColor Yellow
Write-Host ''
Write-Host 'Output also written to: matrix-output.json' -ForegroundColor Green
