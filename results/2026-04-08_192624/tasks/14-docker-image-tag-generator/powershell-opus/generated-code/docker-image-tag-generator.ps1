#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates Docker image tags based on git context.

.DESCRIPTION
    Given git context (branch name, commit SHA, tags, PR number), generates
    appropriate Docker image tags following common conventions:
    - "latest" for main/master branches
    - "pr-{number}" for pull requests
    - "v{semver}" for semver tags
    - "{branch}-{short-sha}" for feature branches
    All tags are sanitized: lowercase, no special characters except hyphens and dots.

.PARAMETER BranchName
    The git branch name (e.g., "main", "feature/my-feature").

.PARAMETER CommitSha
    The full commit SHA.

.PARAMETER Tag
    A git tag (e.g., "v1.2.3"). Optional.

.PARAMETER PrNumber
    The pull request number. Optional.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$BranchName = "",

    [Parameter(Mandatory = $false)]
    [string]$CommitSha = "",

    [Parameter(Mandatory = $false)]
    [string]$Tag = "",

    [Parameter(Mandatory = $false)]
    [string]$PrNumber = ""
)

# Sanitize a string for use as a Docker tag:
# - Convert to lowercase
# - Replace any character that is not alphanumeric, hyphen, or dot with a hyphen
# - Collapse consecutive hyphens into one
# - Trim leading/trailing hyphens
function Sanitize-DockerTag {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $sanitized = $Value.ToLower()
    # Replace special chars (slashes, underscores, etc.) with hyphens
    $sanitized = $sanitized -replace '[^a-z0-9.\-]', '-'
    # Collapse multiple consecutive hyphens
    $sanitized = $sanitized -replace '-{2,}', '-'
    # Trim leading/trailing hyphens
    $sanitized = $sanitized.Trim('-')

    return $sanitized
}

# Extract short SHA (first 7 characters)
function Get-ShortSha {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FullSha
    )

    if ($FullSha.Length -ge 7) {
        return $FullSha.Substring(0, 7).ToLower()
    }
    return $FullSha.ToLower()
}

# Main tag generation logic
function Get-DockerImageTags {
    param(
        [string]$BranchName = "",
        [string]$CommitSha = "",
        [string]$Tag = "",
        [string]$PrNumber = ""
    )

    $tags = @()

    # Validate that we have at least some input
    if (-not $BranchName -and -not $Tag -and -not $PrNumber) {
        Write-Error "At least one of BranchName, Tag, or PrNumber must be provided."
        return @()
    }

    # 1. If a semver tag is provided, produce version tags
    if ($Tag) {
        $sanitizedTag = Sanitize-DockerTag -Value $Tag
        # Match semver pattern like v1.2.3 or 1.2.3 (with optional v prefix)
        if ($sanitizedTag -match '^v?(\d+\.\d+\.\d+.*)$') {
            $version = $Matches[1]
            $tags += "v$version"
            # Also add major.minor tag
            if ($version -match '^(\d+\.\d+)\.') {
                $tags += "v$($Matches[1])"
            }
            # Also add major tag
            if ($version -match '^(\d+)\.') {
                $tags += "v$($Matches[1])"
            }
        }
        else {
            # Non-semver tag, just sanitize and use it
            $tags += $sanitizedTag
        }
    }

    # 2. If a PR number is provided, produce pr-{number} tag
    if ($PrNumber) {
        $tags += "pr-$PrNumber"
    }

    # 3. Branch-based tags
    if ($BranchName) {
        $sanitizedBranch = Sanitize-DockerTag -Value $BranchName

        # Main/master branch gets "latest"
        if ($sanitizedBranch -eq "main" -or $sanitizedBranch -eq "master") {
            $tags += "latest"
        }

        # Feature branches get {branch}-{short-sha}
        if ($CommitSha -and $sanitizedBranch -ne "main" -and $sanitizedBranch -ne "master") {
            $shortSha = Get-ShortSha -FullSha $CommitSha
            $tags += "$sanitizedBranch-$shortSha"
        }
    }

    # Deduplicate and return
    $tags = $tags | Select-Object -Unique
    return $tags
}

# --- Entry point when run as a script ---
$result = Get-DockerImageTags -BranchName $BranchName -CommitSha $CommitSha -Tag $Tag -PrNumber $PrNumber

if ($result.Count -gt 0) {
    Write-Host "Generated Docker image tags:"
    foreach ($t in $result) {
        Write-Host "  - $t"
    }

    # Output as GitHub Actions output if running in CI
    if ($env:GITHUB_OUTPUT) {
        $tagList = $result -join ","
        "tags=$tagList" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
        Write-Host "::set-output name=tags::$tagList"
    }

    # Always output the comma-separated list for easy parsing
    Write-Host "TAG_LIST=$($result -join ',')"
}
else {
    Write-Error "No Docker image tags could be generated from the provided inputs."
    exit 1
}
