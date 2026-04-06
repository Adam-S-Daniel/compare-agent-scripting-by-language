# Generate-DockerTags.ps1
# CLI entry point for the Docker Image Tag Generator.
#
# Usage examples:
#   # Main branch build
#   .\Generate-DockerTags.ps1 -Branch main -CommitSha abc1234def5678
#
#   # PR build
#   .\Generate-DockerTags.ps1 -Branch feature/my-feature -CommitSha deadbeef1234 -PrNumber 42
#
#   # Release tag build
#   .\Generate-DockerTags.ps1 -Branch main -CommitSha cafebabe1234 -GitTags v1.2.3
#
#   # Feature branch
#   .\Generate-DockerTags.ps1 -Branch feature/add-login -CommitSha 1111aaaa2222
#
# Output: one Docker tag per line (suitable for use in shell scripts / GitHub Actions)

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Branch,

    [Parameter(Mandatory)]
    [string]$CommitSha,

    [Parameter()]
    [string[]]$GitTags = @(),

    [Parameter()]
    [Nullable[int]]$PrNumber = $null
)

# Import the module from the same directory as this script
$ModulePath = Join-Path $PSScriptRoot 'DockerTagGenerator.psm1'
Import-Module $ModulePath -Force

# Build the git context hashtable
[hashtable]$gitContext = @{
    Branch    = $Branch
    CommitSha = $CommitSha
    Tags      = $GitTags
    PrNumber  = $PrNumber
}

# Generate and output tags
[string[]]$tags = Get-DockerImageTags -GitContext $gitContext

Write-Host "Generated Docker image tags:" -ForegroundColor Cyan
foreach ($tag in $tags) {
    Write-Output $tag
}
