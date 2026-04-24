# CLI entry. Reads a version file and commit log, bumps the version, updates
# the changelog, and prints a machine-parseable result. Designed to be called
# from the GitHub Actions workflow.
#
# Output contract (on stdout):
#   OLD_VERSION=<x.y.z>
#   NEW_VERSION=<x.y.z>
#   BUMP_TYPE=<major|minor|patch|none>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $VersionFile,
    [Parameter(Mandatory)][string] $CommitLogFile,
    [string] $ChangelogFile = 'CHANGELOG.md',
    [string] $Date
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/SemanticVersionBumper.ps1"

try {
    $params = @{
        VersionFile   = $VersionFile
        CommitLogFile = $CommitLogFile
        ChangelogFile = $ChangelogFile
    }
    if ($Date) { $params['Date'] = $Date }
    $r = Invoke-VersionBump @params

    Write-Output "OLD_VERSION=$($r.OldVersion)"
    Write-Output "NEW_VERSION=$($r.NewVersion)"
    Write-Output "BUMP_TYPE=$($r.BumpType)"
    exit 0
} catch {
    Write-Error "Version bump failed: $($_.Exception.Message)"
    exit 1
}
