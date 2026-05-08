# SemanticVersionBumper.psm1
# Core logic for parsing versions, determining bump type from conventional commits,
# updating version files, and generating changelog entries.

function Get-VersionFromFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        throw "Version file not found: $FilePath"
    }

    $content = Get-Content $FilePath -Raw

    if ($FilePath -match '\.json$') {
        $json = $content | ConvertFrom-Json
        if ($null -eq $json.version) {
            throw "No 'version' field found in JSON file: $FilePath"
        }
        $version = $json.version
    } else {
        $version = $content.Trim()
    }

    if ($version -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid semantic version format: '$version'"
    }

    return $version
}

function Get-BumpType {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Commits
    )

    # Priority order: major > minor > patch (default)
    $bumpType = "patch"

    foreach ($commit in $Commits) {
        $type    = $commit.type
        $message = $commit.message
        $breaking = $commit.breaking

        # Breaking change: BREAKING CHANGE in message body or explicit flag
        if ($breaking -eq $true -or $message -match 'BREAKING CHANGE') {
            return "major"
        }

        if ($type -eq "feat") {
            $bumpType = "minor"
        }
        # fix and others keep whatever was already selected (default patch or promoted minor)
    }

    return $bumpType
}

function Get-NextVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CurrentVersion,

        [Parameter(Mandatory=$true)]
        [ValidateSet("major", "minor", "patch")]
        [string]$BumpType
    )

    $parts = $CurrentVersion -split '\.'
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]

    switch ($BumpType) {
        "major" { $major++; $minor = 0; $patch = 0 }
        "minor" { $minor++;             $patch = 0 }
        "patch" {                       $patch++   }
    }

    return "$major.$minor.$patch"
}

function Update-VersionFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [string]$NewVersion,

        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Host "[DryRun] Would update $FilePath to $NewVersion"
        return
    }

    if ($FilePath -match '\.json$') {
        $json = Get-Content $FilePath -Raw | ConvertFrom-Json
        $json.version = $NewVersion
        $json | ConvertTo-Json -Depth 10 | Set-Content $FilePath -NoNewline
    } else {
        Set-Content -Path $FilePath -Value $NewVersion -NoNewline
    }
}

function New-ChangelogEntry {
    param(
        [Parameter(Mandatory=$true)]
        [string]$NewVersion,

        [Parameter(Mandatory=$true)]
        [array]$Commits,

        [string]$Date = (Get-Date -Format "yyyy-MM-dd")
    )

    $lines = @("## [$NewVersion] - $Date", "")

    $breaking = $Commits | Where-Object { $_.breaking -eq $true -or $_.message -match 'BREAKING CHANGE' }
    $features = $Commits | Where-Object { $_.type -eq "feat" -and $_.breaking -ne $true -and $_.message -notmatch 'BREAKING CHANGE' }
    $fixes    = $Commits | Where-Object { $_.type -eq "fix" }
    $others   = $Commits | Where-Object { $_.type -notin @("feat","fix") -and $_.breaking -ne $true }

    if ($breaking) {
        $lines += "### Breaking Changes"
        foreach ($c in $breaking) { $lines += "- $($c.message)" }
        $lines += ""
    }
    if ($features) {
        $lines += "### Features"
        foreach ($c in $features) { $lines += "- $($c.message)" }
        $lines += ""
    }
    if ($fixes) {
        $lines += "### Bug Fixes"
        foreach ($c in $fixes) { $lines += "- $($c.message)" }
        $lines += ""
    }
    if ($others) {
        $lines += "### Other Changes"
        foreach ($c in $others) { $lines += "- $($c.message)" }
        $lines += ""
    }

    return $lines -join "`n"
}

function Read-CommitsFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        throw "Commits file not found: $FilePath"
    }

    return (Get-Content $FilePath -Raw | ConvertFrom-Json)
}

Export-ModuleMember -Function Get-VersionFromFile, Get-BumpType, Get-NextVersion, Update-VersionFile, New-ChangelogEntry, Read-CommitsFile
