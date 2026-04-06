# DockerTagGenerator.ps1
# Generates Docker image tags from git context following common CI/CD conventions.
#
# TDD history (red → green → refactor):
#  RED 1  – wrote test for main → "latest"          → added main/master branch check
#  RED 2  – wrote test for PR number                → added PullRequestNumber path
#  RED 3  – wrote test for git tags                 → added GitTags loop
#  RED 4  – wrote test for feature branch           → added branch-sha fallback
#  RED 5  – wrote sanitization tests                → extracted Invoke-SanitizeTag helper
#  RED 6  – wrote short-SHA test + length guard     → added Measure-ShortSha
#  RED 7  – wrote error-handling tests              → added parameter validation
#  RED 8  – integration scenarios                   → confirmed all rules compose correctly
#  REFACTOR – extracted helpers, added comments

# ---------------------------------------------------------------------------
# Helper: Invoke-SanitizeTag
# Converts a raw string into a valid Docker tag component:
#   1. Lowercase everything
#   2. Replace any character that is not [a-z0-9] with a hyphen
#   3. Collapse consecutive hyphens into one
#   4. Trim leading/trailing hyphens
# ---------------------------------------------------------------------------
function Invoke-SanitizeTag {
    param([string]$Raw)

    $sanitized = $Raw.ToLowerInvariant()
    # Replace any non-alphanumeric character with a hyphen
    $sanitized = $sanitized -replace '[^a-z0-9]', '-'
    # Collapse consecutive hyphens
    $sanitized = $sanitized -replace '-+', '-'
    # Trim leading/trailing hyphens
    $sanitized = $sanitized.Trim('-')

    return $sanitized
}

# ---------------------------------------------------------------------------
# Helper: Measure-ShortSha
# Returns the first 7 characters of a commit SHA.
# Throws if the SHA is shorter than 7 characters.
# ---------------------------------------------------------------------------
function Measure-ShortSha {
    param([string]$CommitSha)

    if ($CommitSha.Length -lt 7) {
        throw "CommitSha must be at least 7 characters long. Got: '$CommitSha' (length $($CommitSha.Length))."
    }
    return $CommitSha.Substring(0, 7)
}

# ---------------------------------------------------------------------------
# Main function: Get-DockerImageTags
#
# Parameters:
#   -Branch            (required) Git branch name
#   -CommitSha         (required) Full or partial commit SHA (>= 7 chars)
#   -GitTags           (optional) Array of git tag names on this commit
#   -PullRequestNumber (optional) PR number; when supplied, PR-mode is active
#
# Returns: [string[]] of Docker image tags
#
# Tag conventions applied (in order of priority):
#   1. PR context    → "pr-{number}"  (overrides main/latest)
#   2. Git tags      → each tag verbatim (e.g., "v1.2.3")
#   3. Main / master → "latest"
#   4. Other branch  → "{sanitized-branch}-{short-sha}"
# ---------------------------------------------------------------------------
function Get-DockerImageTags {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Branch,

        [Parameter(Mandatory)]
        [string]$CommitSha,

        [string[]]$GitTags = @(),

        [int]$PullRequestNumber = 0
    )

    # --- Input validation ---
    if ([string]::IsNullOrWhiteSpace($Branch)) {
        throw 'Branch must not be empty or whitespace.'
    }
    if ([string]::IsNullOrWhiteSpace($CommitSha)) {
        throw 'CommitSha must not be empty or whitespace.'
    }

    $shortSha = Measure-ShortSha -CommitSha $CommitSha
    $tags = [System.Collections.Generic.List[string]]::new()

    # Rule 1: Pull Request context — emit "pr-{number}" only.
    # PRs should never receive "latest" because they are not yet merged.
    if ($PullRequestNumber -gt 0) {
        $tags.Add("pr-$PullRequestNumber")
        # Do NOT add "latest" or branch tags for PRs.
        return $tags.ToArray()
    }

    # Rule 2: Git tags (release commits) — emit each tag verbatim.
    foreach ($gitTag in $GitTags) {
        if (-not [string]::IsNullOrWhiteSpace($gitTag)) {
            $tags.Add($gitTag)
        }
    }

    # Rule 3: Main / master branch — emit "latest".
    if ($Branch -eq 'main' -or $Branch -eq 'master') {
        $tags.Add('latest')
        return $tags.ToArray()
    }

    # Rule 4: Feature / other branch — emit "{sanitized-branch}-{short-sha}".
    $sanitizedBranch = Invoke-SanitizeTag -Raw $Branch
    $tags.Add("$sanitizedBranch-$shortSha")

    return $tags.ToArray()
}
