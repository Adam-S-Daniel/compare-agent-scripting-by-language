# Invoke-SemanticVersionBump.ps1
# CLI entry point: reads a version file and a commits JSON, bumps the version,
# optionally writes a changelog entry, and prints the new version.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$VersionFile,

    [Parameter(Mandatory=$true)]
    [string]$CommitsFile,

    [string]$ChangelogFile = "",

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Import-Module "$PSScriptRoot/SemanticVersionBumper.psm1" -Force

$currentVersion = Get-VersionFromFile -FilePath $VersionFile
$commits        = Read-CommitsFile    -FilePath $CommitsFile
$bumpType       = Get-BumpType        -Commits $commits
$newVersion     = Get-NextVersion     -CurrentVersion $currentVersion -BumpType $bumpType

Update-VersionFile -FilePath $VersionFile -NewVersion $newVersion -DryRun:$DryRun

if ($ChangelogFile) {
    $entry = New-ChangelogEntry -NewVersion $newVersion -Commits $commits
    if ($DryRun) {
        Write-Host "[DryRun] Changelog entry:`n$entry"
    } else {
        $existing = ""
        if (Test-Path $ChangelogFile) { $existing = Get-Content $ChangelogFile -Raw }
        Set-Content -Path $ChangelogFile -Value ($entry + "`n" + $existing) -NoNewline
    }
}

Write-Host "Bumped $currentVersion -> $newVersion ($bumpType)"
Write-Output $newVersion
