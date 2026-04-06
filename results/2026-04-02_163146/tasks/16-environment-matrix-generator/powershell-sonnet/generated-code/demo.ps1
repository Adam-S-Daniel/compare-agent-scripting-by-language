# demo.ps1 - Demonstrates the Environment Matrix Generator
# Run: pwsh -File demo.ps1

. (Join-Path $PSScriptRoot "MatrixGenerator.ps1")

Write-Host "=== Environment Matrix Generator Demo ===" -ForegroundColor Cyan
Write-Host ""

# -------------------------------------------------------
# Example 1: Simple OS x Language matrix
# -------------------------------------------------------
Write-Host "--- Example 1: OS x Language ---" -ForegroundColor Yellow

$config1 = @{
    os       = @("ubuntu-latest", "windows-latest", "macos-latest")
    language = @("python-3.10", "python-3.11")
    fail_fast = $false
    max_parallel = 4
}

$json1 = New-BuildMatrix -Config $config1
Write-Host $json1
Write-Host ""

# -------------------------------------------------------
# Example 2: Matrix with include/exclude rules
# -------------------------------------------------------
Write-Host "--- Example 2: With Include/Exclude Rules ---" -ForegroundColor Yellow

$config2 = @{
    os       = @("ubuntu-latest", "windows-latest")
    language = @("python-3.10", "python-3.11")
    include  = @(
        @{ os = "macos-latest"; language = "python-3.12"; experimental = $true }
    )
    exclude  = @(
        @{ os = "windows-latest"; language = "python-3.10" }
    )
    fail_fast    = $false
    max_parallel = 3
}

$json2 = New-BuildMatrix -Config $config2
Write-Host $json2
Write-Host ""

# -------------------------------------------------------
# Example 3: Multi-axis with feature flags
# -------------------------------------------------------
Write-Host "--- Example 3: OS x Language x Feature Flags ---" -ForegroundColor Yellow

$config3 = @{
    os            = @("ubuntu-latest", "windows-latest")
    language      = @("node-18", "node-20")
    feature_flags = @("stable", "experimental")
}

$json3 = New-BuildMatrix -Config $config3
$parsed3 = $json3 | ConvertFrom-Json
Write-Host "Matrix size (cartesian product): $($parsed3.matrix_size)"
Write-Host $json3
Write-Host ""

# -------------------------------------------------------
# Example 4: Error handling - matrix too large
# -------------------------------------------------------
Write-Host "--- Example 4: Error Handling (matrix too large) ---" -ForegroundColor Yellow

$config4 = @{
    os       = 1..20 | ForEach-Object { "os-$_" }
    language = 1..15 | ForEach-Object { "lang-$_" }
}

try {
    New-BuildMatrix -Config $config4
} catch {
    Write-Host "Caught expected error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Demo complete ===" -ForegroundColor Cyan
