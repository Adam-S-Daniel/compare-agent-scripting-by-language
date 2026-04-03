# LogAnalyzer.psm1
# Module for parsing mixed-format log files and generating error/warning frequency reports.
#
# TDD approach: each function was grown incrementally to satisfy failing Pester tests.
# Strict mode enforces type safety and prevents accidental use of undefined variables.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Syslog regex pattern
# Matches: "MMM  D HH:MM:SS host process[pid]: LEVEL: message"
# Groups:  month, day, time, host, process, pid, level, message
# ---------------------------------------------------------------------------
$Script:SyslogPattern = '^(?<month>\w{3})\s+(?<day>\d{1,2})\s+(?<time>\d{2}:\d{2}:\d{2})\s+(?<host>\S+)\s+(?<process>\S+?)\[(?<pid>\d+)\]:\s+(?<level>ERROR|WARNING|WARN|CRITICAL|INFO|DEBUG|NOTICE):\s*(?<message>.+)$'

# ---------------------------------------------------------------------------
# Parse-SyslogLine
# Parses a single syslog-formatted log line.
# Returns a PSCustomObject with Timestamp, Level, ErrorType, Source, RawLine
# or $null if the line is not syslog format or is not an error/warning level.
# ---------------------------------------------------------------------------
function Parse-SyslogLine {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $null
    }

    $match = [regex]::Match($Line, $Script:SyslogPattern)
    if (-not $match.Success) {
        return $null
    }

    [string]$level = $match.Groups['level'].Value

    # Only surface ERROR, WARNING, and WARN entries
    if ($level -notin @('ERROR', 'WARNING', 'WARN', 'CRITICAL')) {
        return $null
    }

    # Build a datetime from the syslog tokens (assume current year — syslog omits year)
    [string]$month = $match.Groups['month'].Value
    [string]$day   = $match.Groups['day'].Value
    [string]$time  = $match.Groups['time'].Value
    [int]$year     = [datetime]::Now.Year

    # Parse with explicit format; fall back gracefully on error
    [datetime]$timestamp = [datetime]::MinValue
    try {
        $timestamp = [datetime]::ParseExact(
            "$month $day $year $time",
            'MMM d yyyy HH:mm:ss',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } catch {
        # If parsing fails, use current time as fallback with a warning to stderr
        Write-Warning "Could not parse syslog timestamp from line: $Line"
        $timestamp = [datetime]::Now
    }

    [string]$source  = $match.Groups['process'].Value
    [string]$message = $match.Groups['message'].Value.Trim()

    return [PSCustomObject]@{
        Timestamp = $timestamp
        Level     = $level
        ErrorType = $message
        Source    = $source
        RawLine   = $Line
        Format    = 'syslog'
    }
}

# ---------------------------------------------------------------------------
# Parse-JsonLogLine
# Parses a single JSON-formatted log line.
# Returns a PSCustomObject with Timestamp, Level, ErrorType, Source, RawLine
# or $null if the line is not valid JSON or not an error/warning level.
# ---------------------------------------------------------------------------
function Parse-JsonLogLine {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $null
    }

    # Quick check: JSON lines must start with '{'
    $trimmed = $Line.Trim()
    if (-not $trimmed.StartsWith('{')) {
        return $null
    }

    # Attempt JSON deserialization
    $json = $null
    try {
        $json = $trimmed | ConvertFrom-Json
    } catch {
        return $null
    }

    # Validate required fields exist
    if ($null -eq $json.level -or $null -eq $json.timestamp) {
        return $null
    }

    [string]$level = [string]$json.level

    # Normalize to uppercase for consistent comparison
    $level = $level.ToUpperInvariant()

    if ($level -notin @('ERROR', 'WARNING', 'WARN', 'CRITICAL')) {
        return $null
    }

    # Parse timestamp — JSON logs use ISO 8601
    [datetime]$timestamp = [datetime]::MinValue
    try {
        $timestamp = [datetime]::Parse([string]$json.timestamp, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)
    } catch {
        Write-Warning "Could not parse JSON timestamp from line: $Line"
        $timestamp = [datetime]::Now
    }

    # Determine error type: prefer explicit error_type field, fall back to message
    [string]$errorType = ''
    if ($null -ne $json.error_type -and [string]$json.error_type -ne '') {
        $errorType = [string]$json.error_type
    } else {
        $errorType = [string]$json.message
    }

    # Determine source service
    [string]$source = ''
    if ($null -ne $json.service) {
        $source = [string]$json.service
    } elseif ($null -ne $json.host) {
        $source = [string]$json.host
    }

    return [PSCustomObject]@{
        Timestamp = $timestamp
        Level     = $level
        ErrorType = $errorType
        Source    = $source
        RawLine   = $Line
        Format    = 'json'
    }
}

# ---------------------------------------------------------------------------
# Get-LogEntries
# Parses an entire log file (mixed syslog + JSON format) and returns only
# the error/warning entries as an array of PSCustomObjects.
# Throws with a meaningful message if the file does not exist.
# ---------------------------------------------------------------------------
function Get-LogEntries {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [string]$LogPath
    )

    if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
        throw "Log file not found: '$LogPath'"
    }

    [System.Collections.Generic.List[PSCustomObject]]$entries = [System.Collections.Generic.List[PSCustomObject]]::new()

    [string[]]$lines = Get-Content -LiteralPath $LogPath

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        # Try JSON first (slightly cheaper to detect via leading brace)
        $parsed = $null
        if ($line.TrimStart().StartsWith('{')) {
            $parsed = Parse-JsonLogLine -Line $line
        } else {
            $parsed = Parse-SyslogLine -Line $line
        }

        if ($null -ne $parsed) {
            $entries.Add($parsed)
        }
    }

    return $entries.ToArray()
}

# ---------------------------------------------------------------------------
# Get-ErrorFrequencyTable
# Takes an array of log entry objects and produces a frequency table:
# one row per unique ErrorType, with Count, FirstSeen, LastSeen, and Level.
# Sorted by Count descending.
# ---------------------------------------------------------------------------
function Get-ErrorFrequencyTable {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [PSCustomObject[]]$Entries
    )

    if ($null -eq $Entries -or $Entries.Count -eq 0) {
        return [PSCustomObject[]]@()
    }

    # Group by ErrorType to aggregate counts and timestamps
    $groups = $Entries | Group-Object -Property ErrorType

    [System.Collections.Generic.List[PSCustomObject]]$rows = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($group in $groups) {
        [PSCustomObject[]]$groupItems = [PSCustomObject[]]$group.Group

        # Determine the dominant level (ERROR trumps WARN/WARNING)
        [string]$level = 'WARN'
        foreach ($item in $groupItems) {
            if ([string]$item.Level -eq 'ERROR' -or [string]$item.Level -eq 'CRITICAL') {
                $level = [string]$item.Level
                break
            }
        }
        # If no ERROR found, use the level from first item
        if ($level -eq 'WARN') {
            $level = [string]$groupItems[0].Level
        }

        # Find first and last timestamps
        [datetime]$firstSeen = ($groupItems | Sort-Object Timestamp | Select-Object -First 1).Timestamp
        [datetime]$lastSeen  = ($groupItems | Sort-Object Timestamp -Descending | Select-Object -First 1).Timestamp

        $rows.Add([PSCustomObject]@{
            ErrorType = [string]$group.Name
            Level     = $level
            Count     = [int]$group.Count
            FirstSeen = $firstSeen
            LastSeen  = $lastSeen
        })
    }

    # Sort by Count descending
    [PSCustomObject[]]$sorted = $rows.ToArray() | Sort-Object -Property Count -Descending
    return $sorted
}

# ---------------------------------------------------------------------------
# Format-FrequencyTable
# Renders the frequency table as a human-readable text table.
# Returns a formatted string suitable for console output or file writing.
# ---------------------------------------------------------------------------
function Format-FrequencyTable {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [PSCustomObject[]]$FrequencyTable
    )

    if ($null -eq $FrequencyTable -or $FrequencyTable.Count -eq 0) {
        return 'No error or warning entries found in the log file.'
    }

    # Determine column widths dynamically
    # Measure-Object returns nullable double for Maximum; cast explicitly to avoid strict-mode issues
    [double]$maxLen  = [double]($FrequencyTable | ForEach-Object { [string]$_.ErrorType } | Measure-Object -Property Length -Maximum).Maximum
    [int]$typeWidth  = [Math]::Max(30, [int]$maxLen + 2)
    [int]$levelWidth = 10
    [int]$countWidth = 8
    [int]$dateWidth  = 22

    # Build header
    [string]$header = (
        'ErrorType'.PadRight($typeWidth) +
        'Level'.PadRight($levelWidth) +
        'Count'.PadRight($countWidth) +
        'FirstSeen'.PadRight($dateWidth) +
        'LastSeen'.PadRight($dateWidth)
    )

    [int]$totalWidth = $typeWidth + $levelWidth + $countWidth + $dateWidth + $dateWidth
    [string]$separator = '-' * $totalWidth

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('=== Log Analysis: Error and Warning Frequency Table ===')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine($header)
    [void]$sb.AppendLine($separator)

    foreach ($row in $FrequencyTable) {
        [string]$dateFormat = 'yyyy-MM-dd HH:mm:ss'
        [string]$line = (
            ([string]$row.ErrorType).PadRight($typeWidth) +
            ([string]$row.Level).PadRight($levelWidth) +
            ([string][int]$row.Count).PadRight($countWidth) +
            ([datetime]$row.FirstSeen).ToString($dateFormat).PadRight($dateWidth) +
            ([datetime]$row.LastSeen).ToString($dateFormat).PadRight($dateWidth)
        )
        [void]$sb.AppendLine($line)
    }

    [void]$sb.AppendLine($separator)
    [void]$sb.AppendLine("Total unique error/warning types: $([int]$FrequencyTable.Count)")

    # Compute totals split by ERROR vs WARN
    # Measure-Object -Sum returns nullable; use -as [int] to safely coerce $null -> 0
    $errorSumResult  = ($FrequencyTable | Where-Object { [string]$_.Level -in @('ERROR','CRITICAL') } | Measure-Object -Property Count -Sum).Sum
    $warnSumResult   = ($FrequencyTable | Where-Object { [string]$_.Level -in @('WARN','WARNING') }   | Measure-Object -Property Count -Sum).Sum
    [int]$errorTotal = if ($null -eq $errorSumResult) { 0 } else { [int]$errorSumResult }
    [int]$warnTotal  = if ($null -eq $warnSumResult)  { 0 } else { [int]$warnSumResult  }
    [void]$sb.AppendLine("Total occurrences  — ERROR|WARN: $errorTotal | $warnTotal")

    return $sb.ToString()
}

# ---------------------------------------------------------------------------
# Export-AnalysisJson
# Writes the frequency table to a JSON file, including metadata.
# ---------------------------------------------------------------------------
function Export-AnalysisJson {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [PSCustomObject[]]$FrequencyTable,
        [string]$OutputPath
    )

    # Convert datetime fields to ISO 8601 strings for JSON serialization
    [System.Collections.Generic.List[PSCustomObject]]$serializable = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($row in $FrequencyTable) {
        $serializable.Add([PSCustomObject]@{
            errorType  = [string]$row.ErrorType
            level      = [string]$row.Level
            count      = [int]$row.Count
            firstSeen  = ([datetime]$row.FirstSeen).ToString('o')   # ISO 8601 round-trip
            lastSeen   = ([datetime]$row.LastSeen).ToString('o')
        })
    }

    # Aggregate summary stats — guard against $null from Measure-Object when no matches
    $errSum             = ($FrequencyTable | Where-Object { [string]$_.Level -in @('ERROR','CRITICAL') } | Measure-Object -Property Count -Sum).Sum
    $warnSum            = ($FrequencyTable | Where-Object { [string]$_.Level -in @('WARN','WARNING') }   | Measure-Object -Property Count -Sum).Sum
    [int]$totalErrors   = if ($null -eq $errSum)  { 0 } else { [int]$errSum  }
    [int]$totalWarnings = if ($null -eq $warnSum) { 0 } else { [int]$warnSum }

    $output = [PSCustomObject]@{
        generatedAt  = [datetime]::UtcNow.ToString('o')
        summary      = [PSCustomObject]@{
            uniqueErrorTypes = [int]$FrequencyTable.Count
            totalErrors      = $totalErrors
            totalWarnings    = $totalWarnings
            totalOccurrences = $totalErrors + $totalWarnings
        }
        entries      = $serializable.ToArray()
    }

    $jsonContent = $output | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath $OutputPath -Value $jsonContent -Encoding UTF8
}

# ---------------------------------------------------------------------------
# Invoke-LogAnalysis
# Main orchestration function: parses the log, builds frequency table,
# renders the human-readable report, and writes the JSON output file.
# Returns the human-readable report as a string.
# ---------------------------------------------------------------------------
function Invoke-LogAnalysis {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$LogPath,
        [string]$JsonOutputPath
    )

    # Parse will throw if file not found — let it propagate with its message
    [PSCustomObject[]]$entries = Get-LogEntries -LogPath $LogPath

    [PSCustomObject[]]$frequencyTable = Get-ErrorFrequencyTable -Entries $entries

    [string]$report = Format-FrequencyTable -FrequencyTable $frequencyTable

    Export-AnalysisJson -FrequencyTable $frequencyTable -OutputPath $JsonOutputPath

    return $report
}

# Export all public functions
Export-ModuleMember -Function @(
    'Parse-SyslogLine'
    'Parse-JsonLogLine'
    'Get-LogEntries'
    'Get-ErrorFrequencyTable'
    'Format-FrequencyTable'
    'Export-AnalysisJson'
    'Invoke-LogAnalysis'
)
