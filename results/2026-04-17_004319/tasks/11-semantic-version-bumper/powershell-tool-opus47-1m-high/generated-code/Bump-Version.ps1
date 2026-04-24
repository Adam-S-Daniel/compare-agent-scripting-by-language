#Requires -Version 7.0
<#
.SYNOPSIS
    Bump a semantic version based on conventional commit messages.

.DESCRIPTION
    Reads a version file (plain text or package.json), inspects a list of
    Conventional-Commits-style messages, decides whether the next version is a
    major / minor / patch bump, writes the new version back to the file,
    appends a changelog entry, and prints the new version on stdout.

    The script is dot-source friendly. Pass -NoExecute to load the helper
    functions without running the bumper (used by the Pester suite).
#>

[CmdletBinding()]
param(
    [string] $VersionFile,
    [string] $CommitsFile,
    [string] $ChangelogFile,
    [switch] $NoExecute
)

$ErrorActionPreference = 'Stop'

$script:SemVerRegex = '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(?:[-+].*)?$'

function Get-CurrentVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }
    $raw = (Get-Content -LiteralPath $Path -Raw).Trim()

    # package.json detection by extension; fall back to plain text.
    if ($Path -match '\.json$') {
        try {
            $obj = $raw | ConvertFrom-Json
        } catch {
            throw "Version file '$Path' is not valid JSON: $($_.Exception.Message)"
        }
        if (-not $obj.PSObject.Properties.Name.Contains('version')) {
            throw "package.json '$Path' does not contain a 'version' field"
        }
        $version = [string] $obj.version
    } else {
        $version = $raw
    }

    if ($version -notmatch $script:SemVerRegex) {
        throw "Value '$version' is not a valid semantic version"
    }
    return $version
}

function Get-BumpType {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string[]] $Commits)

    $rank = @{ none = 0; patch = 1; minor = 2; major = 3 }
    $current = 'none'

    foreach ($commit in $Commits) {
        if (-not $commit) { continue }

        # The conventional-commits header sits on the first line.
        $headerLine = ($commit -split "`n", 2)[0]

        $type = 'none'
        if ($headerLine -match '^(?<type>[a-zA-Z]+)(\([^)]*\))?(?<bang>!)?:\s') {
            $rawType = $Matches['type'].ToLowerInvariant()
            $bang = [bool] $Matches['bang']
            if ($bang) {
                $type = 'major'
            } elseif ($commit -match '(?m)^BREAKING CHANGE:') {
                $type = 'major'
            } elseif ($rawType -eq 'feat') {
                $type = 'minor'
            } elseif ($rawType -eq 'fix') {
                $type = 'patch'
            }
        } elseif ($commit -match '(?m)^BREAKING CHANGE:') {
            $type = 'major'
        }

        if ($rank[$type] -gt $rank[$current]) { $current = $type }
    }
    return $current
}

function Step-Version {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Version,
        [Parameter(Mandatory)] [ValidateSet('major', 'minor', 'patch', 'none')] [string] $BumpType
    )
    if ($Version -notmatch $script:SemVerRegex) {
        throw "Value '$Version' is not a valid semantic version"
    }
    $major = [int] $Matches['major']
    $minor = [int] $Matches['minor']
    $patch = [int] $Matches['patch']

    switch ($BumpType) {
        'major' { return ('{0}.0.0' -f ($major + 1)) }
        'minor' { return ('{0}.{1}.0' -f $major, ($minor + 1)) }
        'patch' { return ('{0}.{1}.{2}' -f $major, $minor, ($patch + 1)) }
        'none'  { return ('{0}.{1}.{2}' -f $major, $minor, $patch) }
    }
}

function New-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Version,
        [Parameter(Mandatory)] [string[]] $Commits
    )

    $features = @()
    $fixes = @()
    $breaking = @()

    foreach ($commit in $Commits) {
        if (-not $commit) { continue }
        $headerLine = ($commit -split "`n", 2)[0]

        if ($headerLine -match '^(?<type>[a-zA-Z]+)(\([^)]*\))?(?<bang>!)?:\s*(?<msg>.+)$') {
            $rawType = $Matches['type'].ToLowerInvariant()
            $bang = [bool] $Matches['bang']
            $msg = $Matches['msg'].Trim()

            if ($bang -or $commit -match '(?m)^BREAKING CHANGE:') {
                $breaking += $msg
            } elseif ($rawType -eq 'feat') {
                $features += $msg
            } elseif ($rawType -eq 'fix') {
                $fixes += $msg
            }
        }
    }

    $sb = [System.Text.StringBuilder]::new()
    $date = (Get-Date -Format 'yyyy-MM-dd')
    [void] $sb.AppendLine("## [$Version] - $date")
    [void] $sb.AppendLine()

    if ($breaking.Count) {
        [void] $sb.AppendLine('### BREAKING CHANGES')
        foreach ($m in $breaking) { [void] $sb.AppendLine("- $m") }
        [void] $sb.AppendLine()
    }
    if ($features.Count) {
        [void] $sb.AppendLine('### Features')
        foreach ($m in $features) { [void] $sb.AppendLine("- $m") }
        [void] $sb.AppendLine()
    }
    if ($fixes.Count) {
        [void] $sb.AppendLine('### Bug Fixes')
        foreach ($m in $fixes) { [void] $sb.AppendLine("- $m") }
        [void] $sb.AppendLine()
    }
    return $sb.ToString()
}

function Set-VersionInFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Version
    )
    if ($Path -match '\.json$') {
        $obj = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        $obj.version = $Version
        # Preserve a stable JSON shape; depth 32 covers nested objects we don't care about.
        ($obj | ConvertTo-Json -Depth 32) | Set-Content -LiteralPath $Path
    } else {
        Set-Content -LiteralPath $Path -Value $Version
    }
}

function Read-CommitsFile {
    param([Parameter(Mandatory)] [string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Commits file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    # Commits are separated by a blank line so multi-line bodies (e.g. with
    # BREAKING CHANGE: footers) survive intact. Single-line entries still work
    # because the split also accepts plain newlines when no blank line is found.
    if ($raw -match "(?m)^\s*$") {
        $commits = ($raw -split "(?m)^\s*$") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    } else {
        $commits = ($raw -split "(`r?`n)+") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    return ,$commits
}

function Invoke-VersionBump {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $VersionFile,
        [Parameter(Mandatory)] [string] $CommitsFile,
        [string] $ChangelogFile
    )

    $current = Get-CurrentVersion -Path $VersionFile
    $commits = Read-CommitsFile -Path $CommitsFile
    $bumpType = Get-BumpType -Commits $commits
    $next = Step-Version -Version $current -BumpType $bumpType

    if ($next -ne $current) {
        Set-VersionInFile -Path $VersionFile -Version $next
    }

    if ($ChangelogFile) {
        $entry = New-ChangelogEntry -Version $next -Commits $commits
        $existing = if (Test-Path -LiteralPath $ChangelogFile) {
            Get-Content -LiteralPath $ChangelogFile -Raw
        } else {
            "# Changelog`n`n"
        }
        # New entries go at the top so the latest version is most visible.
        Set-Content -LiteralPath $ChangelogFile -Value ($entry + "`n" + $existing)
    }

    return $next
}

if (-not $NoExecute) {
    if (-not $VersionFile -or -not $CommitsFile) {
        throw 'VersionFile and CommitsFile are required unless -NoExecute is set.'
    }
    $newVersion = Invoke-VersionBump -VersionFile $VersionFile -CommitsFile $CommitsFile -ChangelogFile $ChangelogFile
    Write-Output $newVersion
}
