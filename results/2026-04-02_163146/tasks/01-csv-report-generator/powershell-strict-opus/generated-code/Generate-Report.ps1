#!/usr/bin/env pwsh
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Generates an employee summary report from a CSV file.
.DESCRIPTION
    CLI entry point. Reads employee data, filters active employees,
    computes aggregates, and writes a formatted text report.
.EXAMPLE
    pwsh ./Generate-Report.ps1 -CsvPath ./employees.csv -OutputPath ./report.txt
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

# Import the module from the same directory as this script
Import-Module (Join-Path $PSScriptRoot 'EmployeeReport.psm1') -Force

try {
    New-EmployeeSummaryReport -CsvPath $CsvPath -OutputPath $OutputPath
    Write-Output "Report generated successfully: $OutputPath"
}
catch {
    Write-Error "Failed to generate report: $_"
    exit 1
}
