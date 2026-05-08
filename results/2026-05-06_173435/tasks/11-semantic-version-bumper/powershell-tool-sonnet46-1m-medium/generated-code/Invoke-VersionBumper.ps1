# CLI entry point for the semantic version bumper.
# Dot-sources Bump-Version.ps1 to use its functions.
param(
    [string]$Path = ".",
    [string[]]$Commits,
    [string]$CommitFile,
    [string]$Date = (Get-Date -Format "yyyy-MM-dd")
)

. "$PSScriptRoot/Bump-Version.ps1"

if ($CommitFile -and (Test-Path $CommitFile)) {
    $Commits = Get-Content $CommitFile
}

if (-not $Commits -or $Commits.Count -eq 0) {
    Write-Error "No commits provided. Use -Commits or -CommitFile."
    exit 1
}

$result = Invoke-SemanticVersionBump -Path $Path -Commits $Commits -Date $Date
Write-Output "New version: $($result.NewVersion)"
Write-Output ""
Write-Output $result.Changelog
