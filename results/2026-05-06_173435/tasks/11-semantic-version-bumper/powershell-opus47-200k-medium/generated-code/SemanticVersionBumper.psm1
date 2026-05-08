# SemanticVersionBumper.psm1
#
# Library functions for parsing a semver, classifying conventional-commit
# messages, computing the next version, and rendering a Markdown changelog
# entry. Built TDD-first: see tests/SemanticVersionBumper.Tests.ps1.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Matches a strict X.Y.Z core (we don't need pre-release/build for this task).
$script:SemVerRegex = '^\s*(\d+)\.(\d+)\.(\d+)\s*$'

function Get-CurrentVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw

    # package.json => parse as JSON; otherwise treat the file as the bare version string.
    $version = if ($Path -match '\.json$') {
        try { ($raw | ConvertFrom-Json).version } catch { throw "Failed to parse JSON in '$Path': $_" }
    } else {
        $raw.Trim()
    }

    if ([string]::IsNullOrWhiteSpace($version) -or $version -notmatch $script:SemVerRegex) {
        throw "Value '$version' is not a valid semantic version (expected X.Y.Z)."
    }
    return $version.Trim()
}

function Get-BumpType {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Commits)

    $hasBreaking = $false; $hasFeat = $false; $hasFix = $false
    foreach ($c in $Commits) {
        if (-not $c) { continue }
        # First non-empty line is the conventional-commit subject.
        $lines = @($c -split "`n" | Where-Object { $_.Trim() })
        if ($lines.Count -eq 0) { continue }
        $subject = $lines[0]

        # Breaking marker: "type!:" or "type(scope)!:" anywhere in subject,
        # or a "BREAKING CHANGE:" footer in the body.
        if ($subject -match '^[a-zA-Z]+(\([^)]+\))?!:' -or $c -match '(?m)^\s*BREAKING[ -]CHANGE:') {
            $hasBreaking = $true
        }
        if ($subject -match '^feat(\([^)]+\))?!?:') { $hasFeat = $true }
        if ($subject -match '^fix(\([^)]+\))?!?:')  { $hasFix  = $true }
    }

    if ($hasBreaking) { return 'major' }
    if ($hasFeat)     { return 'minor' }
    if ($hasFix)      { return 'patch' }
    return 'none'
}

function Step-Version {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][ValidateSet('major','minor','patch','none')][string]$BumpType
    )
    if ($Version -notmatch $script:SemVerRegex) {
        throw "'$Version' is not a valid semantic version."
    }
    $maj = [int]$Matches[1]; $min = [int]$Matches[2]; $pat = [int]$Matches[3]
    switch ($BumpType) {
        'major' { return "$($maj + 1).0.0" }
        'minor' { return "$maj.$($min + 1).0" }
        'patch' { return "$maj.$min.$($pat + 1)" }
        'none'  { return "$maj.$min.$pat" }
    }
}

function New-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Date,
        [Parameter(Mandatory)][string[]]$Commits
    )
    $breaking = New-Object System.Collections.Generic.List[string]
    $features = New-Object System.Collections.Generic.List[string]
    $fixes    = New-Object System.Collections.Generic.List[string]

    foreach ($c in $Commits) {
        if (-not $c) { continue }
        $lines = @($c -split "`n" | Where-Object { $_.Trim() })
        if ($lines.Count -eq 0) { continue }
        $subject = $lines[0]

        # Strip the "type(scope)!:" prefix to render a clean bullet.
        $clean = $subject -replace '^[a-zA-Z]+(\([^)]+\))?!?:\s*', ''

        if ($subject -match '^[a-zA-Z]+(\([^)]+\))?!:' -or $c -match '(?m)^\s*BREAKING[ -]CHANGE:') {
            $breaking.Add($clean) | Out-Null
        } elseif ($subject -match '^feat(\([^)]+\))?:') {
            $features.Add($clean) | Out-Null
        } elseif ($subject -match '^fix(\([^)]+\))?:') {
            $fixes.Add($clean) | Out-Null
        }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## [$Version] - $Date")
    [void]$sb.AppendLine()
    if ($breaking.Count) {
        [void]$sb.AppendLine('### Breaking Changes')
        foreach ($b in $breaking) { [void]$sb.AppendLine("- $b") }
        [void]$sb.AppendLine()
    }
    if ($features.Count) {
        [void]$sb.AppendLine('### Features')
        foreach ($f in $features) { [void]$sb.AppendLine("- $f") }
        [void]$sb.AppendLine()
    }
    if ($fixes.Count) {
        [void]$sb.AppendLine('### Bug Fixes')
        foreach ($f in $fixes) { [void]$sb.AppendLine("- $f") }
        [void]$sb.AppendLine()
    }
    return $sb.ToString()
}

function Read-CommitsFile {
    # Commit log fixture format: blocks separated by a line "---COMMIT---".
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Commits file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    return @(($raw -split '(?m)^---COMMIT---\s*$') |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ })
}

function Set-VersionInFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$NewVersion
    )
    if ($Path -match '\.json$') {
        # Replace only the version field; preserve formatting otherwise.
        $raw = Get-Content -LiteralPath $Path -Raw
        $updated = [regex]::Replace(
            $raw,
            '("version"\s*:\s*")[^"]+(")',
            { param($m) "$($m.Groups[1].Value)$NewVersion$($m.Groups[2].Value)" },
            1)
        Set-Content -LiteralPath $Path -Value $updated -NoNewline
    } else {
        Set-Content -LiteralPath $Path -Value $NewVersion
    }
}

function Invoke-VersionBump {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VersionFile,
        [Parameter(Mandatory)][string]$CommitsFile,
        [Parameter(Mandatory)][string]$ChangelogFile,
        [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
    )

    $old = Get-CurrentVersion -Path $VersionFile
    $commits = @(Read-CommitsFile -Path $CommitsFile)
    $bump = Get-BumpType -Commits $commits
    $new = Step-Version -Version $old -BumpType $bump

    if ($bump -ne 'none') {
        Set-VersionInFile -Path $VersionFile -NewVersion $new
        $entry = New-ChangelogEntry -Version $new -Date $Date -Commits $commits
        $existing = if (Test-Path -LiteralPath $ChangelogFile) {
            Get-Content -LiteralPath $ChangelogFile -Raw
        } else { "# Changelog`n`n" }
        Set-Content -LiteralPath $ChangelogFile -Value ($entry + "`n" + $existing)
    }

    return [pscustomobject]@{
        OldVersion = $old
        NewVersion = $new
        BumpType   = $bump
        CommitCount = $commits.Count
    }
}

Export-ModuleMember -Function Get-CurrentVersion, Get-BumpType, Step-Version,
    New-ChangelogEntry, Read-CommitsFile, Set-VersionInFile, Invoke-VersionBump
