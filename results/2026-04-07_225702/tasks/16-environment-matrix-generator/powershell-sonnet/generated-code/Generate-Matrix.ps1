# Generate-Matrix.ps1
# Demo script: generates a realistic GitHub Actions build matrix and prints JSON.

. (Join-Path $PSScriptRoot "MatrixGenerator.ps1")

# ---------------------------------------------------------------------------
# Example configuration: a typical multi-platform, multi-version Python CI run
# ---------------------------------------------------------------------------
$config = @{
    os               = @("ubuntu-latest", "windows-latest", "macos-latest")
    python_version   = @("3.10", "3.11", "3.12")
    experimental     = @("false")       # one flag value keeps the base matrix at 9 entries
}

# Exclude Windows + Python 3.10 (known compatibility issue)
$excludes = @(
    @{ os = "windows-latest"; python_version = "3.10" }
)

# Add one extra experimental entry not in the base product
$includes = @(
    @{ os = "ubuntu-latest"; python_version = "3.13"; experimental = "true" }
)

$result = New-BuildMatrix `
    -Config      $config `
    -Excludes    $excludes `
    -Includes    $includes `
    -FailFast    $false `
    -MaxParallel 6 `
    -MaxSize     256

$json = ConvertTo-MatrixJson -MatrixResult $result

Write-Host "=== Generated GitHub Actions Matrix ===" -ForegroundColor Cyan
Write-Host $json
Write-Host ""
Write-Host "Total combinations: $($result.matrix.include.Count)" -ForegroundColor Green
