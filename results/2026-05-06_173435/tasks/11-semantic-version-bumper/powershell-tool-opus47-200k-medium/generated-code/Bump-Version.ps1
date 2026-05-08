<#
.SYNOPSIS
    Semantic version bumper based on conventional commit messages.

.DESCRIPTION
    Reads the current version from a VERSION file or package.json, scans a
    list of mock conventional-commit messages (separated by lines containing
    only "---"), determines the appropriate semver bump (major/minor/patch),
    updates the version file, prepends a changelog entry, and prints the
    result as KEY=VALUE lines on stdout (parseable from CI logs).

    The script is structured as a set of small functions so each can be
    exercised by Pester. The bottom of the file contains a guarded entry
    point that runs only when the script is invoked directly with
    -VersionFile (i.e. NOT when dot-sourced from a test).
#>
[CmdletBinding()]
param(
    [string]$VersionFile,
    [string]$CommitsFile,
    [string]$ChangelogFile = 'CHANGELOG.md'
)

# ---------- pure logic -------------------------------------------------------

function Get-BumpType {
    # Decides bump type from the highest-precedence commit kind found.
    # major > minor > patch > none
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Commits)

    $hasMajor = $false; $hasMinor = $false; $hasPatch = $false
    foreach ($c in $Commits) {
        if ($null -eq $c) { continue }
        # "feat!:", "fix(scope)!:" or a "BREAKING CHANGE:" footer indicates major
        if ($c -match '(?m)^BREAKING[- ]CHANGE:' -or $c -match '^[a-zA-Z]+(\([^)]*\))?!:') {
            $hasMajor = $true
        }
        elseif ($c -match '^feat(\([^)]*\))?:') {
            $hasMinor = $true
        }
        elseif ($c -match '^fix(\([^)]*\))?:') {
            $hasPatch = $true
        }
    }
    if ($hasMajor) { return 'major' }
    if ($hasMinor) { return 'minor' }
    if ($hasPatch) { return 'patch' }
    return 'none'
}

function Get-NextVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Current,
        [Parameter(Mandatory)][ValidateSet('major', 'minor', 'patch', 'none')][string]$BumpType
    )
    if ($Current -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "Invalid semver string: '$Current'"
    }
    $maj = [int]$Matches[1]; $min = [int]$Matches[2]; $pat = [int]$Matches[3]
    switch ($BumpType) {
        'major' { return "$($maj + 1).0.0" }
        'minor' { return "$maj.$($min + 1).0" }
        'patch' { return "$maj.$min.$($pat + 1)" }
        'none'  { return $Current }
    }
}

# ---------- I/O --------------------------------------------------------------

function Get-CurrentVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw

    if ($Path -like '*.json') {
        try { $obj = $raw | ConvertFrom-Json -ErrorAction Stop }
        catch { throw "Failed to parse JSON in $Path : $($_.Exception.Message)" }
        if (-not $obj.version) {
            throw "No 'version' field in $Path"
        }
        return [string]$obj.version
    }

    $v = $raw.Trim()
    if (-not $v) { throw "VERSION file is empty: $Path" }
    return $v
}

function Set-VersionFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$NewVersion
    )
    if ($Path -like '*.json') {
        $obj = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        $obj.version = $NewVersion
        ($obj | ConvertTo-Json -Depth 32) | Set-Content -LiteralPath $Path -NoNewline
    }
    else {
        Set-Content -LiteralPath $Path -Value $NewVersion -NoNewline
    }
}

function Read-Commits {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Commits file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    # "---" on its own line separates commit messages so we can preserve
    # multi-line commit bodies (needed for BREAKING CHANGE footers).
    $parts = $raw -split "(?m)^---\s*$"
    return @($parts | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function New-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string[]]$Commits,
        [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
    )
    $features = New-Object System.Collections.Generic.List[string]
    $fixes    = New-Object System.Collections.Generic.List[string]
    $breaking = New-Object System.Collections.Generic.List[string]
    $other    = New-Object System.Collections.Generic.List[string]

    foreach ($c in $Commits) {
        $first = ($c -split "`n", 2)[0].Trim()
        $isBreaking = ($c -match '(?m)^BREAKING[- ]CHANGE:') -or ($first -match '^[a-zA-Z]+(\([^)]*\))?!:')
        if ($isBreaking)              { [void]$breaking.Add($first) }
        elseif ($first -match '^feat') { [void]$features.Add($first) }
        elseif ($first -match '^fix')  { [void]$fixes.Add($first) }
        else                           { [void]$other.Add($first) }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## $Version - $Date")
    [void]$sb.AppendLine('')
    if ($breaking.Count) {
        [void]$sb.AppendLine('### BREAKING CHANGES')
        $breaking | ForEach-Object { [void]$sb.AppendLine("- $_") }
        [void]$sb.AppendLine('')
    }
    if ($features.Count) {
        [void]$sb.AppendLine('### Features')
        $features | ForEach-Object { [void]$sb.AppendLine("- $_") }
        [void]$sb.AppendLine('')
    }
    if ($fixes.Count) {
        [void]$sb.AppendLine('### Fixes')
        $fixes | ForEach-Object { [void]$sb.AppendLine("- $_") }
        [void]$sb.AppendLine('')
    }
    if ($other.Count) {
        [void]$sb.AppendLine('### Other')
        $other | ForEach-Object { [void]$sb.AppendLine("- $_") }
        [void]$sb.AppendLine('')
    }
    return $sb.ToString()
}

function Invoke-VersionBump {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VersionFile,
        [Parameter(Mandatory)][string]$CommitsFile,
        [string]$ChangelogFile = 'CHANGELOG.md'
    )
    $current = Get-CurrentVersion -Path $VersionFile
    $commits = Read-Commits -Path $CommitsFile
    $bump    = Get-BumpType -Commits $commits
    $next    = Get-NextVersion -Current $current -BumpType $bump

    if ($bump -ne 'none') {
        Set-VersionFile -Path $VersionFile -NewVersion $next
        $entry = New-ChangelogEntry -Version $next -Commits $commits
        $existing = if (Test-Path -LiteralPath $ChangelogFile) {
            (Get-Content -LiteralPath $ChangelogFile -Raw) -replace '^# Changelog\s*\r?\n+', ''
        }
        else { '' }
        Set-Content -LiteralPath $ChangelogFile -Value ("# Changelog`n`n" + $entry + $existing)
    }

    return [PSCustomObject]@{
        OldVersion = $current
        NewVersion = $next
        BumpType   = $bump
    }
}

# ---------- entry point ------------------------------------------------------

# Run only when invoked directly with -VersionFile. When dot-sourced from a
# test ($MyInvocation.InvocationName equals '.'), $VersionFile is empty and
# we simply expose the functions.
if ($MyInvocation.InvocationName -ne '.' -and $VersionFile) {
    try {
        $r = Invoke-VersionBump -VersionFile $VersionFile -CommitsFile $CommitsFile -ChangelogFile $ChangelogFile
        # Machine-parseable output for CI consumers.
        Write-Output "OLD_VERSION=$($r.OldVersion)"
        Write-Output "NEW_VERSION=$($r.NewVersion)"
        Write-Output "BUMP_TYPE=$($r.BumpType)"
    }
    catch {
        Write-Error $_.Exception.Message
        exit 1
    }
}
