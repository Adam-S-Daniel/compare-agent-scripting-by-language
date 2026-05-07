# Thin CLI wrapper used by the GitHub Actions workflow.
# Reads a fixture JSON and policy parameters, prints the plan + summary lines
# the act test harness asserts against.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$FixturePath,
    [int]$MaxAgeDays = 0,
    [long]$MaxTotalSize = 0,
    [int]$KeepLatestNPerWorkflow = 0,
    [string]$NowIso = '',
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/Invoke-ArtifactCleanup.ps1"

$now = if ([string]::IsNullOrWhiteSpace($NowIso)) { Get-Date } else {
    [datetime]::Parse(
        $NowIso,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
            [System.Globalization.DateTimeStyles]::AdjustToUniversal)
}

# Pass only the policies the caller actually set (treat 0 as "unset").
$cliParams = @{ FixturePath = $FixturePath; Now = $now; DryRun = $DryRun }
if ($MaxAgeDays -gt 0)             { $cliParams.MaxAgeDays = $MaxAgeDays }
if ($MaxTotalSize -gt 0)           { $cliParams.MaxTotalSize = $MaxTotalSize }
if ($KeepLatestNPerWorkflow -gt 0) { $cliParams.KeepLatestNPerWorkflow = $KeepLatestNPerWorkflow }

$plan = Invoke-FromCli @cliParams

Write-Output (Format-CleanupPlan -Plan $plan)

# Machine-readable single-line markers the test harness greps for. Keeps
# parsing simple even with act's log-prefixing.
Write-Output "RESULT_DELETED_COUNT=$($plan.Summary.DeletedCount)"
Write-Output "RESULT_RETAINED_COUNT=$($plan.Summary.RetainedCount)"
Write-Output "RESULT_SPACE_RECLAIMED=$($plan.Summary.SpaceReclaimed)"
Write-Output "RESULT_DRYRUN=$($plan.Summary.DryRun)"
