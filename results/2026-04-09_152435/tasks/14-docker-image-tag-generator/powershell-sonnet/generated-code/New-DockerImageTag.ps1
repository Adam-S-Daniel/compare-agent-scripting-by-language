# New-DockerImageTag.ps1
# Generates Docker image tags from git context following common conventions:
#   - latest          -> main/master branch
#   - pr-{number}     -> pull requests
#   - v{semver}       -> semver git tags (e.g. v1.2.3)
#   - {branch}-{sha}  -> feature branches (sanitized)
#
# Can be dot-sourced (for testing) or run directly (uses env vars).

# ---------------------------------------------------------------------------
# Tag sanitization: lowercase, alphanumeric + dash only, no leading/trailing/
# consecutive dashes.
# ---------------------------------------------------------------------------
function Get-SanitizedTag {
    param(
        [Parameter(Mandatory)]
        [string]$Tag
    )

    # Convert to lowercase
    $result = $Tag.ToLower()

    # Replace any character that is NOT a lowercase letter, digit, or dash with a dash
    $result = $result -replace '[^a-z0-9-]', '-'

    # Remove leading and trailing dashes
    $result = $result.Trim('-')

    # Collapse consecutive dashes into a single dash
    $result = $result -replace '-+', '-'

    return $result
}

# ---------------------------------------------------------------------------
# Core tag generation logic.
# Priority:
#   1. PR number provided -> only return pr-{number}
#   2. Semver git tags present -> add v{semver} tags; add 'latest' if main/master
#   3. Main/master branch -> 'latest' + '{branch}-{sha}'
#   4. Any other branch -> '{sanitized-branch}-{sha}'
# ---------------------------------------------------------------------------
function Get-DockerImageTags {
    param(
        [Parameter(Mandatory)]
        [string]$BranchName,

        [Parameter(Mandatory)]
        [string]$CommitSha,

        [string[]]$GitTags = @(),

        [string]$PrNumber = ""
    )

    $tags = [System.Collections.Generic.List[string]]::new()

    # Truncate SHA to 7 characters (standard Docker/git short SHA)
    $shortSha = $CommitSha.Substring(0, [Math]::Min(7, $CommitSha.Length))

    $sanitizedBranch = Get-SanitizedTag -Tag $BranchName
    $isMainBranch = ($sanitizedBranch -eq "main" -or $sanitizedBranch -eq "master")

    # Rule 1: Pull Request — only generate the pr-{number} tag
    if ($PrNumber -ne "") {
        $tags.Add("pr-$PrNumber")
        return [string[]]$tags.ToArray()
    }

    # Rule 2: Semver git tags — include versioned tags and possibly 'latest'
    $semverPattern = '^v\d+\.\d+'
    $semverTags = $GitTags | Where-Object { $_ -match $semverPattern }
    foreach ($semverTag in $semverTags) {
        $tags.Add($semverTag)
    }

    if ($semverTags.Count -gt 0) {
        # Add 'latest' if this semver release is on the main branch
        if ($isMainBranch) {
            $tags.Add("latest")
        }
        return [string[]]$tags.ToArray()
    }

    # Rule 3: Main/master branch
    if ($isMainBranch) {
        $tags.Add("latest")
        $tags.Add("$sanitizedBranch-$shortSha")
        return [string[]]$tags.ToArray()
    }

    # Rule 4: Feature branch (sanitized branch name + short SHA)
    $tags.Add("$sanitizedBranch-$shortSha")
    return [string[]]$tags.ToArray()
}

# ---------------------------------------------------------------------------
# Entry point when the script is invoked directly (not dot-sourced).
# Reads configuration from environment variables.
# ---------------------------------------------------------------------------
if ($MyInvocation.InvocationName -ne '.') {
    $branchName = if ($env:BRANCH_NAME) { $env:BRANCH_NAME } else { "main" }
    $commitSha  = if ($env:COMMIT_SHA)  { $env:COMMIT_SHA  } else { "0000000" }
    $prNumber   = if ($env:PR_NUMBER)   { $env:PR_NUMBER   } else { "" }

    # GIT_TAGS is a comma-separated list; split and strip whitespace
    $gitTags = @()
    if ($env:GIT_TAGS -and $env:GIT_TAGS.Trim() -ne "") {
        $gitTags = $env:GIT_TAGS -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    }

    $tags = Get-DockerImageTags -BranchName $branchName -CommitSha $commitSha -GitTags $gitTags -PrNumber $prNumber
    $tags | ForEach-Object { Write-Host $_ }
}
