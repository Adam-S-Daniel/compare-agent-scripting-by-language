# Get-DockerImageTags.ps1
# Generates Docker image tags based on git context following common conventions:
# - "latest" for main/master branches
# - "pr-{number}" for pull requests
# - "v{semver}", "{major}.{minor}.{patch}", "{major}.{minor}" for semver tags
# - "{branch}-{short-sha}" for all branches
# All tags are sanitized: lowercase, no special chars except hyphens.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$BranchName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$CommitSha,

    [Parameter()]
    [string[]]$Tags = @(),

    [Parameter()]
    [int]$PrNumber = 0
)

# Sanitize a string for Docker tag use: lowercase, replace non-alphanumeric
# chars with hyphens, collapse consecutive hyphens, trim leading/trailing hyphens.
function ConvertTo-DockerTagSafe {
    param([string]$Value)
    $result = $Value.ToLower()
    $result = $result -replace '[^a-z0-9-]', '-'
    $result = $result -replace '-{2,}', '-'
    $result = $result.Trim('-')
    return $result
}

# Extract first 7 characters of SHA for the short reference
$shortSha = $CommitSha.Substring(0, [Math]::Min(7, $CommitSha.Length))
$sanitizedBranch = ConvertTo-DockerTagSafe -Value $BranchName
$dockerTags = [System.Collections.Generic.List[string]]::new()

# Rule 1: "latest" for main or master branches
if ($sanitizedBranch -eq 'main' -or $sanitizedBranch -eq 'master') {
    $dockerTags.Add('latest')
}

# Rule 2: "pr-{number}" for pull requests
if ($PrNumber -gt 0) {
    $dockerTags.Add("pr-$PrNumber")
}

# Rule 3: Semver tags generate multiple Docker tags (full, without-v, major.minor)
foreach ($tag in $Tags) {
    if ($tag -match '^v?(\d+\.\d+\.\d+.*)$') {
        $version = $Matches[1]
        if ($tag.StartsWith('v')) {
            $dockerTags.Add($tag.ToLower())
        }
        $dockerTags.Add($version.ToLower())
        if ($version -match '^(\d+\.\d+)') {
            $dockerTags.Add($Matches[1])
        }
    }
}

# Rule 4: "{branch}-{short-sha}" for every branch
$dockerTags.Add("$sanitizedBranch-$shortSha")

# Output each tag
foreach ($t in $dockerTags) {
    Write-Output $t
}
