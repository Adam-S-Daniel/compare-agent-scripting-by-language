# LogAnalyzer.ps1
# Log File Analyzer — parses mixed syslog/JSON log files, extracts errors and
# warnings, and produces a frequency table with timestamps plus JSON export.
#
# Design approach
# ---------------
# Each public function is kept small and single-purpose so that Pester tests
# can exercise them in isolation without spinning up a whole pipeline.
#
# Syslog format assumed:
#   <ISO8601-timestamp> <LEVEL> [<Source>] <message...>
#   e.g.  2024-01-15T10:30:45 ERROR [AppServer] Connection refused
#
# JSON format assumed:
#   { "timestamp": "<ISO8601>", "level": "<LEVEL>", "type": "<ErrorType>",
#     "message": "<text>" }
#   The "type" field is optional; when absent it defaults to the level value.

# ---------------------------------------------------------------------------
# Regex for the syslog line format
# ---------------------------------------------------------------------------
$script:SyslogPattern = '^(?<ts>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\s+' +
                        '(?<level>[A-Z]+)\s+' +
                        '\[(?<source>[^\]]+)\]\s+' +
                        '(?<message>.+)$'

# ==============================================================================
# CYCLE 1 — Parse a single syslog-style line
# ==============================================================================
function Parse-SyslogLine {
    <#
    .SYNOPSIS
        Parses one syslog-format log line into a structured object.
    .OUTPUTS
        PSCustomObject with Timestamp, Level, Source, Message, Format
        or $null when the line does not match the expected pattern.
    #>
    param(
        [string]$Line
    )

    if ($Line -match $script:SyslogPattern) {
        return [PSCustomObject]@{
            Timestamp = [datetime]$Matches['ts']
            Level     = $Matches['level']
            Source    = $Matches['source']
            Type      = $Matches['level']   # syslog has no explicit type; use level
            Message   = $Matches['message']
            Format    = 'syslog'
        }
    }

    return $null
}

# ==============================================================================
# CYCLE 2 — Parse a single JSON-structured log line
# ==============================================================================
function Parse-JsonLine {
    <#
    .SYNOPSIS
        Parses one JSON log line into a structured object.
    .OUTPUTS
        PSCustomObject with Timestamp, Level, Type, Message, Format
        or $null when the line is not valid JSON or lacks required fields.
    #>
    param(
        [string]$Line
    )

    # Quick pre-check: must start with '{' to be JSON
    if ($Line -notmatch '^\s*\{') { return $null }

    try {
        $obj = $Line | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }

    # Require at least timestamp, level, and message fields
    if (-not ($obj.PSObject.Properties.Name -contains 'timestamp') -or
        -not ($obj.PSObject.Properties.Name -contains 'level') -or
        -not ($obj.PSObject.Properties.Name -contains 'message')) {
        return $null
    }

    # "type" is optional; fall back to the level string when absent
    $type = if ($obj.PSObject.Properties.Name -contains 'type') { $obj.type } else { $obj.level }

    return [PSCustomObject]@{
        Timestamp = [datetime]$obj.timestamp
        Level     = $obj.level.ToUpper()
        Source    = if ($obj.PSObject.Properties.Name -contains 'source') { $obj.source } else { '' }
        Type      = $type
        Message   = $obj.message
        Format    = 'json'
    }
}

# ==============================================================================
# CYCLE 3 — Auto-detect format and dispatch to the correct parser
# ==============================================================================
function Parse-LogLine {
    <#
    .SYNOPSIS
        Detects whether a line is syslog or JSON format and parses it.
    .OUTPUTS
        PSCustomObject (see Parse-SyslogLine / Parse-JsonLine) or $null.
    #>
    param(
        [string]$Line
    )

    $trimmed = $Line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { return $null }

    # Try JSON first (starts with '{'), then syslog
    if ($trimmed.StartsWith('{')) {
        return Parse-JsonLine -Line $trimmed
    }

    return Parse-SyslogLine -Line $trimmed
}

# ==============================================================================
# CYCLE 4 — Parse an entire log file
# ==============================================================================
function Parse-LogFile {
    <#
    .SYNOPSIS
        Reads a log file line-by-line and returns all successfully parsed entries.
    .OUTPUTS
        Array of PSCustomObjects. Unrecognised lines are silently skipped.
    .THROWS
        A descriptive error when the file is not found.
    #>
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Log file not found: '$Path'"
    }

    $entries = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($line in [System.IO.File]::ReadLines($Path)) {
        $parsed = Parse-LogLine -Line $line
        if ($null -ne $parsed) {
            $entries.Add($parsed)
        }
    }

    return $entries.ToArray()
}

# ==============================================================================
# CYCLE 5 — Filter entries to errors and warnings only
# ==============================================================================
function Get-ErrorsAndWarnings {
    <#
    .SYNOPSIS
        Filters a collection of log entries to ERROR and WARNING levels only.
    .OUTPUTS
        Filtered array of PSCustomObjects.
    #>
    param(
        [PSCustomObject[]]$Entries
    )

    return @($Entries | Where-Object { $_.Level -in @('ERROR', 'WARNING') })
}

# ==============================================================================
# CYCLE 6 — Build a frequency table from filtered entries
# ==============================================================================
function Build-FrequencyTable {
    <#
    .SYNOPSIS
        Groups log entries by Type and computes count, first/last timestamps,
        and dominant severity level.
    .OUTPUTS
        Array of PSCustomObjects: Type, Level, Count, FirstOccurrence, LastOccurrence.
        Sorted descending by Count.
    #>
    param(
        [PSCustomObject[]]$Entries
    )

    if ($Entries.Count -eq 0) { return @() }

    $grouped = $Entries | Group-Object -Property Type

    $rows = foreach ($group in $grouped) {
        $sorted    = $group.Group | Sort-Object Timestamp
        $first     = $sorted[0].Timestamp
        $last      = $sorted[-1].Timestamp

        # Determine dominant level (ERROR beats WARNING)
        $level = if ($group.Group | Where-Object { $_.Level -eq 'ERROR' }) { 'ERROR' } else { 'WARNING' }

        [PSCustomObject]@{
            Type            = $group.Name
            Level           = $level
            Count           = $group.Count
            FirstOccurrence = $first
            LastOccurrence  = $last
        }
    }

    return @($rows | Sort-Object Count -Descending)
}

# ==============================================================================
# CYCLE 7 — Format the frequency table as a human-readable string
# ==============================================================================
function Format-FrequencyTable {
    <#
    .SYNOPSIS
        Renders the frequency table as a padded, human-readable text table.
    .OUTPUTS
        Multi-line string ready to be written to the console or a file.
    #>
    param(
        [PSCustomObject[]]$FrequencyTable
    )

    $sb = [System.Text.StringBuilder]::new()

    # Header
    $header  = "{0,-30} {1,-8} {2,-6} {3,-22} {4,-22}" -f "Type", "Level", "Count", "First Occurrence", "Last Occurrence"
    $divider = "-" * $header.Length

    [void]$sb.AppendLine("Log Analysis — Error/Warning Frequency Table")
    [void]$sb.AppendLine($divider)
    [void]$sb.AppendLine($header)
    [void]$sb.AppendLine($divider)

    foreach ($row in $FrequencyTable) {
        $line = "{0,-30} {1,-8} {2,-6} {3,-22} {4,-22}" -f `
            $row.Type,
            $row.Level,
            $row.Count,
            $row.FirstOccurrence.ToString("yyyy-MM-dd HH:mm:ss"),
            $row.LastOccurrence.ToString("yyyy-MM-dd HH:mm:ss")
        [void]$sb.AppendLine($line)
    }

    [void]$sb.AppendLine($divider)
    [void]$sb.AppendLine("Total distinct error/warning types: $($FrequencyTable.Count)")

    return $sb.ToString()
}

# ==============================================================================
# CYCLE 8 — Export analysis to a JSON file
# ==============================================================================
function Export-AnalysisJson {
    <#
    .SYNOPSIS
        Serialises the frequency table to a JSON file using camelCase keys.
    #>
    param(
        [PSCustomObject[]]$FrequencyTable,
        [string]$Path
    )

    # Convert to plain hashtables with camelCase keys for clean JSON output
    $jsonObjects = $FrequencyTable | ForEach-Object {
        [ordered]@{
            type            = $_.Type
            level           = $_.Level
            count           = $_.Count
            firstOccurrence = $_.FirstOccurrence.ToString("yyyy-MM-ddTHH:mm:ss")
            lastOccurrence  = $_.LastOccurrence.ToString("yyyy-MM-ddTHH:mm:ss")
        }
    }

    $jsonObjects | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
}

# ==============================================================================
# CYCLE 9 — End-to-end orchestration function
# ==============================================================================
function Invoke-LogAnalysis {
    <#
    .SYNOPSIS
        Full pipeline: parse log file → filter → build table → output table string
        and write JSON file.
    .OUTPUTS
        Human-readable table string (also writes JSON to JsonOutputPath).
    #>
    param(
        [string]$LogPath,
        [string]$JsonOutputPath
    )

    # Parse every recognisable line in the log file
    $allEntries = Parse-LogFile -Path $LogPath

    # Keep only errors and warnings
    $filtered = Get-ErrorsAndWarnings -Entries $allEntries

    # Build the frequency table
    $freqTable = Build-FrequencyTable -Entries $filtered

    # Export JSON side-effect
    Export-AnalysisJson -FrequencyTable $freqTable -Path $JsonOutputPath

    # Return the human-readable table string
    return Format-FrequencyTable -FrequencyTable $freqTable
}
