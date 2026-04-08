#!/usr/bin/env pwsh
# bump-version.ps1
# CLI entry point for the semantic version bumper.
# Usage: ./bump-version.ps1 -VersionFile <path> [-ChangelogFile <path>] [-CommitRange <range>]
#
# If no CommitRange is given, reads from stdin or uses "HEAD~10..HEAD" as default.

param(
    [Parameter(Mandatory = $false)]
    [string]$VersionFile = './VERSION',

    [Parameter(Mandatory = $false)]
    [string]$ChangelogFile = './CHANGELOG.md',

    [Parameter(Mandatory = $false)]
    [string]$CommitRange = ''
)

# Import the library functions
. "$PSScriptRoot/SemanticVersionBumper.ps1"

# Gather commit messages either from git log or from a fixture file
try {
    if ($CommitRange -and (Test-Path $CommitRange)) {
        # If CommitRange points to a file, read commits from it (for testing)
        $commits = Get-Content -Path $CommitRange | Where-Object { $_.Trim() -ne '' }
    }
    elseif ($CommitRange) {
        # Use git log with the given range
        $commits = git log --oneline $CommitRange 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "git log failed, using empty commit list"
            $commits = @()
        }
    }
    else {
        # Default: try recent commits, fall back to empty
        $commits = git log --oneline -10 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "git log failed (not in a git repo?), using empty commit list"
            $commits = @()
        }
    }

    # Ensure commits is an array
    if ($null -eq $commits) { $commits = @() }
    if ($commits -is [string]) { $commits = @($commits) }

    # Run the version bump
    $newVersion = Invoke-VersionBump -VersionFilePath $VersionFile `
        -CommitMessages $commits -ChangelogPath $ChangelogFile

    # Output for CI pipelines (set as GitHub Actions output)
    if ($env:GITHUB_OUTPUT) {
        "new_version=$newVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
    }

    exit 0
}
catch {
    Write-Error "Version bump failed: $_"
    exit 1
}
