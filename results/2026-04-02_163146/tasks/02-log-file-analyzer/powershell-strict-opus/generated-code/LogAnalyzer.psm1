Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# LogAnalyzer module
# Parses mixed-format log files (syslog + JSON), extracts errors/warnings,
# builds a frequency table, and outputs as human-readable table + JSON.

# Regex for syslog-style lines:
# Format: YYYY-MM-DD HH:MM:SS hostname source[pid]: LEVEL: message
# or:     YYYY-MM-DD HH:MM:SS hostname source: LEVEL: message
[string]$script:SyslogPattern = '^\s*(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(\S+)\s+(\S+?)(?:\[\d+\])?:\s+(\w+):\s+(.*)\s*$'

function ConvertFrom-LogLine {
    <#
    .SYNOPSIS
        Parses a single log line into a structured object.
    .DESCRIPTION
        Detects whether the line is JSON or syslog format, then extracts
        timestamp, level, source, message, host, and format.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Line
    )

    # Skip empty/whitespace lines
    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $null
    }

    [string]$trimmed = $Line.Trim()

    # Try JSON format first (lines starting with '{')
    if ($trimmed.StartsWith('{')) {
        try {
            $json = $trimmed | ConvertFrom-Json
            [datetime]$ts = [datetime]::Parse([string]$json.timestamp)
            [string]$level = [string]$json.level
            [string]$source = [string]$json.service
            [string]$message = [string]$json.message
            [string]$hostName = [string]$json.host

            return [PSCustomObject]@{
                Timestamp = $ts
                Level     = $level
                Source    = $source
                Message   = $message
                Host      = $hostName
                Format    = [string]'json'
            }
        }
        catch {
            # If JSON parsing fails, fall through to unknown
        }
    }

    # Try syslog format
    if ($trimmed -match $script:SyslogPattern) {
        [datetime]$ts = [datetime]::Parse($Matches[1])
        [string]$hostName = $Matches[2]
        [string]$source = $Matches[3]
        [string]$level = $Matches[4]
        [string]$message = $Matches[5]

        return [PSCustomObject]@{
            Timestamp = $ts
            Level     = $level
            Source    = $source
            Message   = $message
            Host      = $hostName
            Format    = [string]'syslog'
        }
    }

    # Unrecognized format — return with UNKNOWN level so callers can decide
    return [PSCustomObject]@{
        Timestamp = [datetime]::MinValue
        Level     = [string]'UNKNOWN'
        Source    = [string]''
        Message   = $trimmed
        Host      = [string]''
        Format    = [string]'unknown'
    }
}

function Read-LogFile {
    <#
    .SYNOPSIS
        Reads a log file and parses each line into structured log entries.
    .DESCRIPTION
        Opens the file at the given path, parses each non-empty line using
        ConvertFrom-LogLine, and returns an array of parsed entries.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Log file not found: $Path"
    }

    [string[]]$lines = Get-Content -LiteralPath $Path

    foreach ($line in $lines) {
        $entry = ConvertFrom-LogLine -Line $line
        if ($null -ne $entry) {
            Write-Output $entry
        }
    }
}

function Select-ErrorAndWarning {
    <#
    .SYNOPSIS
        Filters log entries to only ERROR and WARNING levels.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Entries
    )

    foreach ($entry in $Entries) {
        if ($entry.Level -eq 'ERROR' -or $entry.Level -eq 'WARNING') {
            Write-Output $entry
        }
    }
}

function Get-ErrorFrequencyTable {
    <#
    .SYNOPSIS
        Groups error/warning entries by message and computes occurrence counts
        with first and last timestamps.
    .DESCRIPTION
        Returns an array of objects sorted by count descending. Each object
        contains Level, Message, Count, FirstOccurrence, LastOccurrence.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Entries
    )

    if ($Entries.Count -eq 0) {
        return @()
    }

    # Group by message text (combining level to distinguish ERROR vs WARNING with same text)
    [hashtable]$groups = @{}

    foreach ($entry in $Entries) {
        # Key on level + message to keep ERROR and WARNING separate
        [string]$key = "$($entry.Level):::$($entry.Message)"

        if ($groups.ContainsKey($key)) {
            [hashtable]$g = [hashtable]$groups[$key]
            $g['Count'] = [int]$g['Count'] + 1

            if ($entry.Timestamp -lt [datetime]$g['FirstOccurrence']) {
                $g['FirstOccurrence'] = $entry.Timestamp
            }
            if ($entry.Timestamp -gt [datetime]$g['LastOccurrence']) {
                $g['LastOccurrence'] = $entry.Timestamp
            }
        }
        else {
            $groups[$key] = @{
                Level           = [string]$entry.Level
                Message         = [string]$entry.Message
                Count           = [int]1
                FirstOccurrence = [datetime]$entry.Timestamp
                LastOccurrence  = [datetime]$entry.Timestamp
            }
        }
    }

    # Convert to objects and sort by count descending
    [PSCustomObject[]]$result = $groups.Values | ForEach-Object {
        [PSCustomObject]@{
            Level           = [string]$_['Level']
            Message         = [string]$_['Message']
            Count           = [int]$_['Count']
            FirstOccurrence = [datetime]$_['FirstOccurrence']
            LastOccurrence  = [datetime]$_['LastOccurrence']
        }
    } | Sort-Object -Property Count -Descending

    return $result
}

function Format-AnalysisTable {
    <#
    .SYNOPSIS
        Formats frequency table data as a human-readable text table.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$FrequencyTable
    )

    if ($FrequencyTable.Count -eq 0) {
        return 'No error or warning entries found.'
    }

    [string]$timestampFormat = 'yyyy-MM-dd HH:mm:ss'

    # Calculate column widths dynamically
    [int]$levelWidth = [Math]::Max(5, ($FrequencyTable | ForEach-Object { $_.Level.Length } | Measure-Object -Maximum).Maximum)
    [int]$messageWidth = [Math]::Max(7, [Math]::Min(60, ($FrequencyTable | ForEach-Object { $_.Message.Length } | Measure-Object -Maximum).Maximum))
    [int]$countWidth = 5
    [int]$tsWidth = 19  # yyyy-MM-dd HH:mm:ss

    # Build header
    [string]$header = '{0}  {1}  {2}  {3}  {4}' -f (
        'Level'.PadRight($levelWidth),
        'Message'.PadRight($messageWidth),
        'Count'.PadLeft($countWidth),
        'First Occurrence'.PadRight($tsWidth),
        'Last Occurrence'.PadRight($tsWidth)
    )

    [int]$totalWidth = $header.Length
    [string]$separator = '-' * $totalWidth

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('=== Log Analysis: Error/Warning Frequency Table ===')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine($header)
    [void]$sb.AppendLine($separator)

    foreach ($row in $FrequencyTable) {
        # Truncate message if too long
        [string]$msg = $row.Message
        if ($msg.Length -gt $messageWidth) {
            $msg = $msg.Substring(0, $messageWidth - 3) + '...'
        }

        [string]$line = '{0}  {1}  {2}  {3}  {4}' -f (
            $row.Level.PadRight($levelWidth),
            $msg.PadRight($messageWidth),
            ([string]$row.Count).PadLeft($countWidth),
            $row.FirstOccurrence.ToString($timestampFormat).PadRight($tsWidth),
            $row.LastOccurrence.ToString($timestampFormat).PadRight($tsWidth)
        )
        [void]$sb.AppendLine($line)
    }

    [void]$sb.AppendLine($separator)
    [int]$totalOccurrences = ($FrequencyTable | Measure-Object -Property Count -Sum).Sum
    [void]$sb.AppendLine("Total unique issues: $($FrequencyTable.Count)  |  Total occurrences: $totalOccurrences")
    [void]$sb.AppendLine('')

    return $sb.ToString()
}

function Export-AnalysisJson {
    <#
    .SYNOPSIS
        Exports the frequency table as a JSON file with summary metadata.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$FrequencyTable,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    [string]$timestampFormat = 'yyyy-MM-dd HH:mm:ss'
    [int]$totalOccurrences = 0
    if ($FrequencyTable.Count -gt 0) {
        $totalOccurrences = [int]($FrequencyTable | Measure-Object -Property Count -Sum).Sum
    }

    # Build entries array with string timestamps for clean JSON
    [object[]]$entries = @()
    foreach ($row in $FrequencyTable) {
        $entries += [PSCustomObject]@{
            level            = [string]$row.Level
            message          = [string]$row.Message
            count            = [int]$row.Count
            first_occurrence = [string]$row.FirstOccurrence.ToString($timestampFormat)
            last_occurrence  = [string]$row.LastOccurrence.ToString($timestampFormat)
        }
    }

    $output = [PSCustomObject]@{
        summary = [PSCustomObject]@{
            generated_at        = [string](Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
            total_unique_issues = [int]$FrequencyTable.Count
            total_occurrences   = [int]$totalOccurrences
        }
        entries = $entries
    }

    [string]$json = $output | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath $OutputPath -Value $json -Encoding UTF8
}

function Invoke-LogAnalysis {
    <#
    .SYNOPSIS
        Main entry point: analyzes a log file, produces human-readable table
        and JSON output.
    .DESCRIPTION
        Reads the log file, filters errors/warnings, builds frequency table,
        formats a text table, and exports to JSON. Returns the text table.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$JsonOutputPath
    )

    # Read and parse all log entries
    [PSCustomObject[]]$allEntries = @(Read-LogFile -Path $Path)

    # Filter to errors and warnings only
    [PSCustomObject[]]$filtered = @(Select-ErrorAndWarning -Entries $allEntries)

    # Build frequency table
    [PSCustomObject[]]$frequencyTable = @(Get-ErrorFrequencyTable -Entries $filtered)

    # Format human-readable output
    [string]$tableOutput = Format-AnalysisTable -FrequencyTable $frequencyTable

    # Export JSON
    Export-AnalysisJson -FrequencyTable $frequencyTable -OutputPath $JsonOutputPath

    return $tableOutput
}

# Export all public functions
Export-ModuleMember -Function @(
    'ConvertFrom-LogLine'
    'Read-LogFile'
    'Select-ErrorAndWarning'
    'Get-ErrorFrequencyTable'
    'Format-AnalysisTable'
    'Export-AnalysisJson'
    'Invoke-LogAnalysis'
)
