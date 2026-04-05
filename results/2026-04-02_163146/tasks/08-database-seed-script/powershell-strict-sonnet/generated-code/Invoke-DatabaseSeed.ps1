# Invoke-DatabaseSeed.ps1
# Entry-point script: seeds a SQLite database and prints a verification report.
#
# Usage:
#   pwsh -File Invoke-DatabaseSeed.ps1
#   pwsh -File Invoke-DatabaseSeed.ps1 -DatabasePath ./mydb.db -Seed 1234

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

[CmdletBinding()]
param(
    [string]$DatabasePath = (Join-Path $PSScriptRoot 'seed.db'),
    [int]$UserCount    = 50,
    [int]$ProductCount = 20,
    [int]$OrderCount   = 200,
    [int]$Seed         = 42
)

# ---------------------------------------------------------------------------
# Ensure required modules
# ---------------------------------------------------------------------------
function Install-RequiredModules {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { [version]$_.Version -ge [version]'5.0.0' })) {
        Write-Host 'Installing Pester 5...'
        Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser -SkipPublisherCheck
    }

    if (-not (Get-Module -ListAvailable -Name PSSQLite)) {
        Write-Host 'Installing PSSQLite...'
        Install-Module -Name PSSQLite -Force -Scope CurrentUser
    }

    Import-Module PSSQLite -Force
}

Install-RequiredModules

# ---------------------------------------------------------------------------
# Load module
# ---------------------------------------------------------------------------
[string]$modulePath = Join-Path $PSScriptRoot 'DatabaseSeed.psm1'
Import-Module $modulePath -Force

# ---------------------------------------------------------------------------
# Clean up any previous database file
# ---------------------------------------------------------------------------
if (Test-Path $DatabasePath) {
    Remove-Item $DatabasePath -Force
    Write-Host "Removed existing database: $DatabasePath"
}

# ---------------------------------------------------------------------------
# Step 1: Create schema
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '=== Step 1: Initialising schema ===' -ForegroundColor Cyan
Initialize-DatabaseSchema -DatabasePath $DatabasePath
Write-Host "Schema created in: $DatabasePath"

# ---------------------------------------------------------------------------
# Step 2: Seed data
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '=== Step 2: Seeding data ===' -ForegroundColor Cyan
Write-Host "  Users:    $UserCount"
Write-Host "  Products: $ProductCount"
Write-Host "  Orders:   $OrderCount"
Write-Host "  Seed:     $Seed"

Import-SeedData `
    -DatabasePath $DatabasePath `
    -UserCount    $UserCount    `
    -ProductCount $ProductCount `
    -OrderCount   $OrderCount   `
    -Seed         $Seed

Write-Host 'Data inserted successfully.'

# ---------------------------------------------------------------------------
# Step 3: Verification report
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '=== Step 3: Verification report ===' -ForegroundColor Cyan

[PSCustomObject]$report = Invoke-VerificationQueries -DatabasePath $DatabasePath

Write-Host ''
Write-Host 'Row counts:'
Write-Host "  Users:    $($report.UserCount)"
Write-Host "  Products: $($report.ProductCount)"
Write-Host "  Orders:   $($report.OrderCount)"
Write-Host ''
Write-Host 'Data integrity:'
Write-Host "  Orphaned orders:      $($report.OrphanedOrders)"
Write-Host "  Price calc errors:    $($report.PriceErrors)"
Write-Host "  Active users:         $($report.ActiveUserPct)%"
Write-Host ''
Write-Host 'Top 5 spenders:'
$report.TopSpenders | ForEach-Object {
    Write-Host ("  {0,-30}  orders={1,-4}  spent={2}" -f [string]$_.username, [string]$_.order_count, [string]$_.total_spent)
}
Write-Host ''
Write-Host 'Revenue by category:'
$report.RevenueByCategory | ForEach-Object {
    Write-Host ("  {0,-25}  orders={1,-4}  revenue={2}" -f [string]$_.category, [string]$_.order_count, [string]$_.revenue)
}

# ---------------------------------------------------------------------------
# Step 4: Assert integrity (fail loudly if something is wrong)
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '=== Step 4: Integrity assertions ===' -ForegroundColor Cyan

if ($report.OrphanedOrders -ne 0) {
    throw "INTEGRITY FAILURE: $($report.OrphanedOrders) orphaned order(s) found"
}
if ($report.PriceErrors -ne 0) {
    throw "INTEGRITY FAILURE: $($report.PriceErrors) price calculation error(s) found"
}
if ($report.UserCount -ne $UserCount) {
    throw "COUNT MISMATCH: expected $UserCount users, found $($report.UserCount)"
}
if ($report.ProductCount -ne $ProductCount) {
    throw "COUNT MISMATCH: expected $ProductCount products, found $($report.ProductCount)"
}
if ($report.OrderCount -ne $OrderCount) {
    throw "COUNT MISMATCH: expected $OrderCount orders, found $($report.OrderCount)"
}

Write-Host 'All assertions passed.' -ForegroundColor Green
Write-Host ''
Write-Host "Database ready at: $DatabasePath" -ForegroundColor Green
