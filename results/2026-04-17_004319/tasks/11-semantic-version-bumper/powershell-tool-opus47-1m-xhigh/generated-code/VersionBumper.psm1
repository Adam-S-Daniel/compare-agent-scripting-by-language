#Requires -Version 7.0
Set-StrictMode -Version 3.0

# VersionBumper — semantic versioning from conventional commits.
#
# Public functions:
#   Get-NextVersion      Pure computation: (current, commits) -> next version.
#   Read-VersionFile     Read version from VERSION file or package.json.
#   Write-VersionFile    Persist a new version, preserving surrounding file content.
#   New-ChangelogEntry   Render a conventional-commits grouped changelog section.
#   Invoke-VersionBump   End-to-end orchestration used by the CLI/workflow.

# Regex capturing the conventional-commit "type" + optional scope + optional ! breaking.
# Example matches:  feat:, fix(parser):, refactor!:, feat(api)!:
$script:HeaderPattern = '^(?<type>[a-zA-Z]+)(?<scope>\([^)]+\))?(?<bang>!)?:\s*(?<subject>.+)$'

function Assert-SemVer {
    param([Parameter(Mandatory)][string]$Version)
    if ($Version -notmatch '^\d+\.\d+\.\d+$') {
        throw "Not a valid semantic version: '$Version'. Expected MAJOR.MINOR.PATCH."
    }
}

function Get-BumpLevel {
    # Inspect commits, return 'major' | 'minor' | 'patch' | 'none'.
    param([string[]]$Commits)

    $level = 'none'
    foreach ($raw in $Commits) {
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }
        $header = ($raw -split "`n", 2)[0]

        $isBreaking = $false
        $type = $null
        if ($header -match $script:HeaderPattern) {
            $type = $Matches['type'].ToLower()
            if ($Matches['bang']) { $isBreaking = $true }
        }
        # Footer-style BREAKING CHANGE: <text>
        if ($raw -match '(?m)^BREAKING[ -]CHANGE:') { $isBreaking = $true }

        if ($isBreaking) { return 'major' }
        if ($type -eq 'feat' -and $level -ne 'major') { $level = 'minor' }
        elseif ($type -eq 'fix' -and $level -notin @('major', 'minor')) { $level = 'patch' }
    }
    return $level
}

function Get-NextVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Current,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Commits
    )
    Assert-SemVer -Version $Current
    $parts = $Current.Split('.') | ForEach-Object { [int]$_ }
    $level = Get-BumpLevel -Commits $Commits

    switch ($level) {
        'major' { return "{0}.0.0" -f ($parts[0] + 1) }
        'minor' { return "{0}.{1}.0" -f $parts[0], ($parts[1] + 1) }
        'patch' { return "{0}.{1}.{2}" -f $parts[0], $parts[1], ($parts[2] + 1) }
        default { return $Current }
    }
}

function Read-VersionFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }
    if ([IO.Path]::GetFileName($Path) -ieq 'package.json') {
        $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        if (-not $json.PSObject.Properties.Name -contains 'version') {
            throw "package.json at $Path has no 'version' field"
        }
        return [string]$json.version
    }
    return (Get-Content -LiteralPath $Path -Raw).Trim()
}

function Write-VersionFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Version
    )
    Assert-SemVer -Version $Version
    if ([IO.Path]::GetFileName($Path) -ieq 'package.json') {
        $raw = Get-Content -LiteralPath $Path -Raw
        # Replace the version string in place so we preserve formatting and key order.
        $updated = [regex]::Replace(
            $raw,
            '("version"\s*:\s*")[^"]+(")',
            { param($m) $m.Groups[1].Value + $Version + $m.Groups[2].Value },
            [System.Text.RegularExpressions.RegexOptions]::Singleline
        )
        Set-Content -LiteralPath $Path -Value $updated -NoNewline
    }
    else {
        Set-Content -LiteralPath $Path -Value "$Version`n" -NoNewline
    }
}

function Get-CommitSubject {
    param([string]$Commit)
    $header = ($Commit -split "`n", 2)[0]
    if ($header -match $script:HeaderPattern) { return $Matches['subject'].Trim() }
    return $header.Trim()
}

function New-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Date,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Commits
    )

    $features = [System.Collections.Generic.List[string]]::new()
    $fixes    = [System.Collections.Generic.List[string]]::new()
    $breaking = [System.Collections.Generic.List[string]]::new()

    foreach ($raw in $Commits) {
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }
        $header = ($raw -split "`n", 2)[0]
        $type = $null
        $bang = $false
        if ($header -match $script:HeaderPattern) {
            $type = $Matches['type'].ToLower()
            if ($Matches['bang']) { $bang = $true }
        }
        $subject = Get-CommitSubject -Commit $raw
        if ($bang -or ($raw -match '(?m)^BREAKING[ -]CHANGE:')) { $breaking.Add($subject) }
        if ($type -eq 'feat') { $features.Add($subject) }
        elseif ($type -eq 'fix') { $fixes.Add($subject) }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## [$Version] - $Date")
    [void]$sb.AppendLine('')
    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine('### BREAKING CHANGES')
        foreach ($s in $breaking) { [void]$sb.AppendLine("- $s") }
        [void]$sb.AppendLine('')
    }
    if ($features.Count -gt 0) {
        [void]$sb.AppendLine('### Features')
        foreach ($s in $features) { [void]$sb.AppendLine("- $s") }
        [void]$sb.AppendLine('')
    }
    if ($fixes.Count -gt 0) {
        [void]$sb.AppendLine('### Bug Fixes')
        foreach ($s in $fixes) { [void]$sb.AppendLine("- $s") }
        [void]$sb.AppendLine('')
    }
    return $sb.ToString()
}

function Read-CommitsFile {
    # Commits are stored one-per-line (newlines within a commit escaped as literal \n).
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Commits file not found: $Path"
    }
    $lines = Get-Content -LiteralPath $Path
    $commits = foreach ($ln in $lines) {
        if ([string]::IsNullOrWhiteSpace($ln)) { continue }
        # Allow \n as multi-line marker so fixture files stay plain-text-diffable.
        $ln -replace '\\n', "`n"
    }
    return , [string[]]$commits
}

function Invoke-VersionBump {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VersionFile,
        [Parameter(Mandatory)][string]$CommitsFile,
        [Parameter(Mandatory)][string]$ChangelogFile,
        [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
    )

    $current = Read-VersionFile -Path $VersionFile
    Assert-SemVer -Version $current
    $commits = Read-CommitsFile -Path $CommitsFile
    $next = Get-NextVersion -Current $current -Commits $commits

    if ($next -ne $current) {
        Write-VersionFile -Path $VersionFile -Version $next
        $entry = New-ChangelogEntry -Version $next -Date $Date -Commits $commits
        $existing = ''
        if (Test-Path -LiteralPath $ChangelogFile) {
            $existing = Get-Content -LiteralPath $ChangelogFile -Raw
        }
        # Keep a stable "# Changelog" title at the top if present; otherwise create one.
        if ($existing -match '^\s*#\s+Changelog') {
            $idx = $existing.IndexOf("`n")
            $title = $existing.Substring(0, $idx + 1)
            $rest  = $existing.Substring($idx + 1)
            $combined = $title + "`n" + $entry + $rest.TrimStart("`r", "`n")
        }
        else {
            $combined = "# Changelog`n`n" + $entry + $existing
        }
        Set-Content -LiteralPath $ChangelogFile -Value $combined -NoNewline
    }
    return $next
}

Export-ModuleMember -Function Get-NextVersion, Read-VersionFile, Write-VersionFile,
    New-ChangelogEntry, Invoke-VersionBump, Read-CommitsFile
