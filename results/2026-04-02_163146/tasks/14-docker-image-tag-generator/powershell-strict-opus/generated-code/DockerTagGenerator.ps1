# DockerTagGenerator.ps1
# Generates Docker image tags from git context (branch, SHA, tags, PR number).
# Follows common conventions: "latest" for main, "pr-{n}" for PRs,
# "v{semver}" for tags, "{branch}-{sha}" for feature branches.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

function Format-SanitizedTag {
    <#
    .SYNOPSIS
        Sanitizes a raw string into a valid Docker image tag.
    .DESCRIPTION
        Lowercases the input, replaces characters that are not alphanumeric,
        dots, or underscores with hyphens, collapses consecutive hyphens,
        and trims leading/trailing hyphens.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$RawTag
    )

    # Step 1: Lowercase
    [string]$tag = $RawTag.ToLowerInvariant()

    # Step 2: Replace any character that is not alphanumeric, dot, or underscore with a hyphen
    $tag = [regex]::Replace($tag, '[^a-z0-9._]', '-')

    # Step 3: Collapse consecutive hyphens into a single hyphen
    $tag = [regex]::Replace($tag, '-{2,}', '-')

    # Step 4: Trim leading and trailing hyphens
    $tag = $tag.Trim('-')

    return $tag
}

function Get-DockerImageTags {
    <#
    .SYNOPSIS
        Generates a list of Docker image tags based on git context.
    .DESCRIPTION
        Given a branch name, commit SHA, optional git tags, and optional PR number,
        produces a list of Docker image tags following common conventions:
        - "latest" for main/master branches
        - "pr-{number}" for pull requests
        - "v{major}.{minor}.{patch}", "v{major}.{minor}", "v{major}" for semver tags
        - "{sanitized-branch}-{short-sha}" for feature branches
        - "sha-{short-sha}" always included
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$BranchName,

        [Parameter(Mandatory)]
        [string]$CommitSha,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$Tags = @(),

        [Parameter()]
        [AllowNull()]
        [Nullable[int]]$PrNumber = $null
    )

    # --- Validation ---
    if ([string]::IsNullOrWhiteSpace($BranchName)) {
        throw "BranchName cannot be empty or whitespace."
    }

    if ([string]::IsNullOrWhiteSpace($CommitSha)) {
        throw "CommitSha cannot be empty or whitespace."
    }

    if ($CommitSha.Length -lt 7) {
        throw "CommitSha must be at least 7 characters long, got $($CommitSha.Length)."
    }

    # --- Build tag list ---
    [System.Collections.Generic.List[string]]$dockerTags = [System.Collections.Generic.List[string]]::new()

    # Short SHA (first 7 chars, lowercased)
    [string]$shortSha = $CommitSha.Substring(0, 7).ToLowerInvariant()

    # Always include sha-{short-sha}
    $dockerTags.Add("sha-$shortSha")

    # Check if this is a main/master branch
    [bool]$isMainBranch = ($BranchName -eq 'main') -or ($BranchName -eq 'master')

    if ($isMainBranch) {
        $dockerTags.Add('latest')
    }

    # PR tag: pr-{number}
    if ($null -ne $PrNumber) {
        $dockerTags.Add("pr-$([int]$PrNumber)")
    }

    # Semver tags: parse each tag and generate version variants
    [string]$semverPattern = '^v?(\d+)\.(\d+)\.(\d+)(.*)$'
    foreach ($gitTag in $Tags) {
        [System.Text.RegularExpressions.Match]$match = [regex]::Match($gitTag, $semverPattern)
        if ($match.Success) {
            [string]$major = $match.Groups[1].Value
            [string]$minor = $match.Groups[2].Value
            [string]$patch = $match.Groups[3].Value

            # Full semver tag with v prefix
            $dockerTags.Add("v${major}.${minor}.${patch}")
            # Major.minor
            $dockerTags.Add("v${major}.${minor}")
            # Major only
            $dockerTags.Add("v${major}")
        }
    }

    # Feature branch tag: {sanitized-branch}-{short-sha}
    if (-not $isMainBranch) {
        [string]$sanitizedBranch = Format-SanitizedTag -RawTag $BranchName
        if (-not [string]::IsNullOrWhiteSpace($sanitizedBranch)) {
            $dockerTags.Add("${sanitizedBranch}-${shortSha}")
        }
    }

    # Deduplicate while preserving order
    [System.Collections.Generic.List[string]]$uniqueTags = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.HashSet[string]]$seen = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($tag in $dockerTags) {
        if ($seen.Add($tag)) {
            $uniqueTags.Add($tag)
        }
    }

    return [string[]]$uniqueTags.ToArray()
}

# --- CLI entry point: when run directly, demonstrate usage ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '') {
    # Only run demo when script is executed directly, not dot-sourced
    [bool]$isDirectRun = -not ($MyInvocation.Line -match '^\.\s')
    if ($isDirectRun -and $MyInvocation.CommandOrigin -eq 'Runspace') {
        Write-Host "Docker Image Tag Generator" -ForegroundColor Cyan
        Write-Host "=========================" -ForegroundColor Cyan
        Write-Host ""

        # Example 1: Main branch
        Write-Host "Example 1: Main branch" -ForegroundColor Yellow
        [string[]]$tags1 = Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890' -Tags @() -PrNumber $null
        Write-Host "  Tags: $($tags1 -join ', ')"
        Write-Host ""

        # Example 2: Feature branch with PR
        Write-Host "Example 2: Feature branch with PR #42" -ForegroundColor Yellow
        [string[]]$tags2 = Get-DockerImageTags -BranchName 'feature/add-login' -CommitSha 'def5678901234' -Tags @() -PrNumber ([Nullable[int]]42)
        Write-Host "  Tags: $($tags2 -join ', ')"
        Write-Host ""

        # Example 3: Tagged release on main
        Write-Host "Example 3: Tagged release v2.1.0 on main" -ForegroundColor Yellow
        [string[]]$tags3 = Get-DockerImageTags -BranchName 'main' -CommitSha 'aaa1111222233' -Tags @('v2.1.0') -PrNumber $null
        Write-Host "  Tags: $($tags3 -join ', ')"
        Write-Host ""
    }
}
