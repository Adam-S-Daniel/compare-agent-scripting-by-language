# DockerTagGenerator.psm1
# Generates Docker image tags from git context following common CI/CD conventions.
#
# Conventions:
#   - main/master branch  → "latest" + short-sha
#   - PR branches         → "pr-{number}" + short-sha
#   - semver git tags     → "v{semver}" + bare semver (no v prefix) + latest (if on main)
#   - feature branches    → "{sanitized-branch}-{short-sha}"
#
# Tag sanitization rules:
#   - All lowercase
#   - Slashes  → dashes
#   - Underscores → dashes
#   - Consecutive dashes → single dash
#   - Leading/trailing dashes stripped

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Private helper: sanitize a raw string into a valid Docker tag segment
# ---------------------------------------------------------------------------
function Invoke-SanitizeTag {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    # Lowercase first
    [string]$sanitized = $Value.ToLower()

    # Replace slashes and underscores with dashes
    $sanitized = $sanitized -replace '[/_]', '-'

    # Replace any character that is not alphanumeric, dash, or dot with a dash
    $sanitized = $sanitized -replace '[^a-z0-9\-\.]', '-'

    # Collapse consecutive dashes into one
    $sanitized = $sanitized -replace '-{2,}', '-'

    # Trim leading/trailing dashes
    $sanitized = $sanitized.Trim('-')

    return $sanitized
}

# ---------------------------------------------------------------------------
# Private helper: extract the 7-character short SHA from a full commit SHA
# ---------------------------------------------------------------------------
function Get-ShortSha {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$CommitSha
    )

    if ($CommitSha.Length -lt 7) {
        throw "CommitSha '$CommitSha' is too short — must be at least 7 characters."
    }

    return $CommitSha.Substring(0, 7).ToLower()
}

# ---------------------------------------------------------------------------
# Private helper: determine if a branch name is a main/default branch
# ---------------------------------------------------------------------------
function Test-IsDefaultBranch {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Branch
    )

    $defaultBranches = @('main', 'master')
    return $defaultBranches -contains $Branch.ToLower()
}

# ---------------------------------------------------------------------------
# Private helper: determine if a string looks like a semver tag
# e.g. v1.2.3, v1.2.3-rc1, 1.2.3
# ---------------------------------------------------------------------------
function Test-IsSemverTag {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Tag
    )

    # Matches optional v prefix, then major.minor.patch with optional pre-release
    return $Tag -match '^v?\d+\.\d+\.\d+(-[a-zA-Z0-9\.\-]+)?$'
}

# ---------------------------------------------------------------------------
# Public: Get-DockerImageTags
# Main entry point — given a git context hashtable, return the list of tags.
#
# GitContext keys:
#   Branch    [string]   — current branch name (required)
#   CommitSha [string]   — full commit SHA (required, min 7 chars)
#   Tags      [string[]] — git tags pointing at this commit (optional, defaults to @())
#   PrNumber  [int?]     — PR number if this is a PR build (optional, null = not a PR)
# ---------------------------------------------------------------------------
function Get-DockerImageTags {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$GitContext
    )

    # --- Validate required keys ---
    if (-not $GitContext.ContainsKey('Branch')) {
        throw "GitContext is missing required key 'Branch'."
    }
    if (-not $GitContext.ContainsKey('CommitSha')) {
        throw "GitContext is missing required key 'CommitSha'."
    }

    [string]$branch    = [string]$GitContext['Branch']
    [string]$commitSha = [string]$GitContext['CommitSha']

    if ([string]::IsNullOrWhiteSpace($branch)) {
        throw "GitContext 'Branch' must not be empty."
    }
    if ([string]::IsNullOrWhiteSpace($commitSha)) {
        throw "GitContext 'CommitSha' must not be empty."
    }

    # Tags and PrNumber are optional
    [string[]]$gitTags = @()
    if ($GitContext.ContainsKey('Tags') -and $null -ne $GitContext['Tags']) {
        $gitTags = [string[]]$GitContext['Tags']
    }

    $prNumber = $null
    if ($GitContext.ContainsKey('PrNumber') -and $null -ne $GitContext['PrNumber']) {
        $prNumber = $GitContext['PrNumber']
    }

    # Compute short SHA once (7 chars, lowercase)
    [string]$shortSha = Get-ShortSha -CommitSha $commitSha

    # Accumulate tags in a list, then deduplicate at the end
    [System.Collections.Generic.List[string]]$tagList = [System.Collections.Generic.List[string]]::new()

    # --- Rule 1: PR builds ---
    if ($null -ne $prNumber) {
        $tagList.Add("pr-$prNumber")
        $tagList.Add($shortSha)
    }
    # --- Rule 2: Default branch (main/master) ---
    elseif (Test-IsDefaultBranch -Branch $branch) {
        $tagList.Add('latest')
        $tagList.Add($shortSha)
    }
    # --- Rule 3: Feature/other branches ---
    else {
        [string]$sanitizedBranch = Invoke-SanitizeTag -Value $branch
        $tagList.Add("$sanitizedBranch-$shortSha")
        $tagList.Add($shortSha)
    }

    # --- Rule 4: Git semver tags (additive — apply on top of branch rules) ---
    foreach ($gitTag in $gitTags) {
        if (Test-IsSemverTag -Tag $gitTag) {
            # Always include the tag as-is (lowercased/sanitized)
            [string]$sanitizedTag = Invoke-SanitizeTag -Value $gitTag
            $tagList.Add($sanitizedTag)

            # Also add bare semver (strip leading 'v' if present)
            if ($gitTag.StartsWith('v') -or $gitTag.StartsWith('V')) {
                [string]$bareVersion = $gitTag.Substring(1)
                $tagList.Add($bareVersion)
            }
        }
    }

    # Deduplicate while preserving order, and ensure all are lowercase
    [System.Collections.Generic.List[string]]$seen = [System.Collections.Generic.List[string]]::new()
    foreach ($tag in $tagList) {
        [string]$lower = $tag.ToLower()
        if (-not $seen.Contains($lower)) {
            $seen.Add($lower)
        }
    }

    return [string[]]$seen.ToArray()
}

# ---------------------------------------------------------------------------
# Public: Invoke-DockerTagGeneratorCli
# CLI-friendly wrapper — writes tags to the success pipeline (one per line
# when printed to stdout) and returns them as a string array.
# ---------------------------------------------------------------------------
function Invoke-DockerTagGeneratorCli {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$GitContext
    )

    [string[]]$tags = Get-DockerImageTags -GitContext $GitContext

    # Write each tag to the pipeline (stdout when run from shell).
    # Do NOT also use 'return' — that would double the output.
    Write-Output $tags
}

Export-ModuleMember -Function 'Get-DockerImageTags', 'Invoke-DockerTagGeneratorCli'
