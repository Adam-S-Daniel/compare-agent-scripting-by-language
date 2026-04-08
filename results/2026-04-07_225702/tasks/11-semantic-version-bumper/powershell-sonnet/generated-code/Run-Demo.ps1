# Run-Demo.ps1
# Demonstrates the semantic version bumper using the fixture files.
# Usage: pwsh Run-Demo.ps1

. "$PSScriptRoot/VersionBumper.ps1"

$fixturesDir = "$PSScriptRoot/fixtures"

# Helper: load commits from a fixture file (skip comment lines)
function Get-CommitsFromFile([string]$Path) {
    Get-Content $Path |
        Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$' }
}

Write-Host "`n=== Semantic Version Bumper Demo ===" -ForegroundColor Cyan

foreach ($scenario in @("patch", "minor", "major")) {
    Write-Host "`n--- Scenario: $scenario ---" -ForegroundColor Yellow

    # Work in a temp directory so we don't mutate the fixture files
    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "vbdemo-$scenario"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    # Copy fixtures into temp dir
    Copy-Item "$fixturesDir/package.json" "$tmpDir/package.json"
    $changelogPath = "$tmpDir/CHANGELOG.md"
    $commits = Get-CommitsFromFile "$fixturesDir/commits-$scenario.txt"

    $currentVersion = Get-CurrentVersion -VersionFilePath "$tmpDir/package.json"
    Write-Host "  Current version : $currentVersion"
    Write-Host "  Commits         :"
    $commits | ForEach-Object { Write-Host "    $_" }

    $newVersion = Invoke-SemanticVersionBump `
        -VersionFilePath "$tmpDir/package.json" `
        -Commits $commits `
        -ChangelogPath $changelogPath `
        -Date (Get-Date -Format "yyyy-MM-dd")

    Write-Host "  New version     : $newVersion" -ForegroundColor Green
    Write-Host "`n  Changelog entry:"
    Get-Content $changelogPath | ForEach-Object { Write-Host "    $_" }

    Remove-Item -Recurse -Force $tmpDir
}

Write-Host "`n=== Done ===" -ForegroundColor Cyan
