# SemanticVersionBumper module
#
# Parses conventional commit messages, computes the next semver,
# updates a version file (package.json or plain VERSION), and
# generates a changelog entry. See SemanticVersionBumper.Tests.ps1.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Regex matching the conventional commit "type(scope)?!?:" prefix.
$script:ConventionalRegex = '^(?<type>[a-zA-Z]+)(?:\((?<scope>[^)]+)\))?(?<bang>!)?:\s*(?<subject>.+)$'

function Get-BumpType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Commits
    )

    $bump = 'none'
    foreach ($raw in $Commits) {
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }
        $firstLine = ($raw -split "`n", 2)[0]
        $m = [regex]::Match($firstLine, $script:ConventionalRegex)
        if (-not $m.Success) { continue }

        $type = $m.Groups['type'].Value.ToLower()
        $bang = $m.Groups['bang'].Value -eq '!'
        $hasBreakingFooter = $raw -match '(?m)^BREAKING[ -]CHANGE:'

        if ($bang -or $hasBreakingFooter) {
            return 'major'
        }
        if ($type -eq 'feat' -and $bump -ne 'major') {
            $bump = 'minor'
        } elseif ($type -eq 'fix' -and $bump -eq 'none') {
            $bump = 'patch'
        }
    }
    return $bump
}

function Step-SemanticVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][ValidateSet('major','minor','patch','none')][string]$BumpType
    )

    if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "Invalid semantic version: '$Version'"
    }
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]

    switch ($BumpType) {
        'major' { return "$($major + 1).0.0" }
        'minor' { return "$major.$($minor + 1).0" }
        'patch' { return "$major.$minor.$($patch + 1)" }
        'none'  { return $Version }
    }
}

function Get-VersionFromFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }

    if ($Path -match '\.json$') {
        $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        if (-not $json.PSObject.Properties.Name.Contains('version')) {
            throw "package.json has no 'version' field: $Path"
        }
        return [string]$json.version
    }

    return (Get-Content -LiteralPath $Path -Raw).Trim()
}

function Set-VersionInFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$NewVersion
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }

    if ($Path -match '\.json$') {
        # Replace via regex to preserve formatting/ordering of fields.
        $content = Get-Content -LiteralPath $Path -Raw
        $updated = [regex]::Replace(
            $content,
            '("version"\s*:\s*")[^"]+(")',
            "`${1}$NewVersion`${2}",
            1
        )
        Set-Content -LiteralPath $Path -Value $updated -NoNewline
    } else {
        Set-Content -LiteralPath $Path -Value $NewVersion
    }
}

function New-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Date,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Commits
    )

    $features = @()
    $fixes = @()
    $breaking = @()
    $other = @()

    foreach ($raw in $Commits) {
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }
        $firstLine = ($raw -split "`n", 2)[0]
        $m = [regex]::Match($firstLine, $script:ConventionalRegex)
        if (-not $m.Success) {
            $other += $firstLine
            continue
        }
        $type = $m.Groups['type'].Value.ToLower()
        $scope = $m.Groups['scope'].Value
        $subject = $m.Groups['subject'].Value
        $bang = $m.Groups['bang'].Value -eq '!'
        $line = if ($scope) { "**$scope**: $subject" } else { $subject }

        if ($bang -or ($raw -match '(?m)^BREAKING[ -]CHANGE:\s*(.*)')) {
            $breaking += $line
        }
        switch ($type) {
            'feat' { $features += $line }
            'fix'  { $fixes += $line }
        }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## [$Version] - $Date")
    [void]$sb.AppendLine()
    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine('### BREAKING CHANGES')
        $breaking | ForEach-Object { [void]$sb.AppendLine("- $_") }
        [void]$sb.AppendLine()
    }
    if ($features.Count -gt 0) {
        [void]$sb.AppendLine('### Features')
        $features | ForEach-Object { [void]$sb.AppendLine("- $_") }
        [void]$sb.AppendLine()
    }
    if ($fixes.Count -gt 0) {
        [void]$sb.AppendLine('### Bug Fixes')
        $fixes | ForEach-Object { [void]$sb.AppendLine("- $_") }
        [void]$sb.AppendLine()
    }
    return $sb.ToString()
}

function Read-CommitsFile {
    # Each commit separated by a blank line so subjects + bodies are preserved.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Commits file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    # Split on blank line (two newlines). Each block is one commit message.
    $blocks = [regex]::Split($raw, '(\r?\n){2,}')
    $commits = @()
    foreach ($b in $blocks) {
        if ([string]::IsNullOrWhiteSpace($b)) { continue }
        $commits += $b.Trim()
    }
    return ,$commits
}

function Invoke-VersionBump {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VersionFile,
        [Parameter(Mandatory)][string]$CommitsFile,
        [Parameter(Mandatory)][string]$ChangelogFile,
        [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
    )

    $previous = Get-VersionFromFile -Path $VersionFile
    $commits = Read-CommitsFile -Path $CommitsFile
    $bumpType = Get-BumpType -Commits $commits
    $newVersion = Step-SemanticVersion -Version $previous -BumpType $bumpType

    if ($bumpType -ne 'none') {
        Set-VersionInFile -Path $VersionFile -NewVersion $newVersion
        $entry = New-ChangelogEntry -Version $newVersion -Date $Date -Commits $commits
        $existing = if (Test-Path -LiteralPath $ChangelogFile) {
            Get-Content -LiteralPath $ChangelogFile -Raw
        } else {
            "# Changelog`n`n"
        }
        # Prepend new entry below the title.
        if ($existing -match '^# Changelog') {
            $combined = $existing -replace '(?s)^(# Changelog\s*\r?\n\r?\n?)', "`$1$entry`n"
        } else {
            $combined = "# Changelog`n`n$entry`n$existing"
        }
        Set-Content -LiteralPath $ChangelogFile -Value $combined
    }

    return [pscustomobject]@{
        PreviousVersion = $previous
        NewVersion      = $newVersion
        BumpType        = $bumpType
        CommitCount     = $commits.Count
    }
}

Export-ModuleMember -Function `
    Get-BumpType, Step-SemanticVersion, Get-VersionFromFile, Set-VersionInFile, `
    New-ChangelogEntry, Read-CommitsFile, Invoke-VersionBump
