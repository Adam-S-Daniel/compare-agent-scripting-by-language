#!/usr/bin/env pwsh
# CLI entrypoint: reads commits from a fixture file (one commit per '---' delimited block)
# or from 'git log' when -UseGit is supplied, then bumps the package.json version and
# appends a CHANGELOG.md entry. Outputs the new version to stdout.
[CmdletBinding()]
param(
    [string]$PackageJsonPath = './package.json',
    [string]$ChangelogPath = './CHANGELOG.md',
    [string]$CommitsFile,
    [switch]$UseGit,
    [string]$Since
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1') -Force

function Read-Commits {
    param([string]$Path, [switch]$Git, [string]$Since)
    if ($Git) {
        $gitArgs = @('log', '--format=%B%n---END---')
        if ($Since) { $gitArgs += "$Since..HEAD" }
        $raw = (& git @gitArgs) -join "`n"
        return ($raw -split '---END---') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        throw "Commits file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    return ($raw -split "(?m)^---$") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

$commits = Read-Commits -Path $CommitsFile -Git:$UseGit -Since $Since
$result = Invoke-VersionBump -PackageJsonPath $PackageJsonPath -ChangelogPath $ChangelogPath -Commits $commits

Write-Host "Previous version: $($result.PreviousVersion)"
Write-Host "Bump type: $($result.BumpType)"
Write-Host "New version: $($result.NewVersion)"
# Machine-parseable marker
Write-Output "VERSION=$($result.NewVersion)"
