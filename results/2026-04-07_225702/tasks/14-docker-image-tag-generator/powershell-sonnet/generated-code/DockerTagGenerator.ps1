# DockerTagGenerator.ps1
# Generates Docker image tags from git context following common CI/CD conventions:
#   - main/master branch      → "latest"
#   - PR (any branch + PR #)  → "pr-{number}"
#   - Semver git tag          → "v{semver}" and bare "{semver}"
#   - Feature branch          → "{sanitized-branch}-{short-sha}"
#
# Tag sanitization rules (Docker tag spec):
#   1. Lowercase the entire string
#   2. Replace '/' (and any other non-alphanumeric, non-hyphen, non-dot char) with '-'
#   3. Collapse runs of '--+' into a single '-'
#   4. Trim leading/trailing hyphens

function Get-SanitizedBranch {
    <#
    .SYNOPSIS
        Sanitizes a branch name so it is safe to embed in a Docker image tag.
    #>
    param([string]$Branch)

    $sanitized = $Branch.ToLower()
    # Replace anything that isn't a-z, 0-9, hyphen, or dot with a hyphen
    $sanitized = $sanitized -replace '[^a-z0-9\-\.]', '-'
    # Collapse consecutive hyphens
    $sanitized = $sanitized -replace '-{2,}', '-'
    # Trim leading/trailing hyphens
    $sanitized = $sanitized.Trim('-')
    return $sanitized
}

function Get-DockerImageTags {
    <#
    .SYNOPSIS
        Returns a list of Docker image tags for the given git context.

    .PARAMETER Branch
        The current git branch name (e.g. "main", "feature/my-feature"). Required.

    .PARAMETER CommitSha
        The full (or at least 8-character) git commit SHA. Required.

    .PARAMETER PrNumber
        Optional pull-request number. When supplied the tag "pr-{number}" is
        added and the branch-sha tag is omitted.

    .PARAMETER GitTag
        Optional semver git tag (e.g. "v1.2.3"). When supplied both the full tag
        and the bare version (without leading 'v') are added.

    .EXAMPLE
        Get-DockerImageTags -Branch "main" -CommitSha "abcdef0123456789"
        # → @("latest")

    .EXAMPLE
        Get-DockerImageTags -Branch "feature/login" -CommitSha "deadbeef1234" -PrNumber 7
        # → @("pr-7")

    .EXAMPLE
        Get-DockerImageTags -Branch "main" -CommitSha "abcdef0123456789" -GitTag "v2.1.0"
        # → @("latest", "v2.1.0", "2.1.0")
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)][string]$Branch,
        [Parameter(Mandatory)][string]$CommitSha,
        [int]   $PrNumber = 0,
        [string]$GitTag   = ""
    )

    # ── Input validation ───────────────────────────────────────────────────────
    if ([string]::IsNullOrWhiteSpace($Branch)) {
        throw "Branch must not be empty."
    }
    if ([string]::IsNullOrWhiteSpace($CommitSha)) {
        throw "CommitSha must not be empty."
    }
    if ($CommitSha.Length -lt 8) {
        throw "CommitSha must be at least 8 characters long (got $($CommitSha.Length))."
    }

    # ── Derived values ─────────────────────────────────────────────────────────
    $shortSha = $CommitSha.Substring(0, 8)
    $tags     = [System.Collections.Generic.List[string]]::new()

    # ── Rule 1: semver git tag ─────────────────────────────────────────────────
    # Add both "v1.2.3" and "1.2.3" when a git tag is present.
    if (-not [string]::IsNullOrWhiteSpace($GitTag)) {
        $tags.Add($GitTag)
        # Strip leading 'v' to also publish the bare semver
        if ($GitTag -match '^v(.+)$') {
            $tags.Add($Matches[1])
        }
    }

    # ── Rule 2: pull-request branch ───────────────────────────────────────────
    # A PR number takes precedence over the branch-sha tag.
    if ($PrNumber -gt 0) {
        $tags.Add("pr-$PrNumber")
    }
    else {
        # ── Rule 3: main / master branch → latest ─────────────────────────────
        if ($Branch -eq "main" -or $Branch -eq "master") {
            $tags.Add("latest")
        }
        else {
            # ── Rule 4: feature branch → {sanitized-branch}-{short-sha} ───────
            $sanitizedBranch = Get-SanitizedBranch -Branch $Branch
            $tags.Add("$sanitizedBranch-$shortSha")
        }
    }

    # ── Deduplicate while preserving order ────────────────────────────────────
    $seen   = [System.Collections.Generic.HashSet[string]]::new()
    $unique = foreach ($tag in $tags) {
        if ($seen.Add($tag)) { $tag }
    }

    return [string[]]$unique
}
