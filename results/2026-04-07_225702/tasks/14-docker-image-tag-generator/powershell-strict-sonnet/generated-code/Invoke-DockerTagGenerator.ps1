# Invoke-DockerTagGenerator.ps1
# Demo entrypoint: generates Docker image tags from mock git context inputs.
# Usage: pwsh ./Invoke-DockerTagGenerator.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'DockerTagGenerator.psm1') -Force

# --- Mock inputs representing common git scenarios ---
[hashtable[]]$scenarios = @(
    @{
        Label      = 'Main branch push'
        BranchName = 'main'
        CommitSha  = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0'
        Tags       = @()
        PrNumber   = $null
    },
    @{
        Label      = 'Pull request #42'
        BranchName = 'feature/my-new-feature'
        CommitSha  = 'deadbeefcafe1234567890abcdef1234567890ab'
        Tags       = @()
        PrNumber   = 42
    },
    @{
        Label      = 'Semver release tag v1.3.0'
        BranchName = 'main'
        CommitSha  = '1111222233334444555566667777888899990000'
        Tags       = @('v1.3.0', 'v1.3')
        PrNumber   = $null
    },
    @{
        Label      = 'Feature branch (no PR)'
        BranchName = 'feature/My_Awesome-Branch'
        CommitSha  = 'cafebabe1234567890abcdef1234567890abcdef'
        Tags       = @()
        PrNumber   = $null
    }
)

foreach ($scenario in $scenarios) {
    # Build the GitContext hashtable (exclude the Label key)
    [hashtable]$ctx = @{
        BranchName = [string]$scenario['BranchName']
        CommitSha  = [string]$scenario['CommitSha']
        Tags       = [array]$scenario['Tags']
        PrNumber   = $scenario['PrNumber']
    }

    [string[]]$tags = New-DockerImageTags -GitContext $ctx

    Write-Host "`n=== $($scenario['Label']) ===" -ForegroundColor Cyan
    Write-Host "  Branch : $($ctx['BranchName'])"
    Write-Host "  SHA    : $($ctx['CommitSha'])"
    Write-Host "  GitTags: $($ctx['Tags'] -join ', ')"
    Write-Host "  PR     : $($ctx['PrNumber'])"
    Write-Host "  => Docker tags:" -ForegroundColor Green
    foreach ($tag in $tags) {
        Write-Host "       $tag"
    }
}
