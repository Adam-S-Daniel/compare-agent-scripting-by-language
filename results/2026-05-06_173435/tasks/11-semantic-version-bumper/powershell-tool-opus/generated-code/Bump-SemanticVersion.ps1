# Semantic Version Bumper
# Parses version files, determines bump type from conventional commits,
# updates version, and generates changelog entries.

function Parse-SemanticVersion {
    param([Parameter(Mandatory)][string]$VersionString)

    $cleaned = $VersionString.Trim() -replace '^v', ''
    if ($cleaned -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid semantic version: '$VersionString'"
    }
    $parts = $cleaned -split '\.'
    @{
        Major = [int]$parts[0]
        Minor = [int]$parts[1]
        Patch = [int]$parts[2]
    }
}

function Get-BumpType {
    param([Parameter(Mandatory)][string[]]$CommitMessages)

    # Highest precedence wins: major > minor > patch
    $bumpType = 'patch'
    foreach ($msg in $CommitMessages) {
        if ($msg -match 'BREAKING CHANGE' -or $msg -match '^\w+!:') {
            return 'major'
        }
        if ($msg -match '^feat(\(.+\))?:') {
            $bumpType = 'minor'
        }
    }
    $bumpType
}

function Invoke-VersionBump {
    param(
        [Parameter(Mandatory)][hashtable]$Version,
        [Parameter(Mandatory)][ValidateSet('major','minor','patch')][string]$BumpType
    )

    switch ($BumpType) {
        'major' { "$([int]$Version.Major + 1).0.0" }
        'minor' { "$($Version.Major).$([int]$Version.Minor + 1).0" }
        'patch' { "$($Version.Major).$($Version.Minor).$([int]$Version.Patch + 1)" }
    }
}

function Read-VersionFile {
    param([Parameter(Mandatory)][string]$ProjectPath)

    $versionFile = Join-Path $ProjectPath 'VERSION'
    $packageJson = Join-Path $ProjectPath 'package.json'

    if (Test-Path $versionFile) {
        return (Get-Content $versionFile -Raw).Trim()
    }
    if (Test-Path $packageJson) {
        $json = Get-Content $packageJson -Raw | ConvertFrom-Json
        return $json.version
    }
    throw "No VERSION file or package.json found in '$ProjectPath'"
}

function Write-VersionFile {
    param(
        [Parameter(Mandatory)][string]$ProjectPath,
        [Parameter(Mandatory)][string]$NewVersion
    )

    $versionFile = Join-Path $ProjectPath 'VERSION'
    $packageJson = Join-Path $ProjectPath 'package.json'

    if (Test-Path $versionFile) {
        Set-Content -Path $versionFile -Value $NewVersion -NoNewline
    }
    elseif (Test-Path $packageJson) {
        $json = Get-Content $packageJson -Raw | ConvertFrom-Json
        $json.version = $NewVersion
        $json | ConvertTo-Json -Depth 10 | Set-Content -Path $packageJson
    }
    else {
        throw "No VERSION file or package.json found in '$ProjectPath'"
    }
}

function New-ChangelogEntry {
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string[]]$CommitMessages
    )

    $breaking = @()
    $features = @()
    $fixes = @()
    $other = @()

    foreach ($msg in $CommitMessages) {
        if ($msg -match 'BREAKING CHANGE' -or $msg -match '^\w+!:') {
            $description = $msg -replace '^\w+!:\s*', '' -replace '^BREAKING CHANGE:\s*', ''
            $breaking += $description
        }
        elseif ($msg -match '^feat(\(.+\))?:\s*(.+)$') {
            $features += $Matches[2]
        }
        elseif ($msg -match '^fix(\(.+\))?:\s*(.+)$') {
            $fixes += $Matches[2]
        }
        else {
            $description = $msg -replace '^\w+(\(.+\))?:\s*', ''
            if ($description) { $other += $description }
        }
    }

    $date = Get-Date -Format 'yyyy-MM-dd'
    $lines = @("## $Version ($date)", '')

    if ($breaking.Count -gt 0) {
        $lines += '### Breaking Changes'
        foreach ($item in $breaking) { $lines += "- $item" }
        $lines += ''
    }
    if ($features.Count -gt 0) {
        $lines += '### Features'
        foreach ($item in $features) { $lines += "- $item" }
        $lines += ''
    }
    if ($fixes.Count -gt 0) {
        $lines += '### Fixes'
        foreach ($item in $fixes) { $lines += "- $item" }
        $lines += ''
    }
    if ($other.Count -gt 0) {
        $lines += '### Other'
        foreach ($item in $other) { $lines += "- $item" }
        $lines += ''
    }

    $lines -join "`n"
}

# Main orchestrator function
function Invoke-SemanticVersionBump {
    param(
        [Parameter(Mandatory)][string]$ProjectPath,
        [Parameter(Mandatory)][string[]]$CommitMessages
    )

    $currentVersionStr = Read-VersionFile $ProjectPath
    $currentVersion = Parse-SemanticVersion $currentVersionStr
    $bumpType = Get-BumpType $CommitMessages
    $newVersion = Invoke-VersionBump $currentVersion $bumpType
    Write-VersionFile $ProjectPath $newVersion
    $changelog = New-ChangelogEntry $newVersion $CommitMessages

    @{
        OldVersion = $currentVersionStr
        NewVersion = $newVersion
        BumpType   = $bumpType
        Changelog  = $changelog
    }
}
