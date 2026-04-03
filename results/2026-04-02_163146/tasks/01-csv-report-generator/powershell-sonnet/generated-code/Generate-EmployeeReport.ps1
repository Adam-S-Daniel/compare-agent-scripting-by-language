# Generate-EmployeeReport.ps1
# Main entry point for the CSV employee report generator.
#
# Usage:
#   ./Generate-EmployeeReport.ps1 -CsvPath ./fixtures/employees.csv -OutputPath ./report.txt
#
# The script reads the CSV, filters active employees, computes stats,
# and writes a formatted summary report to the output file.

param(
    [string]$CsvPath    = "./fixtures/employees.csv",
    [string]$OutputPath = "./report.txt"
)

# Load the implementation functions.
. "$PSScriptRoot/src/CsvReportGenerator.ps1"

try {
    Write-Host "Reading employee data from: $CsvPath"
    $all      = Read-EmployeeCsv -Path $CsvPath

    Write-Host "Filtering active employees..."
    $active   = Get-ActiveEmployees -Employees $all

    Write-Host "Computing department statistics..."
    $deptStats    = Get-DepartmentStats -Employees $active

    Write-Host "Computing overall statistics..."
    $overallStats = Get-OverallStats -Employees $active

    Write-Host "Writing report..."
    Write-SummaryReport -DepartmentStats $deptStats -OverallStats $overallStats -OutputPath $OutputPath

    Write-Host "Done."
}
catch {
    Write-Error "Report generation failed: $_"
    exit 1
}
