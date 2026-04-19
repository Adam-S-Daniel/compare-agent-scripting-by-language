param(
    [string]$PackagePath = "package.json",
    [string]$ChangelogPath = "CHANGELOG.md",
    [string]$CommitsFile = $null,
    [string[]]$Commits = $null
)

$ErrorActionPreference = "Stop"

# Source the main functions
. (Join-Path $PSScriptRoot 'semantic-version-bumper.ps1')

try {
    # Read commits from various sources in priority order
    if ($Commits -and $Commits.Count -gt 0) {
        Write-Host "Using commits from parameter"
        $finalCommits = $Commits
    } elseif ($CommitsFile -and (Test-Path $CommitsFile)) {
        Write-Host "Reading commits from file: $CommitsFile"
        $finalCommits = @(Get-Content -Path $CommitsFile)
    } else {
        # Try to get commits from git log
        if (Test-Path ".git") {
            Write-Host "Attempting to read commits from git log"
            # For workflow context, try to get commits from the current ref
            $gitLog = @(git log --pretty=format:"%B" -n 10 2>/dev/null || @())
            if ($gitLog.Count -gt 0) {
                $finalCommits = $gitLog
                Write-Host "Found $($finalCommits.Count) commits from git"
            } else {
                Write-Warning "No commits found in git log. Using empty commit list."
                $finalCommits = @()
            }
        } else {
            Write-Host "No .git directory found. Using empty commit list."
            $finalCommits = @()
        }
    }

    if ($finalCommits.Count -eq 0) {
        Write-Host "No commits to process. Version unchanged."
        $currentVersion = Get-CurrentVersion -Path $PackagePath
        Write-Host "::set-output name=version::$currentVersion"
        exit 0
    }

    # Perform version update
    $result = Update-SemanticVersion -PackagePath $PackagePath -ChangelogPath $ChangelogPath -Commits $finalCommits

    Write-Host "Version updated: $($result.PreviousVersion) → $($result.NewVersion)"
    Write-Host ""
    Write-Host "Changelog:"
    Write-Host $result.Changelog
    Write-Host ""
    Write-Host "::set-output name=version::$($result.NewVersion)"
    Write-Host "::set-output name=previous-version::$($result.PreviousVersion)"

} catch {
    Write-Error "Error: $_"
    exit 1
}
