# Docker Image Tag Generator
# Generates Docker image tags from git context following common conventions:
#   - 'latest' for main/master branches
#   - 'pr-{number}' for pull requests
#   - 'v{semver}' for semver tags (strips leading 'v' if present, re-adds it)
#   - '{branch}-{short-sha}' for feature branches
#   - All tags are sanitized: lowercase, no special characters except hyphens/dots

function ConvertTo-SanitizedTag {
    <#
    .SYNOPSIS
        Sanitizes a string for use as a Docker image tag.
    .DESCRIPTION
        Docker image tags must be lowercase and can only contain
        alphanumeric characters, hyphens, dots, and underscores.
        Leading dots/hyphens are removed. Max length is 128 characters.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    # Convert to lowercase
    $sanitized = $Value.ToLower()

    # Replace slashes and underscores with hyphens (common in branch names like feature/foo)
    $sanitized = $sanitized -replace '[/_]', '-'

    # Remove any characters that aren't alphanumeric, hyphens, or dots
    $sanitized = $sanitized -replace '[^a-z0-9\.\-]', ''

    # Remove leading dots and hyphens
    $sanitized = $sanitized -replace '^[\.\-]+', ''

    # Remove trailing dots and hyphens
    $sanitized = $sanitized -replace '[\.\-]+$', ''

    # Collapse multiple consecutive hyphens into one
    $sanitized = $sanitized -replace '-{2,}', '-'

    # Docker tags have a max length of 128 characters
    if ($sanitized.Length -gt 128) {
        $sanitized = $sanitized.Substring(0, 128)
    }

    # If sanitization resulted in an empty string, return a fallback
    if ([string]::IsNullOrWhiteSpace($sanitized)) {
        Write-Error "Tag sanitization resulted in empty string for input: '$Value'"
        return $null
    }

    return $sanitized
}

function Get-DockerImageTags {
    <#
    .SYNOPSIS
        Generate Docker image tags from git context.
    .DESCRIPTION
        Given git context (branch name, commit SHA, tags, PR number),
        generates appropriate Docker image tags following common conventions.
    .PARAMETER BranchName
        The current git branch name (e.g., 'main', 'feature/my-feature').
    .PARAMETER CommitSha
        The full commit SHA (at least 7 characters for short SHA).
    .PARAMETER Tags
        Array of git tags pointing to the current commit (e.g., 'v1.2.3').
    .PARAMETER PrNumber
        The pull request number, if this build is for a PR.
    .EXAMPLE
        Get-DockerImageTags -BranchName 'main' -CommitSha 'abc1234567890'
        # Returns: @('latest')
    .EXAMPLE
        Get-DockerImageTags -BranchName 'feature/cool-thing' -CommitSha 'abc1234567890' -PrNumber 42
        # Returns: @('pr-42')
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$BranchName,

        [Parameter()]
        [string]$CommitSha,

        [Parameter()]
        [string[]]$Tags,

        [Parameter()]
        [int]$PrNumber = 0
    )

    # Validate that at least some context was provided
    if ([string]::IsNullOrWhiteSpace($BranchName) -and
        [string]::IsNullOrWhiteSpace($CommitSha) -and
        ($null -eq $Tags -or $Tags.Count -eq 0) -and
        $PrNumber -eq 0) {
        Write-Error "At least one of BranchName, CommitSha, Tags, or PrNumber must be provided."
        return @()
    }

    # Validate CommitSha if provided — must be at least 7 hex characters
    if (-not [string]::IsNullOrWhiteSpace($CommitSha)) {
        if ($CommitSha -notmatch '^[0-9a-fA-F]{7,}$') {
            Write-Error "CommitSha must be a valid hex string of at least 7 characters. Got: '$CommitSha'"
            return @()
        }
    }

    $result = [System.Collections.Generic.List[string]]::new()

    # Priority 1: Semver tags — if the commit has git tags matching semver, emit version tags
    if ($null -ne $Tags -and $Tags.Count -gt 0) {
        foreach ($tag in $Tags) {
            # Match semver pattern, with optional leading 'v'
            if ($tag -match '^v?(\d+\.\d+\.\d+.*)$') {
                $version = $Matches[1]
                $versionTag = "v$version"
                $sanitized = ConvertTo-SanitizedTag -Value $versionTag
                if ($null -ne $sanitized) {
                    $result.Add($sanitized)
                }
            }
        }
    }

    # Priority 2: PR number — if building from a PR, emit pr-{number}
    if ($PrNumber -gt 0) {
        $result.Add("pr-$PrNumber")
    }

    # Priority 3: Main/master branch — emit 'latest'
    $mainBranches = @('main', 'master')
    if ($mainBranches -contains $BranchName.ToLower()) {
        $result.Add('latest')
    }
    # Priority 4: Feature branch — emit {sanitized-branch}-{short-sha}
    elseif (-not [string]::IsNullOrWhiteSpace($BranchName) -and
            -not [string]::IsNullOrWhiteSpace($CommitSha)) {
        $shortSha = $CommitSha.Substring(0, [Math]::Min(7, $CommitSha.Length)).ToLower()
        $sanitizedBranch = ConvertTo-SanitizedTag -Value $BranchName
        if ($null -ne $sanitizedBranch) {
            $result.Add("$sanitizedBranch-$shortSha")
        }
    }

    return $result.ToArray()
}
