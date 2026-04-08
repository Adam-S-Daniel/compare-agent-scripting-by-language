# Run-SemanticVersionBumper.ps1
# CLI entry point for the semantic version bumper.
# Usage:
#   pwsh Run-SemanticVersionBumper.ps1 -VersionFile version.txt -CommitFile commits.txt
#   pwsh Run-SemanticVersionBumper.ps1 -VersionFile package.json -CommitFile commits.txt

param(
    [string]$VersionFile = "version.txt",
    [string]$CommitFile  = "",
    [string]$Date        = (Get-Date -Format "yyyy-MM-dd")
)

# Dot-source the library
. "$PSScriptRoot/SemanticVersionBumper.ps1"

$commits = @()
if ($CommitFile -and (Test-Path $CommitFile)) {
    $commits = Get-Content $CommitFile | Where-Object { $_.Trim() -ne "" }
}

$result = Invoke-SemanticVersionBump -VersionFile $VersionFile -Commits $commits -Date $Date

Write-Output "NEW_VERSION=$($result.NewVersion)"
Write-Output "BUMP_TYPE=$($result.BumpType)"
Write-Output ""
Write-Output $result.Changelog
