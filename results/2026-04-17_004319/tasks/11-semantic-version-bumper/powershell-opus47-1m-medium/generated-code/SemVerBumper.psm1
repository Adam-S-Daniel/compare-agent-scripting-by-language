# SemVerBumper.psm1
# Semantic version bumper driven by Conventional Commits.
# Functions here are kept small and pure to stay TDD-friendly.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-VersionFromFile {
    <#
    .SYNOPSIS
      Read a semantic version from a file. Supports package.json or a plain
      VERSION file (first non-empty line).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw

    if ($Path -like '*.json') {
        $obj = $raw | ConvertFrom-Json
        if (-not $obj.version) { throw "JSON file has no 'version' field: $Path" }
        return [string]$obj.version
    }

    $line = ($raw -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
    if (-not $line) { throw "Version file is empty: $Path" }
    return $line.Trim()
}

function Test-SemanticVersion {
    <# Returns $true for a bare "X.Y.Z" string. #>
    param([string]$Version)
    return [bool]($Version -match '^\d+\.\d+\.\d+$')
}

function Get-BumpTypeFromCommits {
    <#
    .SYNOPSIS
      Given an array of commit subject lines (or full messages), return the
      strongest bump level found: 'major' > 'minor' > 'patch' > 'none'.
    .NOTES
      Conventional Commits rules:
        - Any BREAKING CHANGE, or '!' after type/scope -> major
        - 'feat' type -> minor
        - 'fix' type  -> patch
        - anything else -> none (by itself)
    #>
    param([string[]]$Commits)

    if (-not $Commits -or $Commits.Count -eq 0) { return 'none' }

    $level = 'none'
    foreach ($c in $Commits) {
        if ($null -eq $c) { continue }
        $msg = [string]$c

        # Breaking change markers: "!:" after type(scope) OR "BREAKING CHANGE:" in body
        if ($msg -match '^[a-zA-Z]+(\([^)]*\))?!:' -or $msg -match 'BREAKING CHANGE:') {
            return 'major'
        }

        # Match the first line's type prefix
        $first = ($msg -split "`n" | Select-Object -First 1)
        if ($first -match '^(?<type>[a-zA-Z]+)(\([^)]*\))?:\s') {
            switch ($matches.type.ToLower()) {
                'feat' { if ($level -eq 'none' -or $level -eq 'patch') { $level = 'minor' } }
                'fix'  { if ($level -eq 'none')  { $level = 'patch' } }
            }
        }
    }
    return $level
}

function Step-SemanticVersion {
    <# Apply a bump level to a semver string. #>
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][ValidateSet('major','minor','patch','none')][string]$Bump
    )
    if (-not (Test-SemanticVersion $Version)) {
        throw "Not a valid semantic version: '$Version'"
    }
    $parts = @($Version -split '\.' | ForEach-Object { [int]$_ })
    [int]$maj = $parts[0]; [int]$min = $parts[1]; [int]$pat = $parts[2]
    switch ($Bump) {
        'major' { $maj++; $min = 0; $pat = 0 }
        'minor' { $min++; $pat = 0 }
        'patch' { $pat++ }
        'none'  { } # unchanged
    }
    return "$maj.$min.$pat"
}

function Set-VersionInFile {
    <# Write a new version back to package.json or a plain VERSION file. #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Version
    )
    if (-not (Test-SemanticVersion $Version)) {
        throw "Refusing to write invalid version '$Version' to $Path"
    }
    if ($Path -like '*.json') {
        $raw = Get-Content -LiteralPath $Path -Raw
        # Regex replace to preserve formatting/key order instead of round-tripping JSON.
        $rx  = [regex]'("version"\s*:\s*")[^"]+(")'
        if (-not $rx.IsMatch($raw)) {
            throw "No `"version`" field found to update in $Path"
        }
        $new = $rx.Replace($raw, "`${1}$Version`${2}", 1)
        Set-Content -LiteralPath $Path -Value $new -NoNewline
    } else {
        Set-Content -LiteralPath $Path -Value $Version
    }
}

function New-ChangelogEntry {
    <#
    .SYNOPSIS
      Build a markdown changelog entry grouping commits by Conventional Commit type.
    #>
    param(
        [Parameter(Mandatory)][string]$Version,
        [string[]]$Commits,
        [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
    )

    $features = @()
    $fixes = @()
    $breaking = @()
    $other = @()

    foreach ($c in ($Commits | Where-Object { $_ })) {
        $first = ($c -split "`n" | Select-Object -First 1)
        if ($c -match 'BREAKING CHANGE:' -or $first -match '^[a-zA-Z]+(\([^)]*\))?!:') {
            $breaking += $first
        }
        if ($first -match '^feat(\([^)]*\))?!?:\s*(?<desc>.+)$') { $features += $matches.desc; continue }
        if ($first -match '^fix(\([^)]*\))?!?:\s*(?<desc>.+)$')  { $fixes    += $matches.desc; continue }
        if ($first -match '^[a-zA-Z]+(\([^)]*\))?!?:\s*(?<desc>.+)$') { $other += $matches.desc }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## $Version - $Date")
    [void]$sb.AppendLine("")
    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine("### BREAKING CHANGES")
        foreach ($b in $breaking) { [void]$sb.AppendLine("- $b") }
        [void]$sb.AppendLine("")
    }
    if ($features.Count -gt 0) {
        [void]$sb.AppendLine("### Features")
        foreach ($f in $features) { [void]$sb.AppendLine("- $f") }
        [void]$sb.AppendLine("")
    }
    if ($fixes.Count -gt 0) {
        [void]$sb.AppendLine("### Fixes")
        foreach ($f in $fixes) { [void]$sb.AppendLine("- $f") }
        [void]$sb.AppendLine("")
    }
    if ($other.Count -gt 0) {
        [void]$sb.AppendLine("### Other")
        foreach ($o in $other) { [void]$sb.AppendLine("- $o") }
        [void]$sb.AppendLine("")
    }
    return $sb.ToString()
}

function Read-CommitFixture {
    <#
    .SYNOPSIS
      Parse a mock commit log fixture. Commits are separated by lines containing
      only '---'. Blank lines and leading/trailing whitespace are trimmed.
    #>
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { throw "Commit fixture not found: $Path" }
    $raw = Get-Content -LiteralPath $Path -Raw
    $chunks = $raw -split "(?m)^\s*---\s*$"
    $commits = foreach ($chunk in $chunks) {
        $t = $chunk.Trim()
        if ($t) { $t }
    }
    return ,$commits
}

function Invoke-VersionBump {
    <#
    .SYNOPSIS
      End-to-end: read version, compute bump, write version, prepend changelog.
    .OUTPUTS
      PSCustomObject with OldVersion, NewVersion, Bump, Changelog.
    #>
    param(
        [Parameter(Mandatory)][string]$VersionPath,
        [Parameter(Mandatory)][string[]]$Commits,
        [string]$ChangelogPath
    )

    $old = Get-VersionFromFile -Path $VersionPath
    $bump = Get-BumpTypeFromCommits -Commits $Commits
    $new = Step-SemanticVersion -Version $old -Bump $bump
    Set-VersionInFile -Path $VersionPath -Version $new
    $entry = New-ChangelogEntry -Version $new -Commits $Commits

    if ($ChangelogPath) {
        $existing = ''
        if (Test-Path -LiteralPath $ChangelogPath) {
            $existing = Get-Content -LiteralPath $ChangelogPath -Raw
        }
        Set-Content -LiteralPath $ChangelogPath -Value ($entry + $existing)
    }

    return [pscustomobject]@{
        OldVersion = $old
        NewVersion = $new
        Bump       = $bump
        Changelog  = $entry
    }
}

Export-ModuleMember -Function `
    Get-VersionFromFile, Test-SemanticVersion, Get-BumpTypeFromCommits,
    Step-SemanticVersion, Set-VersionInFile, New-ChangelogEntry,
    Read-CommitFixture, Invoke-VersionBump
