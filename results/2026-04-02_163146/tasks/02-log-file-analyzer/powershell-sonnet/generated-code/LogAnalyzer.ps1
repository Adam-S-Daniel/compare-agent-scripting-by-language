# LogAnalyzer.ps1
# Log File Analyzer - Implementation
# Parses mixed-format log files (syslog-style and JSON-structured),
# extracts errors/warnings, builds a frequency table, and exports results.

# ============================================================
# PHASE 1: Parse syslog-style log lines
# Expected format: "YYYY-MM-DD HH:MM:SS LEVEL component: message"
# ============================================================
function Parse-SyslogLine {
    <#
    .SYNOPSIS
        Parses a single syslog-style log line into a structured object.
    .PARAMETER Line
        The raw log line string to parse.
    .OUTPUTS
        PSCustomObject with Timestamp, Level, Component, Message, Format fields,
        or $null if the line doesn't match the expected format.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Line
    )

    # Regex: date + time + level + component: message
    $pattern = '^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(ERROR|WARNING|WARN|INFO|DEBUG|CRITICAL)\s+(\w+):\s+(.+)$'

    if ($Line -match $pattern) {
        return [PSCustomObject]@{
            Timestamp = [datetime]$Matches[1]
            Level     = $Matches[2] -replace '^WARN$', 'WARNING'  # normalize WARN -> WARNING
            Component = $Matches[3]
            Message   = $Matches[4]
            Format    = 'syslog'
        }
    }

    return $null
}

# ============================================================
# PHASE 2: Parse JSON-structured log lines
# Expected format: {"timestamp":"...","level":"...","component":"...","message":"..."}
# ============================================================
function Parse-JsonLogLine {
    <#
    .SYNOPSIS
        Parses a JSON-formatted log line into a structured object.
    .PARAMETER Line
        The raw log line string to parse.
    .OUTPUTS
        PSCustomObject with Timestamp, Level, Component, Message, Format fields,
        or $null if the line is not valid JSON or lacks required fields.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Line
    )

    # Attempt JSON parse; return null on failure
    try {
        $json = $Line | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return $null
    }

    # Validate required fields exist (use .Name -contains for reliable truthiness check)
    $required = @('timestamp', 'level', 'message')
    $propNames = $json.PSObject.Properties.Name
    foreach ($field in $required) {
        if ($propNames -notcontains $field) {
            return $null
        }
    }

    # component is optional; fall back to "unknown"
    $component = if ($propNames -contains 'component') { $json.component } else { 'unknown' }

    # Parse timestamp - handle ISO 8601 with Z suffix
    $ts = [datetime]::Parse($json.timestamp, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)

    return [PSCustomObject]@{
        Timestamp = $ts
        Level     = ($json.level).ToUpper() -replace '^WARN$', 'WARNING'  # normalize WARN -> WARNING
        Component = $component
        Message   = $json.message
        Format    = 'json'
    }
}

# ============================================================
# PHASE 3: Parse a mixed log file (auto-detect format per line)
# ============================================================
function Parse-LogFile {
    <#
    .SYNOPSIS
        Reads a log file and parses each line, supporting both syslog and JSON formats.
    .PARAMETER Path
        Path to the log file.
    .OUTPUTS
        Array of PSCustomObjects representing parsed log entries.
        Malformed lines are silently skipped.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Validate file exists with a meaningful error message
    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        throw "Log file not found: '$Path'"
    }

    $entries = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($line in Get-Content -Path $Path) {
        # Skip blank lines
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        # Try JSON first (lines starting with '{' are likely JSON)
        $entry = $null
        if ($line.TrimStart().StartsWith('{')) {
            $entry = Parse-JsonLogLine -Line $line
        }

        # Fall back to syslog format
        if ($null -eq $entry) {
            $entry = Parse-SyslogLine -Line $line
        }

        # If still null, the line is malformed - skip it
        if ($null -ne $entry) {
            $entries.Add($entry)
        }
    }

    return $entries.ToArray()
}

# ============================================================
# PHASE 4: Filter errors and warnings
# ============================================================
function Get-ErrorsAndWarnings {
    <#
    .SYNOPSIS
        Filters a collection of log entries to only ERROR and WARNING levels.
    .PARAMETER Entries
        Array of parsed log entry objects.
    .OUTPUTS
        Filtered array containing only ERROR and WARNING entries.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Entries
    )

    return @($Entries | Where-Object { $_.Level -in @('ERROR', 'WARNING') })
}

# ============================================================
# PHASE 5: Build frequency table
# Groups entries by Level + Component + Message, counting occurrences
# and tracking first/last timestamps.
# ============================================================
function Build-FrequencyTable {
    <#
    .SYNOPSIS
        Builds a frequency table from log entries, grouped by level/component/message.
    .PARAMETER Entries
        Array of log entry objects (typically filtered to errors/warnings).
    .OUTPUTS
        Array of PSCustomObjects sorted by Count descending, each with:
        Level, Component, Message, Count, FirstOccurrence, LastOccurrence.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Entries
    )

    # Group by a composite key: Level + Component + Message
    $grouped = $Entries | Group-Object -Property Level, Component, Message

    $table = foreach ($group in $grouped) {
        $timestamps = $group.Group | Select-Object -ExpandProperty Timestamp | Sort-Object

        [PSCustomObject]@{
            Level           = $group.Group[0].Level
            Component       = $group.Group[0].Component
            Message         = $group.Group[0].Message
            Count           = $group.Count
            FirstOccurrence = $timestamps | Select-Object -First 1
            LastOccurrence  = $timestamps | Select-Object -Last 1
        }
    }

    # Sort by Count descending so most-frequent errors appear first
    return @($table | Sort-Object -Property Count -Descending)
}

# ============================================================
# PHASE 6: Export analysis as JSON
# ============================================================
function Export-AnalysisJson {
    <#
    .SYNOPSIS
        Exports the frequency table and summary metadata as a JSON file.
    .PARAMETER FrequencyTable
        Array of frequency table entries from Build-FrequencyTable.
    .PARAMETER OutputPath
        Path where the JSON file should be written.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$FrequencyTable,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $errorCount   = ($FrequencyTable | Where-Object { $_.Level -eq 'ERROR' }   | Measure-Object -Property Count -Sum).Sum
    $warningCount = ($FrequencyTable | Where-Object { $_.Level -eq 'WARNING' } | Measure-Object -Property Count -Sum).Sum

    $output = [ordered]@{
        generatedAt = (Get-Date -Format 'o')
        summary     = [ordered]@{
            totalErrors   = [int]($errorCount   ?? 0)
            totalWarnings = [int]($warningCount ?? 0)
            uniqueTypes   = $FrequencyTable.Count
        }
        entries = @(
            $FrequencyTable | ForEach-Object {
                [ordered]@{
                    level           = $_.Level
                    component       = $_.Component
                    message         = $_.Message
                    count           = $_.Count
                    firstOccurrence = $_.FirstOccurrence.ToString('o')
                    lastOccurrence  = $_.LastOccurrence.ToString('o')
                }
            }
        )
    }

    $output | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding UTF8
}

# ============================================================
# PHASE 7: Format human-readable table
# ============================================================
function Format-AnalysisTable {
    <#
    .SYNOPSIS
        Formats the frequency table as a human-readable text table.
    .PARAMETER FrequencyTable
        Array of frequency table entries from Build-FrequencyTable.
    .OUTPUTS
        A multi-line string containing the formatted table.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$FrequencyTable
    )

    if ($FrequencyTable.Count -eq 0) {
        return "No errors or warnings found."
    }

    # Define column widths
    $colLevel     = [Math]::Max(7,  ($FrequencyTable | ForEach-Object { $_.Level.Length }     | Measure-Object -Maximum).Maximum)
    $colComponent = [Math]::Max(9,  ($FrequencyTable | ForEach-Object { $_.Component.Length } | Measure-Object -Maximum).Maximum)
    $colMessage   = [Math]::Max(7,  ($FrequencyTable | ForEach-Object { $_.Message.Length }   | Measure-Object -Maximum).Maximum)
    $colCount     = 5
    $colDate      = 19  # "YYYY-MM-DD HH:MM:SS"

    # Build format string for rows
    $fmt = "{0,-$colLevel} | {1,-$colComponent} | {2,-$colMessage} | {3,$colCount} | {4,-$colDate} | {5,-$colDate}"

    $lines = [System.Collections.Generic.List[string]]::new()

    # Header
    $header    = $fmt -f "Level", "Component", "Message", "Count", "First Occurrence", "Last Occurrence"
    $separator = "-" * $header.Length

    $lines.Add("Log Analysis - Errors & Warnings Frequency Table")
    $lines.Add($separator)
    $lines.Add($header)
    $lines.Add($separator)

    foreach ($entry in $FrequencyTable) {
        $row = $fmt -f `
            $entry.Level, `
            $entry.Component, `
            $entry.Message, `
            $entry.Count, `
            ($entry.FirstOccurrence.ToString("yyyy-MM-dd HH:mm:ss")), `
            ($entry.LastOccurrence.ToString("yyyy-MM-dd HH:mm:ss"))
        $lines.Add($row)
    }

    $lines.Add($separator)
    $lines.Add("Total entries: $($FrequencyTable.Count) unique error/warning types")

    return $lines -join "`n"
}

# ============================================================
# PHASE 8: End-to-end orchestration
# ============================================================
function Invoke-LogAnalysis {
    <#
    .SYNOPSIS
        Runs the complete log analysis pipeline: parse, filter, tabulate, and export.
    .PARAMETER LogPath
        Path to the input log file.
    .PARAMETER JsonOutputPath
        Path where the JSON analysis output should be written.
    .OUTPUTS
        PSCustomObject with FrequencyTable and HumanReadableTable properties.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LogPath,

        [Parameter(Mandatory)]
        [string]$JsonOutputPath
    )

    Write-Verbose "Parsing log file: $LogPath"
    $allEntries = Parse-LogFile -Path $LogPath

    Write-Verbose "Parsed $($allEntries.Count) entries total"
    $filtered = Get-ErrorsAndWarnings -Entries $allEntries

    Write-Verbose "Found $($filtered.Count) error/warning entries"
    $freqTable = Build-FrequencyTable -Entries $filtered

    Write-Verbose "Built frequency table with $($freqTable.Count) unique types"
    Export-AnalysisJson -FrequencyTable $freqTable -OutputPath $JsonOutputPath

    $humanTable = Format-AnalysisTable -FrequencyTable $freqTable

    return [PSCustomObject]@{
        FrequencyTable     = $freqTable
        HumanReadableTable = $humanTable
        TotalEntries       = $allEntries.Count
        ErrorCount         = ($filtered | Where-Object { $_.Level -eq 'ERROR' }).Count
        WarningCount       = ($filtered | Where-Object { $_.Level -eq 'WARNING' }).Count
    }
}
