# ArtifactCleanup.ps1
# Entry point: loads retention policies, evaluates artifacts, and prints a deletion plan.
# Supports dry-run mode (--DryRun). Reference date is parameterised for testability.

param(
    [Parameter(Mandatory = $true)]
    [string]$ArtifactsFile,

    [Parameter(Mandatory = $true)]
    [string]$PolicyFile,

    [switch]$DryRun,

    [ValidateSet("text", "json")]
    [string]$OutputFormat = "text",

    # Override "today" for deterministic testing
    [datetime]$ReferenceDate = (Get-Date)
)

$ErrorActionPreference = "Stop"

# Load the core functions from the module next to this script
$modulePath = Join-Path $PSScriptRoot "ArtifactCleanup.psm1"
if (-not (Test-Path $modulePath)) {
    Write-Error "Module not found at: $modulePath"
    exit 1
}
Import-Module $modulePath -Force

try {
    $artifacts = Get-ArtifactsFromFile -Path $ArtifactsFile
    $policy    = Get-PolicyFromFile    -Path $PolicyFile
}
catch {
    Write-Error "Failed to load input files: $_"
    exit 1
}

try {
    $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $ReferenceDate
    $plan   = New-DeletionPlan -Artifacts $artifacts -DeletionDecisions $result.ToDelete -DryRun:$DryRun
}
catch {
    Write-Error "Policy evaluation failed: $_"
    exit 1
}

if ($OutputFormat -eq "json") {
    $plan | ConvertTo-Json -Depth 5
} else {
    Format-DeletionPlan -Plan $plan
}
