Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Demo script: generates Docker image tags for several mock git contexts.

. "$PSScriptRoot/Get-DockerImageTags.ps1"

# Define mock git contexts to demonstrate each tagging convention
[hashtable[]]$scenarios = @(
    @{
        Label      = 'Main branch build'
        BranchName = 'main'
        CommitSha  = 'a1b2c3d4e5f6789'
        Tags       = @()
        PrNumber   = $null
    },
    @{
        Label      = 'Pull request build'
        BranchName = 'feature/user-auth'
        CommitSha  = 'deadbeef0123456'
        Tags       = @()
        PrNumber   = [int]42
    },
    @{
        Label      = 'Semver release on main'
        BranchName = 'main'
        CommitSha  = 'f0f0f0f012345678'
        Tags       = @('v2.1.0')
        PrNumber   = $null
    },
    @{
        Label      = 'Feature branch (no PR)'
        BranchName = 'feature/Add-OAuth'
        CommitSha  = '9876543210abcdef'
        Tags       = @()
        PrNumber   = $null
    },
    @{
        Label      = 'Pre-release tag on main'
        BranchName = 'main'
        CommitSha  = 'cafe0123456789ab'
        Tags       = @('v3.0.0-rc.1')
        PrNumber   = $null
    }
)

foreach ($scenario in $scenarios) {
    [string]$label = [string]$scenario['Label']
    Write-Host "=== $label ===" -ForegroundColor Cyan

    # Build splatting hashtable without the Label key
    [hashtable]$params = @{
        BranchName = [string]$scenario['BranchName']
        CommitSha  = [string]$scenario['CommitSha']
        Tags       = [string[]]$scenario['Tags']
        PrNumber   = $scenario['PrNumber']
    }

    [string[]]$imageTags = Get-DockerImageTags @params
    foreach ($t in $imageTags) {
        Write-Host "  $t"
    }
    Write-Host ''
}
