# SemanticVersionBumper.psm1
# Parses a semantic version, determines next version from conventional commits,
# updates the version file, and writes a changelog entry.

function Get-BumpType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $Commits
    )
    # Conventional commit rules:
    #   - "BREAKING CHANGE" anywhere, or "!" before the colon => major
    #   - "feat" type => minor
    #   - "fix" type => patch
    #   - anything else => none
    $bump = 'none'
    foreach ($c in $Commits) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        if ($c -match 'BREAKING CHANGE' -or $c -match '^[a-zA-Z]+(\([^)]*\))?!:') {
            return 'major'
        }
        if ($c -match '^feat(\([^)]*\))?:') {
            if ($bump -ne 'major') { $bump = 'minor' }
        } elseif ($c -match '^fix(\([^)]*\))?:') {
            if ($bump -eq 'none') { $bump = 'patch' }
        }
    }
    return $bump
}

function Step-SemVer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Version,
        [Parameter(Mandatory)][ValidateSet('major','minor','patch','none')][string] $Bump
    )
    if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "Invalid semantic version: '$Version'. Expected MAJOR.MINOR.PATCH."
    }
    $major = [int]$Matches[1]; $minor = [int]$Matches[2]; $patch = [int]$Matches[3]
    switch ($Bump) {
        'major' { $major++; $minor = 0; $patch = 0 }
        'minor' { $minor++; $patch = 0 }
        'patch' { $patch++ }
        'none'  { }
    }
    return "$major.$minor.$patch"
}

function Read-VersionFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: '$Path'."
    }
    if ($Path -like '*package.json') {
        $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        if (-not $json.version) { throw "package.json has no 'version' field." }
        return [string]$json.version
    }
    $content = (Get-Content -LiteralPath $Path -Raw).Trim()
    if (-not $content) { throw "Version file is empty: '$Path'." }
    return $content
}

function Update-VersionFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $NewVersion
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: '$Path'."
    }
    if ($Path -like '*package.json') {
        $raw = Get-Content -LiteralPath $Path -Raw
        # Replace the version field textually so we preserve formatting.
        $updated = [regex]::Replace($raw, '("version"\s*:\s*")([^"]+)(")', {
            param($m) $m.Groups[1].Value + $NewVersion + $m.Groups[3].Value
        }, 1)
        Set-Content -LiteralPath $Path -Value $updated -NoNewline
    } else {
        Set-Content -LiteralPath $Path -Value $NewVersion
    }
}

function New-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Version,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]] $Commits,
        [string] $Date = (Get-Date -Format 'yyyy-MM-dd')
    )
    $features = @()
    $fixes = @()
    $breaking = @()
    $other = @()
    foreach ($c in $Commits) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        if ($c -match '^([a-zA-Z]+)(\([^)]*\))?(!)?:\s*(.+)$') {
            $type = $Matches[1]; $bang = $Matches[3]; $subject = $Matches[4]
            if ($bang -or $c -match 'BREAKING CHANGE') {
                $breaking += $subject
            } elseif ($type -eq 'feat') {
                $features += $subject
            } elseif ($type -eq 'fix') {
                $fixes += $subject
            } else {
                $other += $subject
            }
        }
    }
    $lines = @("## $Version - $Date", "")
    if ($breaking.Count) {
        $lines += '### BREAKING CHANGES'
        foreach ($s in $breaking) { $lines += "- $s" }
        $lines += ''
    }
    if ($features.Count) {
        $lines += '### Features'
        foreach ($s in $features) { $lines += "- $s" }
        $lines += ''
    }
    if ($fixes.Count) {
        $lines += '### Fixes'
        foreach ($s in $fixes) { $lines += "- $s" }
        $lines += ''
    }
    return ($lines -join "`n")
}

function Add-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Entry
    )
    $header = "# Changelog`n`n"
    $body = ''
    if (Test-Path -LiteralPath $Path) {
        $existing = Get-Content -LiteralPath $Path -Raw
        if ($existing -match '^# Changelog\s*\r?\n\r?\n') {
            $body = $existing -replace '^# Changelog\s*\r?\n\r?\n', ''
        } else {
            $body = $existing
        }
    }
    Set-Content -LiteralPath $Path -Value ($header + $Entry + "`n" + $body)
}

function Read-CommitsFromFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Commits file not found: '$Path'."
    }
    # One commit subject per line, blank lines ignored, supports '#' comments.
    return Get-Content -LiteralPath $Path |
        Where-Object { $_ -and -not ($_ -match '^\s*#') } |
        ForEach-Object { $_.TrimEnd() }
}

function Invoke-VersionBump {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $VersionFile,
        [Parameter(Mandatory)][string] $CommitsFile,
        [string] $ChangelogFile = 'CHANGELOG.md'
    )
    $current = Read-VersionFile -Path $VersionFile
    $commits = @(Read-CommitsFromFile -Path $CommitsFile)
    $bump = Get-BumpType -Commits $commits
    $next = Step-SemVer -Version $current -Bump $bump
    if ($bump -ne 'none') {
        Update-VersionFile -Path $VersionFile -NewVersion $next
        $entry = New-ChangelogEntry -Version $next -Commits $commits
        Add-ChangelogEntry -Path $ChangelogFile -Entry $entry
    }
    return [pscustomobject]@{
        OldVersion = $current
        NewVersion = $next
        BumpType   = $bump
    }
}

Export-ModuleMember -Function Get-BumpType, Step-SemVer, Read-VersionFile,
    Update-VersionFile, New-ChangelogEntry, Add-ChangelogEntry,
    Read-CommitsFromFile, Invoke-VersionBump
