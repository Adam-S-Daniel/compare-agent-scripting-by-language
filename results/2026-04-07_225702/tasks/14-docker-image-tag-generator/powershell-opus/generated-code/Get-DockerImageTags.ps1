# Docker Image Tag Generator
# Generates appropriate Docker image tags based on git context:
#   - "latest" for main/master branches
#   - "pr-{number}" for pull requests
#   - "v{semver}" for semver tags
#   - "{branch}-{short-sha}" for feature branches
# All tags are sanitized: lowercase, no special characters.

function ConvertTo-DockerTag {
    # Sanitizes a string to be a valid Docker tag.
    # Docker tags allow: [a-zA-Z0-9_.-]
    # We replace slashes and other invalid chars with hyphens,
    # collapse runs of hyphens, trim leading/trailing hyphens, and lowercase.
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $result = $Value.ToLower()
    # Replace slashes and invalid chars (anything not alphanumeric, hyphen, dot, underscore) with hyphen
    $result = $result -replace '[^a-z0-9._-]', '-'
    # Collapse consecutive hyphens
    $result = $result -replace '-{2,}', '-'
    # Trim leading/trailing hyphens
    $result = $result.Trim('-')

    return $result
}

function Get-DockerImageTags {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BranchName,

        [Parameter(Mandatory = $true)]
        [string]$CommitSha,

        [Parameter()]
        [string]$Tag,

        [Parameter()]
        [int]$PrNumber
    )

    # Validate required inputs
    if ([string]::IsNullOrWhiteSpace($BranchName)) {
        throw "BranchName cannot be empty. Provide the git branch name."
    }
    if ([string]::IsNullOrWhiteSpace($CommitSha)) {
        throw "CommitSha cannot be empty. Provide the git commit SHA."
    }

    $tags = @()

    # Main/master branch gets the "latest" tag (compare lowercase for robustness)
    $branchLower = $BranchName.ToLower()
    if ($branchLower -eq 'main' -or $branchLower -eq 'master') {
        $tags += 'latest'
    }

    # Pull requests get a "pr-{number}" tag
    if ($PrNumber -gt 0) {
        $tags += "pr-$PrNumber"
    }

    # Feature branches get a "{branch}-{short-sha}" tag (not main/master)
    if ($branchLower -ne 'main' -and $branchLower -ne 'master') {
        $shortSha = $CommitSha.Substring(0, [Math]::Min(7, $CommitSha.Length)).ToLower()
        $sanitizedBranch = ConvertTo-DockerTag -Value $BranchName
        $tags += "$sanitizedBranch-$shortSha"
    }

    # Git tags: normalize semver with "v" prefix, pass others through
    if (-not [string]::IsNullOrWhiteSpace($Tag)) {
        if ($Tag -match '^\d+\.\d+\.\d+') {
            # Bare semver — add "v" prefix
            $tags += ConvertTo-DockerTag -Value "v$Tag"
        } else {
            $tags += ConvertTo-DockerTag -Value $Tag
        }
    }

    # Sanitize all tags and remove any empty/duplicate entries
    $tags = $tags | ForEach-Object { ConvertTo-DockerTag -Value $_ } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique

    return @($tags)
}
