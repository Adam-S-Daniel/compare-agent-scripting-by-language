Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Generates Docker image tags based on git context (branch, commit, tags, PR number).

.DESCRIPTION
    Follows common Docker tagging conventions:
      - "latest" for main/master branches
      - "pr-{number}" for pull requests
      - "v{semver}" for semver tags
      - "{branch}-{short-sha}" for feature branches
    All tags are sanitized: lowercased, special characters replaced with hyphens.
#>

# Sanitize a string for use as a Docker tag: lowercase, replace non-alphanumeric
# sequences with a single hyphen, trim leading/trailing hyphens.
function ConvertTo-DockerTagSafe {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    [string]$sanitized = $Value.ToLowerInvariant()
    # Replace any run of characters that aren't alphanumeric or dots with a hyphen
    $sanitized = [regex]::Replace($sanitized, '[^a-z0-9.]+', '-')
    # Trim leading/trailing hyphens
    $sanitized = $sanitized.Trim('-')
    return $sanitized
}

function Get-DockerImageTags {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BranchName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CommitSha,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$Tags = @(),

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [Nullable[int]]$PrNumber = $null
    )

    # Collect all generated tags
    [System.Collections.Generic.List[string]]$result = [System.Collections.Generic.List[string]]::new()

    # Main/master branch gets the "latest" tag
    if ($BranchName -eq 'main' -or $BranchName -eq 'master') {
        $result.Add('latest')
    }

    # Pull request builds get a "pr-{number}" tag
    if ($null -ne $PrNumber) {
        $result.Add("pr-$($PrNumber.ToString())")
    }

    # Semver tags: match v{major}.{minor}.{patch} with optional pre-release suffix
    [string]$semverPattern = '^v\d+\.\d+\.\d+(-[a-zA-Z0-9.\-]+)?$'
    foreach ($tag in $Tags) {
        if ([regex]::IsMatch($tag, $semverPattern)) {
            $result.Add([string]$tag)
        }
    }

    # Every build gets a {sanitized-branch}-{short-sha} tag for traceability
    [string]$shortSha = $CommitSha.Substring(0, [System.Math]::Min(7, $CommitSha.Length))
    [string]$safeBranch = ConvertTo-DockerTagSafe -Value $BranchName
    $result.Add("${safeBranch}-${shortSha}")

    return [string[]]$result.ToArray()
}
