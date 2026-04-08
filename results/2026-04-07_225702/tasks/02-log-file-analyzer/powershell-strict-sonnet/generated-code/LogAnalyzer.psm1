# LogAnalyzer.psm1
# Module for parsing mixed-format log files, extracting errors/warnings,
# and producing frequency tables with first/last occurrence timestamps.
#
# Strict mode requirements:
#   - Set-StrictMode -Version Latest
#   - $ErrorActionPreference = 'Stop'
#   - All parameters explicitly typed
#   - [OutputType()] on every function
#   - [CmdletBinding()] on every function
#   - No implicit type conversions

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Internal helper: PSCustomObject factory for a log entry
# ---------------------------------------------------------------------------
function New-LogEntry {
    <#
    .SYNOPSIS
        Creates a strongly-shaped log entry object.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [string]   $Level,
        [string]   $Message,
        [datetime] $Timestamp,
        [string]   $Source,
        [string]   $Format
    )
    [PSCustomObject]@{
        Level     = $Level
        Message   = $Message
        Timestamp = $Timestamp
        Source    = $Source
        Format    = $Format
    }
}

# ---------------------------------------------------------------------------
# ConvertFrom-SyslogLine
#   Parses a single syslog-style line.
#   Format: "Mon DD HH:MM:SS hostname process[pid]: LEVEL message"
#   Returns a log-entry PSCustomObject, or $null if the line does not match.
# ---------------------------------------------------------------------------
function ConvertFrom-SyslogLine {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [string] $Line
    )

    # Regex captures: month, day, time, host, process name (no pid), level, message
    $pattern = '^(?<Month>\w{3})\s+(?<Day>\d{1,2})\s+(?<Time>\d{2}:\d{2}:\d{2})\s+(?<Host>\S+)\s+(?<Proc>[^\[:\s]+)(?:\[\d+\])?:\s+(?<Level>ERROR|WARNING|WARN|INFO|DEBUG|NOTICE|CRITICAL)\s+(?<Msg>.+)$'

    if ($Line -match $pattern) {
        # Build a parseable timestamp string; use current year as syslog omits it
        [string] $year      = [string][datetime]::Now.Year
        [string] $tsString  = "$($Matches['Month']) $($Matches['Day']) $year $($Matches['Time'])"
        [datetime] $ts      = [datetime]::Parse($tsString)

        # Normalise WARN -> WARNING for consistency
        [string] $level = $Matches['Level']
        if ($level -eq 'WARN') { $level = 'WARNING' }

        New-LogEntry -Level $level -Message $Matches['Msg'] -Timestamp $ts `
                     -Source $Matches['Proc'] -Format 'syslog'
    }
    else {
        $null
    }
}

# ---------------------------------------------------------------------------
# ConvertFrom-JsonLogLine
#   Parses a single JSON-structured log line.
#   Expected fields: timestamp, level, message, source
#   Returns a log-entry PSCustomObject, or $null on failure.
# ---------------------------------------------------------------------------
function ConvertFrom-JsonLogLine {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [string] $Line
    )

    # Quick guard: must look like JSON
    [string] $trimmed = $Line.Trim()
    if (-not ($trimmed.StartsWith('{') -and $trimmed.EndsWith('}'))) {
        return $null
    }

    try {
        $obj = $trimmed | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return $null
    }

    # Validate required fields exist
    if ($null -eq $obj.timestamp -or $null -eq $obj.level -or $null -eq $obj.message) {
        return $null
    }

    [datetime] $ts = [datetime]::Parse([string]$obj.timestamp)

    [string] $level = ([string]$obj.level).ToUpper()
    if ($level -eq 'WARN') { $level = 'WARNING' }

    [string] $source = if ($null -ne $obj.source) { [string]$obj.source } else { 'unknown' }

    New-LogEntry -Level $level -Message ([string]$obj.message) -Timestamp $ts `
                 -Source $source -Format 'json'
}

# ---------------------------------------------------------------------------
# Read-LogFile
#   Reads a mixed-format log file and returns all successfully parsed entries.
#   Lines that cannot be parsed as syslog or JSON are silently skipped.
#   Throws a terminating error if the file does not exist.
# ---------------------------------------------------------------------------
function Read-LogFile {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [string] $Path
    )

    if (-not (Test-Path $Path)) {
        throw "Log file not found: '$Path'"
    }

    [PSCustomObject[]] $entries = @()

    foreach ($line in (Get-Content -Path $Path)) {
        [string] $trimmedLine = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmedLine)) { continue }

        # Try JSON first (starts with '{'), then syslog
        [PSCustomObject] $entry = $null
        if ($trimmedLine.StartsWith('{')) {
            $entry = ConvertFrom-JsonLogLine -Line $trimmedLine
        }
        else {
            $entry = ConvertFrom-SyslogLine -Line $trimmedLine
        }

        if ($null -ne $entry) {
            $entries += $entry
        }
    }

    $entries
}

# ---------------------------------------------------------------------------
# Select-ErrorsAndWarnings
#   Filters a collection of log entries to only ERROR and WARNING levels.
# ---------------------------------------------------------------------------
function Select-ErrorsAndWarnings {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [PSCustomObject[]] $Entries
    )

    [PSCustomObject[]] $filtered = @($Entries | Where-Object { $_.Level -in @('ERROR', 'WARNING') })
    $filtered
}

# ---------------------------------------------------------------------------
# Get-ErrorFrequencyTable
#   Groups filtered entries by Level+Message and computes:
#     - Count           : number of occurrences
#     - FirstSeen       : earliest timestamp
#     - LastSeen        : latest timestamp
# ---------------------------------------------------------------------------
function Get-ErrorFrequencyTable {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [PSCustomObject[]] $Entries
    )

    # Group by composite key "LEVEL|Message"
    $groups = $Entries | Group-Object -Property { "$($_.Level)|$($_.Message)" }

    [PSCustomObject[]] $table = foreach ($g in $groups) {
        [datetime[]] $timestamps = @($g.Group | Select-Object -ExpandProperty Timestamp)
        [datetime]   $first      = $timestamps | Sort-Object | Select-Object -First 1
        [datetime]   $last       = $timestamps | Sort-Object | Select-Object -Last  1
        [string]     $lvl        = [string]($g.Group | Select-Object -First 1 -ExpandProperty Level)
        [string]     $msg        = [string]($g.Group | Select-Object -First 1 -ExpandProperty Message)

        [PSCustomObject]@{
            Level     = $lvl
            Message   = $msg
            Count     = [int]$g.Count
            FirstSeen = $first
            LastSeen  = $last
        }
    }

    # Sort by Count descending so the most frequent errors appear first
    @($table | Sort-Object -Property Count -Descending)
}

# ---------------------------------------------------------------------------
# Export-AnalysisJson
#   Serialises the frequency table to a JSON file.
# ---------------------------------------------------------------------------
function Export-AnalysisJson {
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [PSCustomObject[]] $FrequencyTable,
        [string]           $Path
    )

    # Convert datetime fields to ISO 8601 strings for portable JSON
    [object[]] $serialisable = foreach ($row in $FrequencyTable) {
        [PSCustomObject]@{
            Level     = $row.Level
            Message   = $row.Message
            Count     = $row.Count
            FirstSeen = $row.FirstSeen.ToString('o')   # ISO 8601 round-trip format
            LastSeen  = $row.LastSeen.ToString('o')
        }
    }

    $serialisable | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
}

# ---------------------------------------------------------------------------
# Format-AnalysisTable
#   Returns a human-readable plain-text table of the frequency table.
# ---------------------------------------------------------------------------
function Format-AnalysisTable {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [PSCustomObject[]] $FrequencyTable
    )

    # Column widths — compute dynamically from data
    [int] $levelWidth   = [math]::Max(7,  ($FrequencyTable | ForEach-Object { $_.Level.Length }   | Measure-Object -Maximum).Maximum)
    [int] $countWidth   = [math]::Max(5,  ($FrequencyTable | ForEach-Object { ([string]$_.Count).Length } | Measure-Object -Maximum).Maximum)
    [int] $msgWidth     = [math]::Max(40, ($FrequencyTable | ForEach-Object { $_.Message.Length }  | Measure-Object -Maximum).Maximum)
    [int] $tsWidth      = 19  # "yyyy-MM-dd HH:mm:ss"

    [string] $fmt       = "{0,-$levelWidth}  {1,$countWidth}  {2,-$msgWidth}  {3,-$tsWidth}  {4,-$tsWidth}"
    [string] $separator = '-' * ($levelWidth + $countWidth + $msgWidth + $tsWidth * 2 + 8)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add($separator)
    $lines.Add(($fmt -f 'Level', 'Count', 'Message', 'First Seen', 'Last Seen'))
    $lines.Add($separator)

    foreach ($row in $FrequencyTable) {
        [string] $firstStr = $row.FirstSeen.ToString('yyyy-MM-dd HH:mm:ss')
        [string] $lastStr  = $row.LastSeen.ToString('yyyy-MM-dd HH:mm:ss')
        $lines.Add(($fmt -f $row.Level, $row.Count, $row.Message, $firstStr, $lastStr))
    }

    $lines.Add($separator)
    $lines -join "`n"
}

# ---------------------------------------------------------------------------
# New-SampleLogFile
#   Creates a sample log fixture file containing both syslog and JSON lines
#   covering ERROR, WARNING, and INFO levels.
# ---------------------------------------------------------------------------
function New-SampleLogFile {
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [string] $Path
    )

    $content = @(
        '# Sample mixed-format log file generated by New-SampleLogFile'
        ''
        '# --- Syslog-style entries ---'
        'Jan 15 08:00:01 webserver nginx[1001]: INFO Service started'
        'Jan 15 08:01:10 webserver nginx[1001]: WARNING Worker pool nearly exhausted (90%)'
        'Jan 15 08:02:22 webserver nginx[1001]: ERROR Failed to bind to port 443: permission denied'
        'Jan 15 08:05:00 dbserver postgres[2002]: INFO Database ready'
        'Jan 15 08:10:15 dbserver postgres[2002]: ERROR Connection pool exhausted'
        'Jan 15 08:15:30 dbserver postgres[2002]: WARNING Slow query detected (5200ms)'
        'Jan 15 08:20:45 appserver app[3003]: ERROR Unhandled exception in request handler'
        'Jan 15 08:25:00 appserver app[3003]: WARNING Memory usage above threshold (82%)'
        'Jan 15 08:30:10 appserver app[3003]: ERROR Connection pool exhausted'
        'Jan 15 08:35:20 webserver nginx[1001]: WARNING Worker pool nearly exhausted (90%)'
        'Jan 15 08:40:00 dbserver postgres[2002]: ERROR Connection pool exhausted'
        ''
        '# --- JSON-structured entries ---'
        '{"timestamp":"2024-01-15T09:00:00Z","level":"INFO","message":"Scheduler started","source":"scheduler"}'
        '{"timestamp":"2024-01-15T09:05:00Z","level":"WARN","message":"Job queue backed up","source":"scheduler"}'
        '{"timestamp":"2024-01-15T09:10:00Z","level":"ERROR","message":"Failed to bind to port 443: permission denied","source":"nginx"}'
        '{"timestamp":"2024-01-15T09:15:00Z","level":"ERROR","message":"Unhandled exception in request handler","source":"app"}'
        '{"timestamp":"2024-01-15T09:20:00Z","level":"WARN","message":"Job queue backed up","source":"scheduler"}'
        '{"timestamp":"2024-01-15T09:25:00Z","level":"ERROR","message":"Disk I/O error on /dev/sda1","source":"kernel"}'
        '{"timestamp":"2024-01-15T09:30:00Z","level":"INFO","message":"Backup completed successfully","source":"backup"}'
        '{"timestamp":"2024-01-15T09:35:00Z","level":"ERROR","message":"Disk I/O error on /dev/sda1","source":"kernel"}'
        '{"timestamp":"2024-01-15T09:40:00Z","level":"WARN","message":"Certificate expires in 14 days","source":"tls"}'
        ''
        '# Unrecognised line that should be silently ignored'
        'this line has no recognised log format'
    )

    Set-Content -Path $Path -Value $content -Encoding UTF8
}

# ---------------------------------------------------------------------------
# Invoke-LogAnalysis
#   Top-level orchestration function: read → filter → frequency table →
#   output JSON and human-readable table to console.
# ---------------------------------------------------------------------------
function Invoke-LogAnalysis {
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [string] $LogPath,
        [string] $OutputPath
    )

    Write-Verbose "Reading log file: $LogPath"
    [PSCustomObject[]] $allEntries = Read-LogFile -Path $LogPath

    Write-Verbose "Total parsed entries: $($allEntries.Count)"
    [PSCustomObject[]] $filtered = Select-ErrorsAndWarnings -Entries $allEntries

    Write-Verbose "Errors/warnings found: $($filtered.Count)"
    [PSCustomObject[]] $table = Get-ErrorFrequencyTable -Entries $filtered

    # Write JSON output
    [string] $outputDir = [System.IO.Path]::GetDirectoryName($OutputPath)
    if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir | Out-Null
    }
    Export-AnalysisJson -FrequencyTable $table -Path $OutputPath
    Write-Verbose "JSON analysis written to: $OutputPath"

    # Print human-readable table to console
    [string] $textTable = Format-AnalysisTable -FrequencyTable $table
    Write-Output "`nLog Analysis Report"
    Write-Output "==================="
    Write-Output $textTable
}

# ---------------------------------------------------------------------------
# Export public surface
# ---------------------------------------------------------------------------
Export-ModuleMember -Function @(
    'ConvertFrom-SyslogLine'
    'ConvertFrom-JsonLogLine'
    'Read-LogFile'
    'Select-ErrorsAndWarnings'
    'Get-ErrorFrequencyTable'
    'Export-AnalysisJson'
    'Format-AnalysisTable'
    'New-SampleLogFile'
    'Invoke-LogAnalysis'
)
