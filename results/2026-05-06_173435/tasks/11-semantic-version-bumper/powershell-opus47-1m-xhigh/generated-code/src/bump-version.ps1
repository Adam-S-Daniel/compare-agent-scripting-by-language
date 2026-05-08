#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Conventional-Commits-driven semantic version bumper (CLI entrypoint).

.DESCRIPTION
    Locates a version file (package.json or VERSION) in -RepoRoot, walks
    the commit log (or a fixture file in test mode), figures out the
    appropriate bump (major/minor/patch/none), updates the version file
    and prepends a CHANGELOG.md entry.

    Outputs NEW_VERSION=x.y.z (and OLD_VERSION/BUMP_KIND) to stdout, and
    additionally writes to $GITHUB_OUTPUT when running under GitHub
    Actions / act so downstream steps can consume the values.

.PARAMETER RepoRoot
    Repository root containing the version file. Defaults to PWD.

.PARAMETER CommitsFile
    Optional path to a fixture file with commit messages separated by a
    line containing only '---COMMIT---'. When provided, git is NOT
    consulted — useful for unit-test fixtures and for environments
    without git history.

.PARAMETER Since
    Optional git ref to use as the lower bound for `git log <since>..HEAD`.
    When omitted, all reachable commits on HEAD are considered.

.PARAMETER Date
    ISO date string to use in the changelog header. Defaults to today.

.PARAMETER DryRun
    Compute and report the bump without writing anything to disk.

.EXAMPLE
    pwsh ./src/bump-version.ps1 -RepoRoot . -Since v1.0.0
#>

[CmdletBinding()]
param(
    [string]$RepoRoot = (Get-Location).Path,
    [string]$CommitsFile,
    [string]$Since,
    [string]$Date,
    [switch]$DryRun
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Import the module that lives next to this script.
$ModulePath = Join-Path $PSScriptRoot 'SemverBumper.psm1'
Import-Module $ModulePath -Force

function Get-CommitsFromGit {
    param([string]$RepoRoot, [string]$Since)

    Push-Location -LiteralPath $RepoRoot
    try {
        # Containers under act often complain about "dubious ownership" because
        # the bind-mount UID doesn't match the in-container user. Marking the
        # repo dir as safe is the documented workaround and is harmless outside
        # CI as well.
        & git config --global --add safe.directory $RepoRoot 2>$null | Out-Null

        # Use NUL as the record separator: commit messages can themselves
        # contain blank lines and even '---' style separators, so a printable
        # delimiter would not be safe.
        $rangeArg = if ($Since) { "$Since..HEAD" } else { 'HEAD' }
        $logOutput = & git log $rangeArg --format='%B%x00' 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "git log failed (exit $LASTEXITCODE): $logOutput"
        }
        if (-not $logOutput) { return @() }

        $combined = if ($logOutput -is [array]) { $logOutput -join "`n" } else { [string]$logOutput }
        # Each commit record ends in a NUL. git separates records with the
        # standard newline between log entries as well, so each record after
        # the first arrives with a leading newline that we need to strip.
        $records = $combined -split [char]0
        return @($records |
            ForEach-Object { $_.Trim("`r","`n"," ","`t") } |
            Where-Object   { -not [string]::IsNullOrWhiteSpace($_) })
    }
    finally { Pop-Location }
}

function Get-CommitsFromFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Commits fixture file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    # Records separated by a line consisting solely of '---COMMIT---'.
    $records = $raw -split "(?m)^---COMMIT---\s*$"
    return @($records |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim() })
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

try {
    if ($CommitsFile) {
        Write-Host "Reading commits from fixture file: $CommitsFile"
        $commits = Get-CommitsFromFile -Path $CommitsFile
    }
    else {
        Write-Host "Reading commits from git log (RepoRoot=$RepoRoot, Since='$Since')"
        $commits = Get-CommitsFromGit -RepoRoot $RepoRoot -Since $Since
    }

    Write-Host "Found $($commits.Count) commit(s):"
    foreach ($c in $commits) {
        $first = ($c -split "`r?`n")[0]
        Write-Host "  - $first"
    }

    if ($DryRun) {
        # Compute without writing — mirrors Invoke-VersionBump's logic but
        # skips the side-effecting tail.
        $vf      = Find-VersionFile -RepoRoot $RepoRoot
        $current = Read-VersionFile -Path $vf.Path
        $kind    = Get-BumpKind $commits
        $next    = Step-SemVer -SemVer (ConvertTo-SemVer $current.Version) -Kind $kind
        $result  = [pscustomobject]@{
            OldVersion  = $current.Version
            NewVersion  = (ConvertFrom-SemVer $next)
            BumpKind    = $kind
            VersionFile = $vf.Path
            Format      = $vf.Format
        }
    }
    else {
        $result = Invoke-VersionBump -RepoRoot $RepoRoot -CommitMessages $commits -Date $Date
    }

    Write-Host '----------------------------------------'
    Write-Host "OLD_VERSION=$($result.OldVersion)"
    Write-Host "NEW_VERSION=$($result.NewVersion)"
    Write-Host "BUMP_KIND=$($result.BumpKind)"
    Write-Host "VERSION_FILE=$($result.VersionFile)"
    Write-Host '----------------------------------------'

    # Surface the values to downstream GitHub Actions steps.
    if ($env:GITHUB_OUTPUT) {
        "old_version=$($result.OldVersion)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        "new_version=$($result.NewVersion)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        "bump_kind=$($result.BumpKind)"     | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    }

    return $result
}
catch {
    Write-Error "bump-version.ps1 failed: $($_.Exception.Message)"
    exit 1
}
