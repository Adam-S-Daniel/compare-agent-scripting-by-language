<#
.SYNOPSIS
    Bumps a semantic version based on conventional commit messages.

.DESCRIPTION
    Reads a version file (plain text VERSION or package.json) and a list of
    conventional commits, determines the next semantic version, updates the
    file in place, appends a changelog entry, and writes the new version to
    stdout.

    Bump rules (highest match wins):
      breaking change (BREAKING CHANGE: footer or "!" after type/scope) -> major
      feat            -> minor
      fix             -> patch
      anything else   -> no change (still emits current version)

.PARAMETER VersionFile
    Path to a VERSION file (containing only the version) or a package.json file.

.PARAMETER CommitsFile
    Path to a file with one conventional-commit message per line. Multi-line
    bodies use a literal "\n" or are flattened on a single line; BREAKING CHANGE
    footers are detected when present anywhere in the line.

.PARAMETER ChangelogFile
    Path to the changelog file. Created if missing. New entry is prepended
    under a heading with the new version.

.OUTPUTS
    System.String. The new version (e.g. "1.2.0").
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $VersionFile,
    [Parameter(Mandatory)] [string] $CommitsFile,
    [string] $ChangelogFile = "CHANGELOG.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Version {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    if ($Path -match '\.json$') {
        $obj = $raw | ConvertFrom-Json
        if (-not $obj.PSObject.Properties['version']) {
            throw "package.json does not contain a 'version' field: $Path"
        }
        return [string]$obj.version
    }
    return $raw.Trim()
}

function Write-Version {
    param([string] $Path, [string] $NewVersion)
    if ($Path -match '\.json$') {
        $obj = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        $obj.version = $NewVersion
        $json = $obj | ConvertTo-Json -Depth 50
        Set-Content -LiteralPath $Path -Value $json -NoNewline
    } else {
        Set-Content -LiteralPath $Path -Value $NewVersion -NoNewline
    }
}

function Test-SemVer {
    param([string] $Version)
    if ($Version -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid semantic version: '$Version'. Expected MAJOR.MINOR.PATCH."
    }
}

function Get-BumpType {
    param([string[]] $Commits)
    $bump = 'none'
    foreach ($line in $Commits) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        # Breaking: "type!:" or "type(scope)!:" or contains "BREAKING CHANGE"
        if ($line -match '^[a-zA-Z]+(\([^)]+\))?!:' -or $line -match 'BREAKING CHANGE') {
            return 'major'
        }
        if ($line -match '^feat(\([^)]+\))?:') {
            if ($bump -ne 'minor') { $bump = 'minor' }
        } elseif ($line -match '^fix(\([^)]+\))?:') {
            if ($bump -eq 'none') { $bump = 'patch' }
        }
    }
    return $bump
}

function Step-Version {
    param([string] $Version, [string] $BumpType)
    Test-SemVer -Version $Version
    $parts = $Version -split '\.' | ForEach-Object { [int]$_ }
    switch ($BumpType) {
        'major' { return "$($parts[0]+1).0.0" }
        'minor' { return "$($parts[0]).$($parts[1]+1).0" }
        'patch' { return "$($parts[0]).$($parts[1]).$($parts[2]+1)" }
        default { return $Version }
    }
}

function New-ChangelogEntry {
    param([string] $NewVersion, [string[]] $Commits)
    $today = (Get-Date -Format 'yyyy-MM-dd')
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## $NewVersion - $today")
    [void]$sb.AppendLine()
    foreach ($c in $Commits) {
        if (-not [string]::IsNullOrWhiteSpace($c)) {
            [void]$sb.AppendLine("- $c")
        }
    }
    [void]$sb.AppendLine()
    return $sb.ToString()
}

# --- main ---
try {
    $current = Read-Version -Path $VersionFile
    Test-SemVer -Version $current

    $commits = @()
    if (Test-Path -LiteralPath $CommitsFile) {
        $commits = Get-Content -LiteralPath $CommitsFile
    } else {
        throw "Commits file not found: $CommitsFile"
    }

    $bump = Get-BumpType -Commits $commits
    $next = Step-Version -Version $current -BumpType $bump

    if ($next -ne $current) {
        Write-Version -Path $VersionFile -NewVersion $next
        $entry = New-ChangelogEntry -NewVersion $next -Commits $commits
        $existing = ''
        if (Test-Path -LiteralPath $ChangelogFile) {
            $existing = Get-Content -LiteralPath $ChangelogFile -Raw
        }
        Set-Content -LiteralPath $ChangelogFile -Value ($entry + $existing) -NoNewline
    }

    # Emit the new version on stdout (last line) and a clearly tagged marker line
    # so CI logs can be parsed unambiguously.
    Write-Output "NEW_VERSION=$next"
    Write-Output "BUMP_TYPE=$bump"
    Write-Output $next
}
catch {
    Write-Error "semantic-version-bumper failed: $($_.Exception.Message)"
    exit 1
}
