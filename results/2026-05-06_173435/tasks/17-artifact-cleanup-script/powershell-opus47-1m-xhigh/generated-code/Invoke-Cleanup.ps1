<#
.SYNOPSIS
    Entry-point script for the artifact-cleanup workflow. Loads a fixture JSON,
    applies retention policies, and prints the deletion plan to stdout.

.DESCRIPTION
    The workflow at .github/workflows/artifact-cleanup-script.yml invokes this
    script with -InputPath fixtures/active.json. The harness rotates the active
    fixture for each test case before running act.

    All policy parameters can be specified on the command line OR carried inside
    the fixture file alongside the artifacts list. CLI flags take precedence
    when both are present (zero / unspecified means "use what's in the JSON").
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $InputPath,
    [int]      $MaxAgeDays = 0,
    [long]     $MaxTotalSizeBytes = 0,
    [int]      $KeepLatestPerWorkflow = 0,
    [string]   $Now,
    [switch]   $DryRun
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
Import-Module (Join-Path $here 'ArtifactCleanup.psm1') -Force

try {
    $invokeArgs = @{ InputPath = $InputPath }
    if ($MaxAgeDays            -gt 0) { $invokeArgs.MaxAgeDays            = $MaxAgeDays }
    if ($MaxTotalSizeBytes     -gt 0) { $invokeArgs.MaxTotalSizeBytes     = $MaxTotalSizeBytes }
    if ($KeepLatestPerWorkflow -gt 0) { $invokeArgs.KeepLatestPerWorkflow = $KeepLatestPerWorkflow }
    if ($PSBoundParameters.ContainsKey('Now') -and $Now) {
        $invokeArgs.Now = [datetime]::Parse($Now, $null, [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal)
    }
    if ($DryRun) { $invokeArgs.DryRun = $true }

    $plan = Invoke-ArtifactCleanup @invokeArgs
    Format-CleanupPlanText -Plan $plan | Write-Output
    exit 0
} catch {
    Write-Error "Cleanup failed: $($_.Exception.Message)"
    exit 1
}
