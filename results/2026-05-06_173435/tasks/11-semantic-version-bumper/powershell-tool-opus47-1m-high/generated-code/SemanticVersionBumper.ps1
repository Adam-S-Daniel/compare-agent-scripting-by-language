#!/usr/bin/env pwsh
# SemanticVersionBumper.ps1
#
# Determine the next semantic version from a set of conventional commits,
# update the version file (package.json or plain VERSION file), and prepend
# a grouped Markdown changelog entry. Designed for direct use and for
# dot-sourcing in Pester tests.
#
# Conventional commits mapping:
#   - any commit with `!:` in its header OR a `BREAKING CHANGE` token in
#     its body  -> major bump
#   - any commit starting with `feat`                                 -> minor bump
#   - any commit starting with `fix`                                  -> patch bump
#   - everything else (chore/docs/refactor/test/...)                  -> no bump
#
# CLI form (used by the GitHub Actions workflow):
#   Invoke-VersionBumper -VersionFile package.json -CommitsFile commits.bin \
#       -ChangelogFile CHANGELOG.md -Date 2026-05-07
#
# The CommitsFile is the raw output of `git log -z --format=%B`: commit
# bodies separated by NUL bytes. This makes the script trivially testable
# without spinning up a git repo.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Strict semver regex (no pre-release / build metadata for this benchmark).
$script:SemverRegex = '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)$'

function Get-CurrentVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }

    $raw = (Get-Content -Raw -LiteralPath $Path).Trim()

    # If it parses as JSON with a .version field, use that; else treat the
    # whole file as a bare version string.
    $version = $null
    try {
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
        if ($obj.PSObject.Properties.Name -contains 'version') {
            $version = [string]$obj.version
        }
    } catch {
        $version = $raw
    }

    if (-not $version) { $version = $raw }

    if ($version -notmatch $script:SemverRegex) {
        throw "File '$Path' does not contain a valid semver string (got '$version')."
    }
    return $version
}

function Get-BumpType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Commits
    )

    $type = 'none'
    foreach ($c in $Commits) {
        if (-not $c) { continue }
        $header = ($c -split "`n", 2)[0]

        # Major: `!:` in the header OR `BREAKING CHANGE` token anywhere.
        if ($header -match '^[a-zA-Z]+(\([^)]*\))?!:' -or $c -match 'BREAKING[ -]CHANGE') {
            return 'major'
        }
        if ($header -match '^feat(\([^)]*\))?:') {
            if ($type -ne 'major') { $type = 'minor' }
        } elseif ($header -match '^fix(\([^)]*\))?:') {
            if ($type -eq 'none') { $type = 'patch' }
        }
    }
    return $type
}

function Step-Version {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Version,
        [Parameter(Mandatory)] [ValidateSet('major', 'minor', 'patch', 'none')] [string] $BumpType
    )

    if ($Version -notmatch $script:SemverRegex) {
        throw "Invalid semver: '$Version'"
    }
    $maj = [int]$Matches['major']
    $min = [int]$Matches['minor']
    $pat = [int]$Matches['patch']

    switch ($BumpType) {
        'major' { return "{0}.0.0" -f ($maj + 1) }
        'minor' { return "{0}.{1}.0" -f $maj, ($min + 1) }
        'patch' { return "{0}.{1}.{2}" -f $maj, $min, ($pat + 1) }
        'none'  { return $Version }
    }
}

function Set-CurrentVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Version
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }

    $raw = (Get-Content -Raw -LiteralPath $Path).Trim()
    $isJson = $false
    $obj = $null
    try {
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
        if ($obj.PSObject.Properties.Name -contains 'version') { $isJson = $true }
    } catch { $isJson = $false }

    if ($isJson) {
        $obj.version = $Version
        # 2-space indent matches package.json convention.
        $json = $obj | ConvertTo-Json -Depth 32
        Set-Content -LiteralPath $Path -Value $json -NoNewline
    } else {
        Set-Content -LiteralPath $Path -Value $Version
    }
}

function Get-CommitsFromFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Commits file not found: $Path"
    }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -eq 0) { return @() }
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    # Strip trailing NUL (git log -z appends one).
    $text = $text.TrimEnd([char]0)
    if ([string]::IsNullOrWhiteSpace($text)) { return @() }
    return @($text -split [char]0 | Where-Object { $_ -and $_.Trim() })
}

function New-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Version,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Commits,
        [Parameter(Mandatory)] [string] $Date
    )

    $breaking = New-Object System.Collections.Generic.List[string]
    $features = New-Object System.Collections.Generic.List[string]
    $fixes    = New-Object System.Collections.Generic.List[string]

    foreach ($c in $Commits) {
        if (-not $c) { continue }
        $header = ($c -split "`n", 2)[0]
        $isBreaking = ($header -match '^[a-zA-Z]+(\([^)]*\))?!:') -or ($c -match 'BREAKING[ -]CHANGE')
        if ($isBreaking) {
            $breaking.Add($header) | Out-Null
            continue
        }
        if ($header -match '^feat(\([^)]*\))?:') {
            $features.Add($header) | Out-Null
        } elseif ($header -match '^fix(\([^)]*\))?:') {
            $fixes.Add($header) | Out-Null
        }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## [$Version] - $Date")
    [void]$sb.AppendLine()

    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine('### Breaking Changes')
        foreach ($h in $breaking) { [void]$sb.AppendLine("- $h") }
        [void]$sb.AppendLine()
    }
    if ($features.Count -gt 0) {
        [void]$sb.AppendLine('### Features')
        foreach ($h in $features) { [void]$sb.AppendLine("- $h") }
        [void]$sb.AppendLine()
    }
    if ($fixes.Count -gt 0) {
        [void]$sb.AppendLine('### Fixes')
        foreach ($h in $fixes) { [void]$sb.AppendLine("- $h") }
        [void]$sb.AppendLine()
    }

    return $sb.ToString()
}

function Invoke-VersionBumper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $VersionFile,
        [Parameter(Mandatory)] [string] $CommitsFile,
        [Parameter(Mandatory)] [string] $ChangelogFile,
        [string] $Date = (Get-Date -Format 'yyyy-MM-dd')
    )

    $current = Get-CurrentVersion -Path $VersionFile
    $commits = Get-CommitsFromFile -Path $CommitsFile
    $bump = Get-BumpType -Commits $commits
    $next = Step-Version -Version $current -BumpType $bump

    if ($bump -ne 'none') {
        Set-CurrentVersion -Path $VersionFile -Version $next
        $entry = New-ChangelogEntry -Version $next -Commits $commits -Date $Date

        $existing = ''
        if (Test-Path -LiteralPath $ChangelogFile) {
            $existing = Get-Content -Raw -LiteralPath $ChangelogFile
            if ($null -eq $existing) { $existing = '' }
        }
        $combined = if ($existing.Trim()) { "$entry`n$existing" } else { $entry }
        Set-Content -LiteralPath $ChangelogFile -Value $combined -NoNewline
    }

    return $next
}

