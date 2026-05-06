# SemanticVersionBumper.ps1
# Implements semantic versioning with conventional commits support

# Parse a semantic version string into major, minor, patch components
function Parse-SemanticVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VersionString
    )

    if ($VersionString -match '^(\d+)\.(\d+)\.(\d+)(?:-(.+))?$') {
        return @{
            Major      = [int]$Matches[1]
            Minor      = [int]$Matches[2]
            Patch      = [int]$Matches[3]
            Prerelease = $Matches[4]
        }
    }
    else {
        throw "Invalid semantic version format: $VersionString"
    }
}

# Parse a conventional commit message and extract type, subject, and breaking change flag
function Parse-ConventionalCommit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommitMessage
    )

    $breaking = $false
    $lines = $CommitMessage -split "`n"
    $headerLine = $lines[0]

    # Check for breaking change indicator (!)
    if ($headerLine -match '^(\w+)!:\s*(.+)$') {
        $type = $Matches[1]
        $subject = $Matches[2]
        $breaking = $true
    }
    # Standard format: type(scope): subject
    elseif ($headerLine -match '^(\w+)(?:\(.+\))?:\s*(.+)$') {
        $type = $Matches[1]
        $subject = $Matches[2]
    }
    else {
        throw "Invalid conventional commit format: $headerLine"
    }

    # Check for BREAKING CHANGE in footer
    if ($CommitMessage -match 'BREAKING[\s-]CHANGE') {
        $breaking = $true
    }

    return @{
        type    = $type
        subject = $subject
        breaking = $breaking
    }
}

# Determine the next version based on current version and commits
function Get-NextVersion {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$CurrentVersion,

        [Parameter(Mandatory = $true)]
        [array]$Commits
    )

    $bumpType = "none"  # none, patch, minor, major

    foreach ($commit in $Commits) {
        $commitType = $commit.type
        $isBreaking = $commit.breaking

        if ($isBreaking) {
            $bumpType = "major"
            break
        }
        elseif ($commitType -eq "feat" -and $bumpType -ne "major") {
            $bumpType = "minor"
        }
        elseif ($commitType -eq "fix" -and $bumpType -eq "none") {
            $bumpType = "patch"
        }
    }

    $newVersion = $CurrentVersion.Clone()

    switch ($bumpType) {
        "major" {
            $newVersion.Major += 1
            $newVersion.Minor = 0
            $newVersion.Patch = 0
        }
        "minor" {
            $newVersion.Minor += 1
            $newVersion.Patch = 0
        }
        "patch" {
            $newVersion.Patch += 1
        }
    }

    return $newVersion
}

# Update the version in a file (package.json or VERSION)
function Update-VersionFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$NewVersion
    )

    $fileName = Split-Path -Leaf $FilePath

    if ($fileName -eq "package.json") {
        $content = Get-Content $FilePath -Raw | ConvertFrom-Json
        $content.version = $NewVersion
        $content | ConvertTo-Json | Set-Content $FilePath
    }
    else {
        # Plain text file (VERSION, version.txt, etc.)
        $NewVersion | Set-Content $FilePath
    }
}

# Generate a changelog entry for the given version and commits
function Generate-ChangelogEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [array]$Commits
    )

    $date = Get-Date -Format "yyyy-MM-dd"
    $entry = "## $Version ($date)`n`n"

    $feats = @()
    $fixes = @()
    $other = @()

    foreach ($commit in $Commits) {
        $line = "- $($commit.subject)"

        switch ($commit.type) {
            "feat" { $feats += $line }
            "fix" { $fixes += $line }
            default { $other += $line }
        }
    }

    if ($feats.Count -gt 0) {
        $entry += "### Features`n`n" + ($feats -join "`n") + "`n`n"
    }

    if ($fixes.Count -gt 0) {
        $entry += "### Bug Fixes`n`n" + ($fixes -join "`n") + "`n`n"
    }

    if ($other.Count -gt 0) {
        $entry += "### Other`n`n" + ($other -join "`n") + "`n`n"
    }

    return $entry
}

# Main function: bump semantic version based on commits
function Invoke-SemanticVersionBump {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VersionFilePath,

        [Parameter(Mandatory = $true)]
        [array]$Commits
    )

    # Read current version
    $content = Get-Content $VersionFilePath -Raw

    $currentVersionStr = if ($VersionFilePath -match 'package\.json$') {
        ($content | ConvertFrom-Json).version
    }
    else {
        $content -replace '[\r\n]+', ''
    }

    $currentVersion = Parse-SemanticVersion $currentVersionStr

    # Determine next version
    $nextVersion = Get-NextVersion -CurrentVersion $currentVersion -Commits $Commits
    $nextVersionStr = "$($nextVersion.Major).$($nextVersion.Minor).$($nextVersion.Patch)"

    # Update version file
    Update-VersionFile -FilePath $VersionFilePath -NewVersion $nextVersionStr

    # Generate changelog
    $changelog = Generate-ChangelogEntry -Version $nextVersionStr -Commits $Commits

    return @{
        OldVersion = $currentVersionStr
        NewVersion = $nextVersionStr
        Changelog  = $changelog
    }
}

