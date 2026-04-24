# Semantic version bumper library.
#
# Exposes pure-ish functions used by the CLI entry (Invoke-Bumper.ps1) and the
# Pester test suite. Commits are supplied as an array of strings so the library
# stays decoupled from `git log` — callers pass real git output, mocked log
# fixtures, or in-memory arrays as appropriate.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-BumpTypeFromCommits {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $Commits
    )

    # Precedence: major > minor > patch > none. We iterate once, raising the
    # level as we find stronger signals so the scan is O(n).
    $level = 'none'
    foreach ($c in $Commits) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }

        # Breaking change: either `type!:` / `type(scope)!:` on subject, or a
        # `BREAKING CHANGE:` footer anywhere in the body.
        if ($c -match '^(feat|fix|refactor|perf|chore|build|ci|docs|style|test)(\([^)]+\))?!:' `
            -or $c -match '(?m)^BREAKING CHANGE:') {
            return 'major'
        }

        $subject = ($c -split "`n", 2)[0]
        if ($subject -match '^feat(\([^)]+\))?:') {
            $level = 'minor'
        } elseif ($subject -match '^fix(\([^)]+\))?:' -and $level -ne 'minor') {
            $level = 'patch'
        }
    }
    return $level
}

function Get-NextVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Current,
        [Parameter(Mandatory)][ValidateSet('major','minor','patch','none')][string] $BumpType
    )
    if ($Current -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "Invalid semantic version: '$Current' (expected MAJOR.MINOR.PATCH)"
    }
    $maj = [int]$Matches[1]; $min = [int]$Matches[2]; $pat = [int]$Matches[3]
    switch ($BumpType) {
        'major' { "$($maj+1).0.0" }
        'minor' { "$maj.$($min+1).0" }
        'patch' { "$maj.$min.$($pat+1)" }
        'none'  { $Current }
    }
}

function Get-CurrentVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    if ($Path -match '\.json$') {
        $obj = $raw | ConvertFrom-Json
        if (-not $obj.version) { throw "No 'version' field in $Path" }
        return [string]$obj.version
    }
    return $raw.Trim()
}

function Set-NewVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $NewVersion
    )
    if ($Path -match '\.json$') {
        # Preserve field order and formatting as much as possible by doing a
        # targeted regex swap on the "version" key rather than re-serialising.
        $raw = Get-Content -LiteralPath $Path -Raw
        $updated = [regex]::Replace(
            $raw,
            '("version"\s*:\s*")([^"]+)(")',
            { param($m) $m.Groups[1].Value + $NewVersion + $m.Groups[3].Value },
            [System.Text.RegularExpressions.RegexOptions]::None)
        Set-Content -LiteralPath $Path -Value $updated -NoNewline
    } else {
        Set-Content -LiteralPath $Path -Value $NewVersion -NoNewline
    }
}

function ConvertTo-CommitRecord {
    # Normalises a raw commit body into a record we can classify/render.
    param([string] $Commit)
    $subject = ($Commit -split "`n", 2)[0]
    $isBreaking = ($Commit -match '(?m)^BREAKING CHANGE:') -or `
                  ($subject -match '^(feat|fix|refactor|perf|chore|build|ci|docs|style|test)(\([^)]+\))?!:')
    $type = 'other'
    $desc = $subject
    if ($subject -match '^(?<type>[a-z]+)(\([^)]+\))?!?:\s*(?<desc>.+)$') {
        $type = $Matches['type']
        $desc = $Matches['desc']
    }
    [pscustomobject]@{
        Type       = $type
        IsBreaking = $isBreaking
        Description = $desc
        Raw        = $Commit
    }
}

function New-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Version,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]] $Commits,
        [string] $Date = (Get-Date -Format 'yyyy-MM-dd')
    )

    $records = $Commits | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { ConvertTo-CommitRecord $_ }
    $breaking = @($records | Where-Object { $_.IsBreaking })
    $features = @($records | Where-Object { -not $_.IsBreaking -and $_.Type -eq 'feat' })
    $fixes    = @($records | Where-Object { -not $_.IsBreaking -and $_.Type -eq 'fix' })

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## [$Version] - $Date")
    [void]$sb.AppendLine('')
    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine('### Breaking Changes')
        foreach ($b in $breaking) { [void]$sb.AppendLine("- $($b.Description)") }
        [void]$sb.AppendLine('')
    }
    if ($features.Count -gt 0) {
        [void]$sb.AppendLine('### Features')
        foreach ($f in $features) { [void]$sb.AppendLine("- $($f.Description)") }
        [void]$sb.AppendLine('')
    }
    if ($fixes.Count -gt 0) {
        [void]$sb.AppendLine('### Fixes')
        foreach ($f in $fixes) { [void]$sb.AppendLine("- $($f.Description)") }
        [void]$sb.AppendLine('')
    }
    return $sb.ToString()
}

function Read-CommitLogFile {
    # Fixture format: commits separated by a line containing only `---`.
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Commit log file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    $parts = [regex]::Split($raw, '(?m)^---\s*$')
    return @($parts | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Invoke-VersionBump {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $VersionFile,
        [Parameter(Mandatory)][string] $CommitLogFile,
        [string] $ChangelogFile,
        [string] $Date = (Get-Date -Format 'yyyy-MM-dd')
    )

    $commits = Read-CommitLogFile -Path $CommitLogFile
    $bump    = Get-BumpTypeFromCommits -Commits $commits
    $old     = Get-CurrentVersion -Path $VersionFile
    $new     = Get-NextVersion -Current $old -BumpType $bump

    if ($bump -ne 'none') {
        Set-NewVersion -Path $VersionFile -NewVersion $new
        if ($ChangelogFile) {
            $entry = New-ChangelogEntry -Version $new -Commits $commits -Date $Date
            $existing = if (Test-Path -LiteralPath $ChangelogFile) { Get-Content -LiteralPath $ChangelogFile -Raw } else { "# Changelog`n`n" }
            Set-Content -LiteralPath $ChangelogFile -Value ($entry + $existing) -NoNewline
        }
    }

    [pscustomobject]@{
        OldVersion = $old
        NewVersion = $new
        BumpType   = $bump
        Commits    = $commits
    }
}
