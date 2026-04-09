# Docker Image Tag Generator
# Generates appropriate Docker image tags based on git context following common conventions:
#   - "latest" for main/master branch
#   - "pr-{number}" for pull requests
#   - "v{semver}" for semver-tagged commits
#   - "{branch}-{short-sha}" for feature branches
# All tags are sanitized: lowercase, no special chars (replaced with hyphens)

<#
.SYNOPSIS
    Sanitizes a string for use as a Docker image tag component.

.DESCRIPTION
    Converts to lowercase, replaces invalid characters with hyphens,
    collapses consecutive hyphens, and trims leading/trailing hyphens.

.PARAMETER Tag
    The string to sanitize.
#>
function Get-SanitizedTag {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Tag
    )

    # Convert to lowercase
    $sanitized = $Tag.ToLower()
    # Replace any character that is not alphanumeric, dot, or hyphen with a hyphen
    # Note: underscores are also replaced — branch-derived tags use hyphens only
    $sanitized = $sanitized -replace '[^a-z0-9.-]', '-'
    # Collapse consecutive hyphens into one
    $sanitized = $sanitized -replace '-+', '-'
    # Trim leading and trailing hyphens
    $sanitized = $sanitized.Trim('-')

    return $sanitized
}

<#
.SYNOPSIS
    Returns the first 7 characters of a commit SHA (short SHA).

.PARAMETER Sha
    The full commit SHA string.
#>
function Get-ShortSha {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Sha
    )

    return $Sha.Substring(0, [Math]::Min(7, $Sha.Length))
}

<#
.SYNOPSIS
    Generates Docker image tags based on git context.

.DESCRIPTION
    Applies common Docker tagging conventions:
    - Semver git tags (v1.2.3) are always included when present
    - PR branches get "pr-{number}" tag
    - main/master gets "latest"
    - Feature branches get "{sanitized-branch}-{short-sha}"

.PARAMETER BranchName
    The git branch name (e.g., "main", "feature/my-feature").

.PARAMETER CommitSha
    The full commit SHA.

.PARAMETER GitTags
    Array of git tags pointing to this commit (optional).

.PARAMETER PrNumber
    The pull request number, if this is a PR build (optional).
#>
function New-DockerImageTags {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BranchName,

        [Parameter(Mandatory)]
        [string]$CommitSha,

        [Parameter()]
        [string[]]$GitTags = @(),

        [Parameter()]
        [string]$PrNumber = ""
    )

    $imageTags = [System.Collections.Generic.List[string]]::new()
    $shortSha = Get-ShortSha -Sha $CommitSha

    # Pattern for semver tags: v{major}.{minor}.{patch} with optional pre-release suffix
    # Examples: v1.2.3, v1.2.3-beta.1, v1.2.3-rc1, v1.2
    $semverPattern = '^v\d+\.\d+(\.\d+)?(-[\w.]+)?$'

    # Always add semver tags when present — these are release tags
    foreach ($tag in $GitTags) {
        if ($tag -match $semverPattern) {
            $imageTags.Add($tag)
        }
    }

    if ($PrNumber -ne "") {
        # PR build: tag as pr-{number}
        $imageTags.Add("pr-$PrNumber")
    }
    elseif ($BranchName -eq "main" -or $BranchName -eq "master") {
        # Main/master branch: tag as "latest"
        $imageTags.Add("latest")
    }
    else {
        # Feature/other branch: sanitize branch name and append short SHA
        $sanitizedBranch = Get-SanitizedTag -Tag $BranchName
        $imageTags.Add("$sanitizedBranch-$shortSha")
    }

    return $imageTags.ToArray()
}

# Detect direct execution (not dot-sourced) by checking script invocation
# When dot-sourced, $MyInvocation.Line starts with '.'
# When run directly, execute CLI behavior using environment variables
$isDirectExecution = $MyInvocation.InvocationName -ne '.' -and
                     $MyInvocation.InvocationName -ne '' -and
                     $PSCommandPath -ne $null -and
                     $MyInvocation.Line -notmatch '^\s*\.'

if ($isDirectExecution) {
    $Branch = $env:BRANCH_NAME
    $Sha    = $env:COMMIT_SHA
    $Tags   = $env:GIT_TAGS        # Comma-separated list
    $Pr     = $env:PR_NUMBER

    if (-not $Branch) {
        Write-Error "Branch name is required. Set BRANCH_NAME environment variable."
        exit 1
    }
    if (-not $Sha) {
        Write-Error "Commit SHA is required. Set COMMIT_SHA environment variable."
        exit 1
    }

    $tagArray = if ($Tags) { $Tags -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } } else { @() }
    $prNum    = if ($Pr) { $Pr } else { "" }

    $dockerTags = New-DockerImageTags -BranchName $Branch -CommitSha $Sha -GitTags $tagArray -PrNumber $prNum

    Write-Output "Generated Docker image tags:"
    foreach ($t in $dockerTags) {
        Write-Output "  $t"
    }

    # Machine-readable output for CI pipeline consumption
    $tagsJoined = $dockerTags -join ','
    Write-Output "DOCKER_TAGS=$tagsJoined"
}
