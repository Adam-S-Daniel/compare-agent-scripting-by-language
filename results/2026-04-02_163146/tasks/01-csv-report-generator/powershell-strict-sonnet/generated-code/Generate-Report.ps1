# Generate-Report.ps1
# Entry-point script: reads the employee CSV, computes aggregates, writes report.
# Usage: pwsh -File Generate-Report.ps1 [-CsvPath <path>] [-OutputPath <path>]

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

[CmdletBinding()]
param(
    [string] $CsvPath    = (Join-Path $PSScriptRoot 'fixtures' 'employees.csv'),
    [string] $OutputPath = (Join-Path $PSScriptRoot 'output'   'employee-report.txt')
)

# Import the module
Import-Module (Join-Path $PSScriptRoot 'EmployeeReport.psm1') -Force

Write-Host "Reading employee data from: $CsvPath"
[PSCustomObject[]] $all = Import-EmployeeData -Path $CsvPath
Write-Host "  Total records loaded: $($all.Count)"

[PSCustomObject[]] $active = Get-ActiveEmployees -Employees $all
Write-Host "  Active employees   : $($active.Count)"

[PSCustomObject[]] $deptAggregates = Get-DepartmentAggregates -Employees $active
[PSCustomObject]   $overallStats   = Get-OverallStatistics     -Employees $active

Write-SummaryReport `
    -DepartmentAggregates $deptAggregates `
    -OverallStatistics    $overallStats `
    -OutputPath           $OutputPath

Write-Host "Report written to: $OutputPath"
