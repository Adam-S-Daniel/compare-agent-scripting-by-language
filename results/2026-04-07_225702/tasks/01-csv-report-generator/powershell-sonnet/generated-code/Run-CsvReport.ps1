# Run-CsvReport.ps1
# Main entry point — orchestrates the full pipeline:
#   1. Load CSV  2. Filter active  3. Compute stats  4. Write report

param(
    [string]$CsvPath    = "$PSScriptRoot/fixtures/employees.csv",
    [string]$OutputPath = "$PSScriptRoot/report.txt"
)

# Dot-source the library functions
. "$PSScriptRoot/CsvReportGenerator.ps1"

try {
    Write-Host "Loading employee data from: $CsvPath"
    $employees = Import-EmployeeCsv -Path $CsvPath

    Write-Host "Filtering active employees..."
    $active = Get-ActiveEmployees -Employees $employees

    Write-Host "Computing department statistics..."
    $deptStats = Get-DepartmentStats -Employees $active

    Write-Host "Computing overall statistics..."
    $overallStats = Get-OverallStats -Employees $active

    Write-Host "Writing report to: $OutputPath"
    Write-SummaryReport -DepartmentStats $deptStats -OverallStats $overallStats -OutputPath $OutputPath

    Write-Host "Done. Report generated successfully."
}
catch {
    Write-Error "Report generation failed: $_"
    exit 1
}
