Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Log Analyzer — parses mixed-format log files (syslog + JSON),
# extracts errors/warnings, builds a frequency table, and outputs
# results as both a human-readable table and a JSON file.

function ConvertFrom-SyslogLine {
    <#
    .SYNOPSIS
        Parses a syslog-style log line into a structured object.
    .DESCRIPTION
        Expects format: YYYY-MM-DD HH:MM:SS LEVEL [source] message
        Returns $null if the line does not match.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Line
    )

    # Regex: timestamp, level (with optional trailing spaces), bracketed source, message
    [string]$pattern = '^\s*(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(INFO|WARN|ERROR|DEBUG|TRACE)\s+\[([^\]]+)\]\s*(.*)\s*$'
    [System.Text.RegularExpressions.Match]$m = [regex]::Match($Line, $pattern)

    if (-not $m.Success) {
        return $null
    }

    return [PSCustomObject]@{
        Timestamp = [string]$m.Groups[1].Value
        Level     = [string]$m.Groups[2].Value
        Source    = [string]$m.Groups[3].Value
        Message   = [string]$m.Groups[4].Value
    }
}

function ConvertFrom-JsonLogLine {
    <#
    .SYNOPSIS
        Parses a JSON-structured log line into a structured object.
    .DESCRIPTION
        Expects a JSON object with at least "timestamp", "level", and "message" keys.
        The "service" key is mapped to Source. WARNING is normalized to WARN.
        Returns $null if the line is not valid JSON or lacks required keys.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Line
    )

    # Quick guard: JSON lines must start with '{'
    if (-not $Line.TrimStart().StartsWith('{')) {
        return $null
    }

    try {
        [PSCustomObject]$obj = $Line | ConvertFrom-Json
    }
    catch {
        return $null
    }

    # Require minimum fields
    if (-not ($obj.PSObject.Properties.Name -contains 'timestamp' -and
              $obj.PSObject.Properties.Name -contains 'level' -and
              $obj.PSObject.Properties.Name -contains 'message')) {
        return $null
    }

    # Normalize WARNING -> WARN for consistency with syslog
    [string]$level = [string]$obj.level
    if ($level -eq 'WARNING') {
        $level = 'WARN'
    }

    # Use "service" as the source if present, otherwise "unknown"
    [string]$source = if ($obj.PSObject.Properties.Name -contains 'service') {
        [string]$obj.service
    } else {
        'unknown'
    }

    # Preserve the raw timestamp string — ConvertFrom-Json may auto-parse it
    # to DateTime, so we extract from the original JSON text instead.
    [string]$rawTimestamp = ''
    [System.Text.RegularExpressions.Match]$tsMatch = [regex]::Match($Line, '"timestamp"\s*:\s*"([^"]+)"')
    if ($tsMatch.Success) {
        $rawTimestamp = [string]$tsMatch.Groups[1].Value
    }
    else {
        $rawTimestamp = [string]$obj.timestamp
    }

    return [PSCustomObject]@{
        Timestamp = $rawTimestamp
        Level     = $level
        Source    = $source
        Message   = [string]$obj.message
    }
}

function Read-LogFile {
    <#
    .SYNOPSIS
        Reads a log file and returns parsed entries from all recognized lines.
    .DESCRIPTION
        Tries JSON parsing first (fast check for leading '{'), then syslog.
        Lines that match neither format are silently skipped.
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

    [System.Collections.Generic.List[PSCustomObject]]$entries = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        # Try JSON first (cheaper guard: starts with '{')
        [PSCustomObject]$entry = ConvertFrom-JsonLogLine -Line $line
        if ($null -eq $entry) {
            $entry = ConvertFrom-SyslogLine -Line $line
        }

        if ($null -ne $entry) {
            $entries.Add($entry)
        }
    }

    return [PSCustomObject[]]$entries.ToArray()
}

function Get-ErrorAndWarningEntries {
    <#
    .SYNOPSIS
        Filters log entries to only ERROR and WARN levels.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Entries
    )

    [System.Collections.Generic.List[PSCustomObject]]$filtered = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($e in $Entries) {
        if ($e.Level -eq 'ERROR' -or $e.Level -eq 'WARN') {
            $filtered.Add($e)
        }
    }
    return [PSCustomObject[]]$filtered.ToArray()
}

function Get-FrequencyTable {
    <#
    .SYNOPSIS
        Groups error/warning entries by type and computes frequency stats.
    .DESCRIPTION
        The "error type" key is "LEVEL [Source] Message". Each group gets
        a count, first-seen timestamp, and last-seen timestamp.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Entries
    )

    # Build a key from level + source + message for grouping
    [System.Collections.Generic.Dictionary[string, PSCustomObject]]$groups =
        [System.Collections.Generic.Dictionary[string, PSCustomObject]]::new()

    foreach ($entry in $Entries) {
        [string]$key = "$($entry.Level) [$($entry.Source)] $($entry.Message)"

        if ($groups.ContainsKey($key)) {
            [PSCustomObject]$existing = $groups[$key]
            $existing.Count = [int]$existing.Count + 1

            # Track earliest and latest timestamps (string comparison works for ISO-ish formats)
            if ([string]$entry.Timestamp -lt [string]$existing.FirstSeen) {
                $existing.FirstSeen = [string]$entry.Timestamp
            }
            if ([string]$entry.Timestamp -gt [string]$existing.LastSeen) {
                $existing.LastSeen = [string]$entry.Timestamp
            }
        }
        else {
            $groups[$key] = [PSCustomObject]@{
                ErrorType = [string]$key
                Count     = [int]1
                FirstSeen = [string]$entry.Timestamp
                LastSeen  = [string]$entry.Timestamp
            }
        }
    }

    # Return sorted by count descending
    [PSCustomObject[]]$result = @($groups.Values | Sort-Object -Property Count -Descending)
    return $result
}

function Format-FrequencyTable {
    <#
    .SYNOPSIS
        Formats frequency table data as a human-readable text table.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$TableData
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    # Header
    [string]$header = '{0,-60} {1,6} {2,-24} {3,-24}' -f 'Error Type', 'Count', 'First Seen', 'Last Seen'
    [void]$sb.AppendLine($header)
    [void]$sb.AppendLine([string]::new('-', $header.Length))

    foreach ($row in $TableData) {
        [string]$rowText = '{0,-60} {1,6} {2,-24} {3,-24}' -f `
            ([string]$row.ErrorType).Substring(0, [Math]::Min(60, ([string]$row.ErrorType).Length)),
            [int]$row.Count,
            [string]$row.FirstSeen,
            [string]$row.LastSeen
        [void]$sb.AppendLine($rowText)
    }

    return [string]$sb.ToString()
}

function Export-FrequencyTableJson {
    <#
    .SYNOPSIS
        Exports frequency table data to a JSON file.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$TableData,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    # Wrap in @() to ensure a JSON array even for a single element
    [string]$json = ConvertTo-Json -InputObject @($TableData) -Depth 5
    Set-Content -LiteralPath $OutputPath -Value $json -Encoding UTF8
}

function Invoke-LogAnalysis {
    <#
    .SYNOPSIS
        End-to-end log analysis: parse, filter, tabulate, and output.
    .DESCRIPTION
        Reads a log file, extracts errors and warnings, builds a frequency
        table, writes a JSON report, and returns the human-readable table.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$LogPath,

        [Parameter(Mandatory)]
        [string]$JsonOutputPath
    )

    # 1. Parse all log entries
    [PSCustomObject[]]$allEntries = Read-LogFile -Path $LogPath

    # 2. Filter to errors and warnings
    [PSCustomObject[]]$issues = Get-ErrorAndWarningEntries -Entries $allEntries

    if ($issues.Count -eq 0) {
        [string]$msg = 'No errors or warnings found in the log file.'
        Export-FrequencyTableJson -TableData @() -OutputPath $JsonOutputPath
        return $msg
    }

    # 3. Build frequency table
    [PSCustomObject[]]$freqTable = Get-FrequencyTable -Entries $issues

    # 4. Export JSON
    Export-FrequencyTableJson -TableData $freqTable -OutputPath $JsonOutputPath

    # 5. Return human-readable table
    [string]$tableText = Format-FrequencyTable -TableData $freqTable
    return $tableText
}
