# SemanticVersionBumper.psm1
# Module implementing semantic version bumping based on conventional commits.

function Get-CurrentVersion {
    # Reads semantic version from a version file or package.json.
    # Accepts either a plain-text file containing "X.Y.Z" or a JSON file with a "version" field.
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }
    $raw = (Get-Content -LiteralPath $Path -Raw).Trim()
    if ($Path -match '\.json$') {
        try {
            $obj = $raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "Invalid JSON in $Path"
        }
        if (-not $obj.version) {
            throw "No 'version' field in $Path"
        }
        return [string]$obj.version
    }
    # plain text
    if ($raw -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid semver in $Path : '$raw'"
    }
    return $raw
}

function Get-BumpType {
    # Inspects a list of conventional-commit messages and returns the highest bump type.
    # breaking > major (major), feat > minor, fix > patch, else none.
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Commits
    )
    $highest = 'none'
    foreach ($c in $Commits) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        $type = 'none'
        # Breaking change: "feat!:" / "fix!:" or a "BREAKING CHANGE:" footer
        if ($c -match '^[a-zA-Z]+(\([^)]+\))?!:' -or $c -match 'BREAKING CHANGE:') {
            $type = 'major'
        } elseif ($c -match '^feat(\([^)]+\))?:') {
            $type = 'minor'
        } elseif ($c -match '^fix(\([^)]+\))?:') {
            $type = 'patch'
        }
        if ($type -eq 'major') { return 'major' }
        if ($type -eq 'minor' -and $highest -ne 'major') { $highest = 'minor' }
        elseif ($type -eq 'patch' -and $highest -eq 'none') { $highest = 'patch' }
    }
    return $highest
}

function Step-Version {
    # Pure function: given a semver string and a bump type, return the new version.
    param(
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)][ValidateSet('major','minor','patch','none')][string]$BumpType
    )
    if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "Invalid semver: $Version"
    }
    $maj = [int]$Matches[1]; $min = [int]$Matches[2]; $pat = [int]$Matches[3]
    switch ($BumpType) {
        'major' { return "$($maj+1).0.0" }
        'minor' { return "$maj.$($min+1).0" }
        'patch' { return "$maj.$min.$($pat+1)" }
        'none'  { return $Version }
    }
}

function Set-CurrentVersion {
    # Writes the new version back into the version file, preserving format.
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$NewVersion
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }
    if ($Path -match '\.json$') {
        $raw = Get-Content -LiteralPath $Path -Raw
        $obj = $raw | ConvertFrom-Json
        $obj.version = $NewVersion
        ($obj | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $Path -NoNewline
    } else {
        Set-Content -LiteralPath $Path -Value $NewVersion -NoNewline
    }
}

function New-ChangelogEntry {
    # Generates a markdown changelog entry grouping commits by type.
    param(
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Commits,
        [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
    )
    $features = @(); $fixes = @(); $breaking = @(); $other = @()
    foreach ($c in $Commits) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        $first = ($c -split "`n")[0]
        if ($c -match '^[a-zA-Z]+(\([^)]+\))?!:' -or $c -match 'BREAKING CHANGE:') {
            $breaking += $first
        } elseif ($first -match '^feat(\([^)]+\))?:') {
            $features += $first
        } elseif ($first -match '^fix(\([^)]+\))?:') {
            $fixes += $first
        } else {
            $other += $first
        }
    }
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## $Version - $Date")
    [void]$sb.AppendLine("")
    if ($breaking.Count) {
        [void]$sb.AppendLine("### BREAKING CHANGES")
        foreach ($l in $breaking) { [void]$sb.AppendLine("- $l") }
        [void]$sb.AppendLine("")
    }
    if ($features.Count) {
        [void]$sb.AppendLine("### Features")
        foreach ($l in $features) { [void]$sb.AppendLine("- $l") }
        [void]$sb.AppendLine("")
    }
    if ($fixes.Count) {
        [void]$sb.AppendLine("### Fixes")
        foreach ($l in $fixes) { [void]$sb.AppendLine("- $l") }
        [void]$sb.AppendLine("")
    }
    if ($other.Count) {
        [void]$sb.AppendLine("### Other")
        foreach ($l in $other) { [void]$sb.AppendLine("- $l") }
        [void]$sb.AppendLine("")
    }
    return $sb.ToString()
}

function Invoke-VersionBump {
    # Orchestrates: read version, determine bump, write version, prepend changelog, return new version.
    param(
        [Parameter(Mandatory = $true)][string]$VersionFile,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Commits,
        [string]$ChangelogFile
    )
    $current = Get-CurrentVersion -Path $VersionFile
    $bump = Get-BumpType -Commits $Commits
    $new = Step-Version -Version $current -BumpType $bump
    if ($bump -ne 'none') {
        Set-CurrentVersion -Path $VersionFile -NewVersion $new
        if ($ChangelogFile) {
            $entry = New-ChangelogEntry -Version $new -Commits $Commits
            $existing = ''
            if (Test-Path -LiteralPath $ChangelogFile) {
                $existing = Get-Content -LiteralPath $ChangelogFile -Raw
            }
            $content = "# Changelog`n`n" + $entry
            if ($existing -and $existing -notmatch '^\s*#\s*Changelog') {
                $content += $existing
            } elseif ($existing) {
                # strip existing top header
                $stripped = $existing -replace '^\s*#\s*Changelog\s*\r?\n\r?\n?', ''
                $content = "# Changelog`n`n" + $entry + $stripped
            }
            Set-Content -LiteralPath $ChangelogFile -Value $content -NoNewline
        }
    }
    return [pscustomobject]@{
        OldVersion = $current
        NewVersion = $new
        BumpType   = $bump
    }
}

Export-ModuleMember -Function Get-CurrentVersion, Get-BumpType, Step-Version, Set-CurrentVersion, New-ChangelogEntry, Invoke-VersionBump
