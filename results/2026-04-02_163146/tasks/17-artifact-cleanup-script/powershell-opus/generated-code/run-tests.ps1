#!/usr/bin/env pwsh
# Run all Pester tests and exit with appropriate code
$result = Invoke-Pester -Path './ArtifactCleanup.Tests.ps1' -Output Detailed -PassThru
exit $result.FailedCount
