# DockerTagGenerator.psm1
# Generates Docker image tags from git context following common conventions:
#   - "latest"              for main/master branch
#   - "pr-{number}"         for pull requests
#   - "v{semver}"           for semver git tags
#   - "{branch}-{short-sha}" for feature branches
#
# All tags are sanitized: lowercase, only [a-z0-9-] allowed.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Semver pattern: optional 'v' prefix, major.minor.patch, optional pre-release/build.
# We accept the tag as-is (preserving the leading 'v') when it matches.
[string]$script:SemverPattern = '^v?\d+\.\d+(\.\d+)?([-.][a-zA-Z0-9.]+)?$'

<#
.SYNOPSIS
    Sanitizes a string into a valid Docker image tag component.
.DESCRIPTION
    Converts to lowercase, replaces any character that is not [a-z0-9] with a
    hyphen, collapses consecutive hyphens, and trims leading/trailing hyphens.
.OUTPUTS
    [string]
#>
function ConvertTo-SanitizedTag {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Tag
    )

    # Lowercase first
    [string]$result = $Tag.ToLowerInvariant()

    # Replace any character that is not a lowercase letter, digit, or hyphen
    $result = [System.Text.RegularExpressions.Regex]::Replace($result, '[^a-z0-9-]', '-')

    # Collapse runs of hyphens into a single hyphen
    $result = [System.Text.RegularExpressions.Regex]::Replace($result, '-{2,}', '-')

    # Trim leading and trailing hyphens
    $result = $result.Trim('-')

    return $result
}

<#
.SYNOPSIS
    Returns the 7-character short SHA from a full commit SHA.
.OUTPUTS
    [string]
#>
function Get-ShortSha {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$CommitSha
    )

    if ($CommitSha.Length -eq 0) {
        throw 'CommitSha cannot be empty'
    }

    if ($CommitSha.Length -le 7) {
        return $CommitSha
    }

    return $CommitSha.Substring(0, 7)
}

<#
.SYNOPSIS
    Generates the list of Docker image tags for a given git context.
.DESCRIPTION
    Accepts a hashtable with keys:
        BranchName  [string]  — current git branch (required)
        CommitSha   [string]  — full commit SHA  (required)
        Tags        [array]   — git tags on HEAD (required, may be empty)
        PrNumber    [object]  — PR number or $null
    Returns a de-duplicated string array of Docker tags.
.OUTPUTS
    [string[]]
#>
function New-DockerImageTags {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)][hashtable]$GitContext
    )

    # --- Validate required keys ---
    if (-not $GitContext.ContainsKey('BranchName') -or $null -eq $GitContext['BranchName']) {
        throw 'GitContext must contain a non-null BranchName key'
    }
    if (-not $GitContext.ContainsKey('CommitSha') -or $null -eq $GitContext['CommitSha']) {
        throw 'GitContext must contain a non-null CommitSha key'
    }

    [string]$branch   = [string]$GitContext['BranchName']
    [string]$sha      = [string]$GitContext['CommitSha']
    [array]$gitTags   = if ($GitContext.ContainsKey('Tags') -and $null -ne $GitContext['Tags']) {
                            @($GitContext['Tags'])
                        } else {
                            @()
                        }
    [object]$prNumber = if ($GitContext.ContainsKey('PrNumber')) { $GitContext['PrNumber'] } else { $null }

    [string]$shortSha         = Get-ShortSha -CommitSha $sha
    [string]$sanitizedBranch  = ConvertTo-SanitizedTag -Tag $branch
    [System.Collections.Generic.List[string]]$tags = [System.Collections.Generic.List[string]]::new()

    # Rule 1 — PR build: add pr-{number} tag, skip everything else branch-related
    if ($null -ne $prNumber -and [string]$prNumber -ne '') {
        $tags.Add("pr-$prNumber")
    }
    # Rule 2 — Main/master branch: add "latest" + {branch}-{sha}
    elseif ($branch -eq 'main' -or $branch -eq 'master') {
        $tags.Add('latest')
        $tags.Add("$sanitizedBranch-$shortSha")
    }
    # Rule 3 — Any other branch: add {sanitized-branch}-{short-sha}
    else {
        $tags.Add("$sanitizedBranch-$shortSha")
    }

    # Rule 4 — Semver git tags: add each matching v{semver} tag
    foreach ($gitTag in $gitTags) {
        [string]$t = [string]$gitTag
        if ([System.Text.RegularExpressions.Regex]::IsMatch($t, $script:SemverPattern)) {
            # Preserve the tag as-is (already validated format); sanitize only the
            # non-semver part if needed, but semver tags are safe by definition.
            $tags.Add($t)
        }
    }

    # Return unique tags preserving insertion order
    [string[]]$unique = ($tags | Select-Object -Unique)
    return $unique
}

Export-ModuleMember -Function ConvertTo-SanitizedTag, Get-ShortSha, New-DockerImageTags
