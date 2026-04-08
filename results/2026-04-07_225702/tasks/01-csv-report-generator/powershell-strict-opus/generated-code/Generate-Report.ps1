#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Main entry point: reads employee CSV, filters active employees,
    computes aggregates, and writes a formatted summary report.
.DESCRIPTION
    Usage: pwsh ./Generate-Report.ps1 [-CsvPath <path>] [-OutputPath <path>]
    Defaults to employees.csv in the script directory and report.txt output.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$CsvPath = (Join-Path $PSScriptRoot 'employees.csv'),

    [Parameter()]
    [string]$OutputPath = (Join-Path $PSScriptRoot 'report.txt')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Load the function library
. "$PSScriptRoot/EmployeeReport.ps1"

try {
    Write-Host "Reading employee data from: $CsvPath"
    [object[]]$allEmployees = Import-EmployeeCsv -Path $CsvPath

    Write-Host "Total records: $($allEmployees.Count)"
    [object[]]$activeEmployees = Get-ActiveEmployees -Employees $allEmployees
    Write-Host "Active employees: $($activeEmployees.Count)"

    Export-EmployeeReport -Employees $activeEmployees -OutputPath $OutputPath
    Write-Host "Report written to: $OutputPath"
}
catch {
    Write-Error "Failed to generate report: $_"
    exit 1
}
