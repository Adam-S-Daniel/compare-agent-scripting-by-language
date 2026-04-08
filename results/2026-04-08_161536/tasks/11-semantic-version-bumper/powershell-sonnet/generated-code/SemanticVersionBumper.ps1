# Semantic Version Bumper
# Parses version files, determines the next version based on conventional commits,
# updates the version file, and generates a changelog entry.
#
# Conventional Commits spec:
#   - feat: -> minor bump
#   - fix:  -> patch bump
#   - feat! or BREAKING CHANGE: -> major bump

#region Get-CurrentVersion
# Reads the current version from a version.txt or package.json file.
function Get-CurrentVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VersionFile,

        [ValidateSet("text", "json")]
        [string]$Format = "text"
    )

    if (-not (Test-Path $VersionFile)) {
        throw "Version file not found: $VersionFile"
    }

    $content = Get-Content -Path $VersionFile -Raw

    if ($Format -eq "json") {
        try {
            $json = $content | ConvertFrom-Json
        } catch {
            throw "Failed to parse JSON from ${VersionFile}: $_"
        }

        if ($null -eq $json.version) {
            throw "No version field found in $VersionFile"
        }

        return $json.version.Trim()
    }

    # text format: first non-empty line is the version
    $version = ($content -split "`n" | Where-Object { $_ -match '\S' } | Select-Object -First 1).Trim()
    if (-not $version) {
        throw "Version file $VersionFile is empty"
    }
    return $version
}
#endregion

#region Get-BumpType
# Analyzes conventional commit messages and returns "major", "minor", or "patch".
# Priority: major > minor > patch
function Get-BumpType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Commits
    )

    $bumpType = "patch"  # default

    foreach ($commit in $Commits) {
        # Check for breaking change: feat!/fix! prefix or BREAKING CHANGE in body/footer
        if ($commit -match '^(feat|fix|refactor|chore|docs|style|test|perf|ci)(\([^)]+\))?!:' -or
            $commit -match 'BREAKING CHANGE:') {
            return "major"  # highest priority, return immediately
        }

        # Check for feature commit -> minor
        if ($commit -match '^feat(\([^)]+\))?:') {
            $bumpType = "minor"
        }

        # fix, chore, docs etc. remain as patch (the default)
    }

    return $bumpType
}
#endregion

#region Get-NextVersion
# Calculates the next semantic version given the current version and bump type.
function Get-NextVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CurrentVersion,

        [Parameter(Mandatory)]
        [ValidateSet("major", "minor", "patch")]
        [string]$BumpType
    )

    # Validate semver format
    if ($CurrentVersion -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid semantic version: '$CurrentVersion'. Expected format: MAJOR.MINOR.PATCH"
    }

    $parts = $CurrentVersion -split '\.'
    [int]$major = $parts[0]
    [int]$minor = $parts[1]
    [int]$patch = $parts[2]

    switch ($BumpType) {
        "major" {
            $major++
            $minor = 0
            $patch = 0
        }
        "minor" {
            $minor++
            $patch = 0
        }
        "patch" {
            $patch++
        }
    }

    return "$major.$minor.$patch"
}
#endregion

#region Set-VersionFile
# Writes the new version to the version file (text or JSON format).
function Set-VersionFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VersionFile,

        [Parameter(Mandatory)]
        [string]$NewVersion,

        [ValidateSet("text", "json")]
        [string]$Format = "text"
    )

    if ($Format -eq "json") {
        $content = Get-Content -Path $VersionFile -Raw | ConvertFrom-Json
        $content.version = $NewVersion
        $content | ConvertTo-Json -Depth 10 | Set-Content -Path $VersionFile -NoNewline:$false
    } else {
        Set-Content -Path $VersionFile -Value $NewVersion
    }
}
#endregion

#region New-ChangelogEntry
# Generates a markdown changelog entry from conventional commits.
# Groups commits by type: Features, Bug Fixes, Other Changes.
function New-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$NewVersion,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Commits,

        [string]$Date = (Get-Date -Format "yyyy-MM-dd")
    )

    $features = [System.Collections.Generic.List[string]]::new()
    $bugFixes  = [System.Collections.Generic.List[string]]::new()
    $breaking  = [System.Collections.Generic.List[string]]::new()
    $other     = [System.Collections.Generic.List[string]]::new()

    foreach ($commit in $Commits) {
        $firstLine = ($commit -split "`n")[0].Trim()

        if ($firstLine -match '^(feat|fix|refactor|chore|docs|style|test|perf|ci)(\([^)]+\))?!:' -or
            $commit -match 'BREAKING CHANGE:') {
            $breaking.Add("- $firstLine")
        } elseif ($firstLine -match '^feat(\([^)]+\))?:') {
            $features.Add("- $firstLine")
        } elseif ($firstLine -match '^fix(\([^)]+\))?:') {
            $bugFixes.Add("- $firstLine")
        } else {
            $other.Add("- $firstLine")
        }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## [$NewVersion] - $Date")
    [void]$sb.AppendLine()

    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine("### Breaking Changes")
        foreach ($item in $breaking) { [void]$sb.AppendLine($item) }
        [void]$sb.AppendLine()
    }

    if ($features.Count -gt 0) {
        [void]$sb.AppendLine("### Features")
        foreach ($item in $features) { [void]$sb.AppendLine($item) }
        [void]$sb.AppendLine()
    }

    if ($bugFixes.Count -gt 0) {
        [void]$sb.AppendLine("### Bug Fixes")
        foreach ($item in $bugFixes) { [void]$sb.AppendLine($item) }
        [void]$sb.AppendLine()
    }

    if ($other.Count -gt 0) {
        [void]$sb.AppendLine("### Other Changes")
        foreach ($item in $other) { [void]$sb.AppendLine($item) }
        [void]$sb.AppendLine()
    }

    return $sb.ToString()
}
#endregion

#region Invoke-SemanticVersionBump
# Main orchestration function: reads version, determines bump type,
# updates the file, generates changelog, and returns a result object.
function Invoke-SemanticVersionBump {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VersionFile,

        [Parameter(Mandatory)]
        [string[]]$Commits,

        [ValidateSet("text", "json")]
        [string]$Format = "text",

        [string]$Date = (Get-Date -Format "yyyy-MM-dd")
    )

    # Step 1: Read current version
    $oldVersion = Get-CurrentVersion -VersionFile $VersionFile -Format $Format

    # Step 2: Determine bump type from commits
    $bumpType = Get-BumpType -Commits $Commits

    # Step 3: Calculate new version
    $newVersion = Get-NextVersion -CurrentVersion $oldVersion -BumpType $bumpType

    # Step 4: Update the version file
    Set-VersionFile -VersionFile $VersionFile -NewVersion $newVersion -Format $Format

    # Step 5: Generate changelog entry
    $changelogEntry = New-ChangelogEntry -NewVersion $newVersion -Commits $Commits -Date $Date

    # Return structured result
    return [PSCustomObject]@{
        OldVersion     = $oldVersion
        NewVersion     = $newVersion
        BumpType       = $bumpType
        ChangelogEntry = $changelogEntry
    }
}
#endregion

# Allow script to be run directly (not just dot-sourced for tests)
if ($MyInvocation.InvocationName -ne '.') {
    # When executed directly, look for version.txt or package.json and mock commits
    $versionFile = Join-Path $PSScriptRoot "version.txt"
    $format = "text"

    if (-not (Test-Path $versionFile)) {
        $versionFile = Join-Path $PSScriptRoot "package.json"
        $format = "json"
    }

    if (-not (Test-Path $versionFile)) {
        Write-Error "No version.txt or package.json found in $PSScriptRoot"
        exit 1
    }

    # Load commits from fixture file if available, otherwise use git log
    $fixtureFile = Join-Path $PSScriptRoot "fixtures/mock-commits.txt"
    if (Test-Path $fixtureFile) {
        $commits = Get-Content -Path $fixtureFile
    } else {
        # Attempt to read from git log
        try {
            $commits = & git log --pretty=format:"%s" -n 20 2>$null
        } catch {
            $commits = @("fix: default patch bump when no commits available")
        }
    }

    $result = Invoke-SemanticVersionBump -VersionFile $versionFile -Commits $commits -Format $format
    Write-Output "Version bumped: $($result.OldVersion) -> $($result.NewVersion) ($($result.BumpType))"
    Write-Output ""
    Write-Output $result.ChangelogEntry
}
