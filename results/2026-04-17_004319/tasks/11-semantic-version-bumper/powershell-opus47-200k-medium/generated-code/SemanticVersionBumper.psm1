# SemanticVersionBumper
# Parses semver from package.json, inspects conventional commits,
# determines next version, writes back file + appends changelog.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CurrentVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$PackageJsonPath)

    if (-not (Test-Path -LiteralPath $PackageJsonPath)) {
        throw "Package file not found: $PackageJsonPath"
    }
    $raw = Get-Content -LiteralPath $PackageJsonPath -Raw
    try {
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Invalid JSON in ${PackageJsonPath}: $($_.Exception.Message)"
    }
    if (-not $obj.PSObject.Properties['version'] -or [string]::IsNullOrWhiteSpace($obj.version)) {
        throw "No 'version' field in $PackageJsonPath"
    }
    if ($obj.version -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid semantic version: $($obj.version)"
    }
    return [string]$obj.version
}

function Get-BumpType {
    # Inspect commit messages to determine bump type.
    # Precedence: major > minor > patch > none
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Commits)

    $bump = 'none'
    foreach ($c in $Commits) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        # BREAKING CHANGE either in body or `!` after type/scope
        if ($c -match 'BREAKING CHANGE' -or $c -match '^[a-zA-Z]+(\([^)]+\))?!:') {
            return 'major'
        }
        if ($c -match '^feat(\([^)]+\))?:' -and $bump -ne 'minor') {
            $bump = 'minor'
        } elseif ($c -match '^fix(\([^)]+\))?:' -and $bump -eq 'none') {
            $bump = 'patch'
        }
    }
    return $bump
}

function Get-NextVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CurrentVersion,
        [Parameter(Mandatory)][ValidateSet('major','minor','patch','none')][string]$BumpType
    )
    if ($CurrentVersion -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "Invalid semantic version: $CurrentVersion"
    }
    $maj = [int]$Matches[1]; $min = [int]$Matches[2]; $pat = [int]$Matches[3]
    switch ($BumpType) {
        'major' { return "$($maj+1).0.0" }
        'minor' { return "$maj.$($min+1).0" }
        'patch' { return "$maj.$min.$($pat+1)" }
        'none'  { return $CurrentVersion }
    }
}

function Update-VersionFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PackageJsonPath,
        [Parameter(Mandatory)][string]$NewVersion
    )
    if ($NewVersion -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid semantic version: $NewVersion"
    }
    $raw = Get-Content -LiteralPath $PackageJsonPath -Raw
    # Replace only the version field to preserve formatting.
    $updated = [regex]::Replace(
        $raw,
        '("version"\s*:\s*")[^"]+(")',
        "`${1}$NewVersion`${2}",
        1
    )
    Set-Content -LiteralPath $PackageJsonPath -Value $updated -NoNewline
}

function New-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Commits,
        [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
    )
    $feat = @(); $fix = @(); $breaking = @(); $other = @()
    foreach ($c in $Commits) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        $line = ($c -split "`n")[0]
        if ($c -match 'BREAKING CHANGE' -or $line -match '^[a-zA-Z]+(\([^)]+\))?!:') {
            $breaking += $line
        } elseif ($line -match '^feat(\([^)]+\))?:\s*(.*)$') {
            $feat += $line
        } elseif ($line -match '^fix(\([^)]+\))?:\s*(.*)$') {
            $fix += $line
        } else {
            $other += $line
        }
    }
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## [$Version] - $Date")
    [void]$sb.AppendLine()
    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine("### BREAKING CHANGES")
        foreach ($l in $breaking) { [void]$sb.AppendLine("- $l") }
        [void]$sb.AppendLine()
    }
    if ($feat.Count -gt 0) {
        [void]$sb.AppendLine("### Features")
        foreach ($l in $feat) { [void]$sb.AppendLine("- $l") }
        [void]$sb.AppendLine()
    }
    if ($fix.Count -gt 0) {
        [void]$sb.AppendLine("### Fixes")
        foreach ($l in $fix) { [void]$sb.AppendLine("- $l") }
        [void]$sb.AppendLine()
    }
    if ($other.Count -gt 0) {
        [void]$sb.AppendLine("### Other")
        foreach ($l in $other) { [void]$sb.AppendLine("- $l") }
        [void]$sb.AppendLine()
    }
    return $sb.ToString()
}

function Add-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ChangelogPath,
        [Parameter(Mandatory)][string]$Entry
    )
    $header = "# Changelog`n`n"
    if (Test-Path -LiteralPath $ChangelogPath) {
        $existing = Get-Content -LiteralPath $ChangelogPath -Raw
        if ($existing -match '^\# Changelog') {
            # Insert new entry after the top header.
            $rest = $existing -replace '^\# Changelog\s*\r?\n\r?\n?', ''
            Set-Content -LiteralPath $ChangelogPath -Value ($header + $Entry + $rest) -NoNewline
        } else {
            Set-Content -LiteralPath $ChangelogPath -Value ($header + $Entry + $existing) -NoNewline
        }
    } else {
        Set-Content -LiteralPath $ChangelogPath -Value ($header + $Entry) -NoNewline
    }
}

function Invoke-VersionBump {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PackageJsonPath,
        [Parameter(Mandatory)][string]$ChangelogPath,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Commits
    )
    $current = Get-CurrentVersion -PackageJsonPath $PackageJsonPath
    $bump = Get-BumpType -Commits $Commits
    $next = Get-NextVersion -CurrentVersion $current -BumpType $bump
    if ($bump -ne 'none') {
        Update-VersionFile -PackageJsonPath $PackageJsonPath -NewVersion $next
        $entry = New-ChangelogEntry -Version $next -Commits $Commits
        Add-ChangelogEntry -ChangelogPath $ChangelogPath -Entry $entry
    }
    [pscustomobject]@{
        PreviousVersion = $current
        NewVersion      = $next
        BumpType        = $bump
    }
}

Export-ModuleMember -Function Get-CurrentVersion, Get-BumpType, Get-NextVersion,
    Update-VersionFile, New-ChangelogEntry, Add-ChangelogEntry, Invoke-VersionBump
