# VersionBumper.ps1 - Core functions for semantic version bumping
# Provides parsing, classification, bumping, changelog, and file-update logic
# based on conventional commit messages (https://www.conventionalcommits.org).

function Get-CurrentVersion {
    # Reads a semantic version from a VERSION file (plain text) or package.json.
    # Returns a hashtable with Major, Minor, Patch, and Raw keys.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        throw "Version file not found: $FilePath"
    }

    $content = Get-Content $FilePath -Raw

    if ($FilePath -match '\.json$') {
        # Parse JSON and extract the "version" field
        try {
            $json = $content | ConvertFrom-Json
            $versionString = $json.version
        } catch {
            throw "Failed to parse JSON from ${FilePath}: $_"
        }
        if (-not $versionString) {
            throw "No 'version' field found in $FilePath"
        }
    } else {
        # Plain text - just trim whitespace
        $versionString = $content.Trim()
    }

    # Match major.minor.patch with optional v prefix
    if ($versionString -match '^v?(\d+)\.(\d+)\.(\d+)$') {
        return @{
            Major = [int]$Matches[1]
            Minor = [int]$Matches[2]
            Patch = [int]$Matches[3]
            Raw   = $versionString
        }
    } else {
        throw "Invalid semantic version format: '$versionString'"
    }
}

function Get-CommitMessages {
    # Retrieves commit messages from a fixture file or git log.
    # When CommitLogFile is provided and exists, reads from it (one message per line).
    # Otherwise falls back to git log.
    [CmdletBinding()]
    param(
        [string]$CommitLogFile = "",
        [string]$Since = ""
    )

    if ($CommitLogFile -and (Test-Path $CommitLogFile)) {
        return @(Get-Content $CommitLogFile | Where-Object { $_.Trim() -ne '' })
    }

    # Fall back to git log
    try {
        if ($Since) {
            $messages = git log "$Since..HEAD" --pretty=format:"%s" 2>&1
        } else {
            $messages = git log --pretty=format:"%s" 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            throw "git log failed: $messages"
        }
        return @($messages | Where-Object { $_.Trim() -ne '' })
    } catch {
        throw "Failed to get commit messages: $_"
    }
}

function Get-BumpType {
    # Analyzes conventional commit messages to determine the bump type.
    # Priority: breaking (major) > feat (minor) > everything else (patch).
    # Breaking is detected via ! before colon or BREAKING CHANGE keyword.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$CommitMessages
    )

    $bumpType = 'patch'

    foreach ($msg in $CommitMessages) {
        # Breaking change: type!: or BREAKING CHANGE: anywhere
        if ($msg -match '^[a-z]+(\(.+\))?!:' -or $msg -match 'BREAKING CHANGE:') {
            return 'major'  # Highest priority - return immediately
        }
        # Feature commit
        if ($msg -match '^feat(\(.+\))?:') {
            $bumpType = 'minor'
        }
    }

    return $bumpType
}

function Invoke-VersionBump {
    # Calculates the new version given the current version and bump type.
    # Major resets minor+patch, minor resets patch, patch just increments.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CurrentVersion,

        [Parameter(Mandatory)]
        [ValidateSet('major', 'minor', 'patch')]
        [string]$BumpType
    )

    $major = $CurrentVersion.Major
    $minor = $CurrentVersion.Minor
    $patch = $CurrentVersion.Patch

    switch ($BumpType) {
        'major' { $major++; $minor = 0; $patch = 0 }
        'minor' { $minor++; $patch = 0 }
        'patch' { $patch++ }
    }

    return "$major.$minor.$patch"
}

function New-ChangelogEntry {
    # Generates a markdown changelog entry grouped by commit type.
    # Sections: Breaking Changes, Features, Bug Fixes, Other.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$NewVersion,

        [Parameter(Mandatory)]
        [string[]]$CommitMessages
    )

    $date = Get-Date -Format 'yyyy-MM-dd'
    $breaking = [System.Collections.Generic.List[string]]::new()
    $features = [System.Collections.Generic.List[string]]::new()
    $fixes    = [System.Collections.Generic.List[string]]::new()
    $other    = [System.Collections.Generic.List[string]]::new()

    foreach ($msg in $CommitMessages) {
        if ($msg -match '^[a-z]+(\(.+\))?!:' -or $msg -match 'BREAKING CHANGE:') {
            $breaking.Add($msg)
        } elseif ($msg -match '^feat(\(.+\))?:') {
            $features.Add($msg)
        } elseif ($msg -match '^fix(\(.+\))?:') {
            $fixes.Add($msg)
        } else {
            $other.Add($msg)
        }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## [$NewVersion] - $date")
    [void]$sb.AppendLine()

    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine('### Breaking Changes')
        [void]$sb.AppendLine()
        foreach ($b in $breaking) { [void]$sb.AppendLine("- $b") }
        [void]$sb.AppendLine()
    }
    if ($features.Count -gt 0) {
        [void]$sb.AppendLine('### Features')
        [void]$sb.AppendLine()
        foreach ($f in $features) { [void]$sb.AppendLine("- $f") }
        [void]$sb.AppendLine()
    }
    if ($fixes.Count -gt 0) {
        [void]$sb.AppendLine('### Bug Fixes')
        [void]$sb.AppendLine()
        foreach ($f in $fixes) { [void]$sb.AppendLine("- $f") }
        [void]$sb.AppendLine()
    }
    if ($other.Count -gt 0) {
        [void]$sb.AppendLine('### Other')
        [void]$sb.AppendLine()
        foreach ($o in $other) { [void]$sb.AppendLine("- $o") }
        [void]$sb.AppendLine()
    }

    return $sb.ToString()
}

function Update-VersionFile {
    # Writes the new version back to a VERSION file or package.json.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string]$NewVersion
    )

    if ($FilePath -match '\.json$') {
        if (-not (Test-Path $FilePath)) {
            throw "File not found: $FilePath"
        }
        $json = Get-Content $FilePath -Raw | ConvertFrom-Json
        $json.version = $NewVersion
        $json | ConvertTo-Json -Depth 10 | Set-Content $FilePath -NoNewline
    } else {
        Set-Content -Path $FilePath -Value $NewVersion -NoNewline
    }
}
