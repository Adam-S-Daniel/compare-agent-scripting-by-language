# Invoke-TestAggregator.ps1
# Entry-point script: parses test result files, aggregates across matrix runs,
# detects flaky tests, and writes a markdown summary.

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ResultsPath,

    [Parameter()]
    [string]$OutputPath = 'summary.md'
)

. "$PSScriptRoot/TestAggregator-Functions.ps1"

try {
    $allResults = Get-AllResults -ResultsPath $ResultsPath
    if ($allResults.Count -eq 0) {
        throw "No test result files found in '$ResultsPath'."
    }

    $flakyTests = Find-FlakyTests  -Results $allResults
    $summary    = New-MarkdownSummary -Results $allResults -FlakyTests $flakyTests

    $summary | Set-Content -Path $OutputPath -Encoding UTF8

    Write-Host "=== TEST AGGREGATOR SUMMARY ==="
    Write-Host $summary
    Write-Host "=== END SUMMARY ==="
    Write-Host "Summary written to: $OutputPath"

} catch {
    Write-Error "Aggregator failed: $_"
    exit 1
}
