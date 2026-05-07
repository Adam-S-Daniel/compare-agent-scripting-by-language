Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Reads the current semantic version from a plain version.txt file or a package.json file.
function Get-CurrentVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw

    if ($Path -match '\.json$') {
        try {
            $json = $raw | ConvertFrom-Json
        } catch {
            throw "Failed to parse JSON from '$Path': $($_.Exception.Message)"
        }
        if (-not $json.PSObject.Properties.Name.Contains('version')) {
            throw "package.json at '$Path' has no 'version' field"
        }
        $version = $json.version
    } else {
        $version = $raw.Trim()
    }

    if ($version -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid semantic version '$version' in '$Path' (expected MAJOR.MINOR.PATCH)"
    }

    return $version
}

# Determines the bump type from a list of conventional-commit messages.
# Returns one of: 'major', 'minor', 'patch', 'none'.
function Get-BumpType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Commits
    )

    $bump = 'none'
    foreach ($commit in $Commits) {
        if ([string]::IsNullOrWhiteSpace($commit)) { continue }

        # Breaking change wins over everything; detected via "!" in the type or a
        # "BREAKING CHANGE:" footer anywhere in the body.
        if ($commit -match '^[a-zA-Z]+(\([^)]+\))?!:' -or $commit -match 'BREAKING CHANGE:') {
            return 'major'
        }
        if ($commit -match '^feat(\([^)]+\))?:' -and $bump -ne 'minor') {
            $bump = 'minor'
        } elseif ($commit -match '^fix(\([^)]+\))?:' -and $bump -eq 'none') {
            $bump = 'patch'
        }
    }
    return $bump
}

# Computes the next version from a current version + bump type.
function Get-NextVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CurrentVersion,
        [Parameter(Mandatory)][ValidateSet('major','minor','patch','none')][string]$BumpType
    )

    if ($CurrentVersion -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "Invalid current version '$CurrentVersion'"
    }
    $major = [int]$Matches[1]; $minor = [int]$Matches[2]; $patch = [int]$Matches[3]

    switch ($BumpType) {
        'major' { return "$($major + 1).0.0" }
        'minor' { return "$major.$($minor + 1).0" }
        'patch' { return "$major.$minor.$($patch + 1)" }
        'none'  { return $CurrentVersion }
    }
}

# Persists the new version back to the version file (txt or package.json),
# preserving JSON structure when applicable.
function Set-Version {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$NewVersion
    )

    if ($Path -match '\.json$') {
        $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        $json.version = $NewVersion
        ($json | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $Path -NoNewline
    } else {
        Set-Content -LiteralPath $Path -Value $NewVersion -NoNewline
    }
}

# Builds a markdown changelog entry from the version + commit list, grouping by type.
function New-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Commits,
        [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
    )

    $breaking = @(); $features = @(); $fixes = @(); $other = @()
    foreach ($c in $Commits) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        $line = ($c -split "`n")[0]
        if ($c -match '^[a-zA-Z]+(\([^)]+\))?!:' -or $c -match 'BREAKING CHANGE:') {
            $breaking += $line
        } elseif ($line -match '^feat(\([^)]+\))?:') {
            $features += $line
        } elseif ($line -match '^fix(\([^)]+\))?:') {
            $fixes += $line
        } else {
            $other += $line
        }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## [$Version] - $Date")
    [void]$sb.AppendLine()
    if ($breaking.Count) {
        [void]$sb.AppendLine('### BREAKING CHANGES')
        foreach ($l in $breaking) { [void]$sb.AppendLine("- $l") }
        [void]$sb.AppendLine()
    }
    if ($features.Count) {
        [void]$sb.AppendLine('### Features')
        foreach ($l in $features) { [void]$sb.AppendLine("- $l") }
        [void]$sb.AppendLine()
    }
    if ($fixes.Count) {
        [void]$sb.AppendLine('### Fixes')
        foreach ($l in $fixes) { [void]$sb.AppendLine("- $l") }
        [void]$sb.AppendLine()
    }
    if ($other.Count) {
        [void]$sb.AppendLine('### Other')
        foreach ($l in $other) { [void]$sb.AppendLine("- $l") }
        [void]$sb.AppendLine()
    }
    return $sb.ToString()
}

# Reads commits from a fixture file: one commit per record, records separated by lines of "---".
function Read-CommitFixture {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Commits file not found: $Path" }
    $raw = Get-Content -LiteralPath $Path -Raw
    $commits = @()
    foreach ($chunk in ($raw -split "(?m)^---\s*$")) {
        $t = $chunk.Trim()
        if ($t) { $commits += $t }
    }
    return ,$commits
}

# Top-level orchestrator: reads version + commits, computes next version, updates files,
# prepends changelog entry, prints the new version. Returns the new version string.
function Invoke-VersionBump {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VersionFile,
        [Parameter(Mandatory)][string]$CommitsFile,
        [string]$ChangelogFile = 'CHANGELOG.md'
    )

    $current = Get-CurrentVersion -Path $VersionFile
    $commits = Read-CommitFixture -Path $CommitsFile
    $bump = Get-BumpType -Commits $commits
    $next = Get-NextVersion -CurrentVersion $current -BumpType $bump

    if ($bump -eq 'none') {
        Write-Information "No version-affecting commits; version remains $current" -InformationAction Continue
        return $current
    }

    Set-Version -Path $VersionFile -NewVersion $next

    $entry = New-ChangelogEntry -Version $next -Commits $commits
    $existing = if (Test-Path -LiteralPath $ChangelogFile) { Get-Content -LiteralPath $ChangelogFile -Raw } else { "# Changelog`n`n" }
    Set-Content -LiteralPath $ChangelogFile -Value ($entry + "`n" + $existing) -NoNewline

    return $next
}

Export-ModuleMember -Function Get-CurrentVersion, Get-BumpType, Get-NextVersion, Set-Version, New-ChangelogEntry, Read-CommitFixture, Invoke-VersionBump
