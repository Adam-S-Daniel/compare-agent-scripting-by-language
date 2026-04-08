# LogAnalyzer.ps1 - Parses mixed-format log files (syslog + JSON),
# extracts errors/warnings, builds a frequency table, and outputs
# both a human-readable table and JSON summary.

function Parse-LogLine {
    # Parses a single log line, handling both syslog-style and JSON formats.
    # Returns a PSCustomObject with Timestamp, Level, Source, Message — or $null if unparseable.
    param(
        [string]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Line)) { return $null }

    # Try JSON first — lines starting with '{' are JSON-structured
    if ($Line.TrimStart().StartsWith('{')) {
        try {
            # Extract the raw timestamp string before ConvertFrom-Json converts it
            $rawTimestamp = $null
            if ($Line -match '"timestamp"\s*:\s*"([^"]+)"') {
                $rawTimestamp = $Matches[1]
            }
            $json = $Line | ConvertFrom-Json -AsHashtable
            return [PSCustomObject]@{
                Timestamp = if ($rawTimestamp) { $rawTimestamp } else { [string]$json['timestamp'] }
                Level     = [string]$json['level']
                Source    = [string]$json['service']
                Message   = [string]$json['message']
            }
        } catch {
            return $null
        }
    }

    # Try syslog format: "YYYY-MM-DD HH:MM:SS LEVEL [Source] Message"
    if ($Line -match '^\s*(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(ERROR|WARNING|INFO|DEBUG)\s+\[([^\]]+)\]\s+(.+)$') {
        return [PSCustomObject]@{
            Timestamp = $Matches[1]
            Level     = $Matches[2]
            Source    = $Matches[3]
            Message   = $Matches[4]
        }
    }

    return $null
}

function Get-LogEntries {
    # Reads a log file and returns an array of parsed log entry objects.
    # Skips lines that cannot be parsed. Throws on missing file.
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Log file '$Path' does not exist."
    }

    $entries = @()
    foreach ($line in Get-Content -Path $Path) {
        $parsed = Parse-LogLine $line
        if ($null -ne $parsed) {
            $entries += $parsed
        }
    }
    return $entries
}

function Select-ErrorsAndWarnings {
    # Filters parsed log entries to only ERROR and WARNING levels.
    param(
        [Parameter(Mandatory)]
        [array]$Entries
    )

    $filtered = @($Entries | Where-Object { $_.Level -in @('ERROR', 'WARNING') })
    return $filtered
}

function Get-FrequencyTable {
    # Groups error/warning entries by source+message, counts occurrences,
    # and tracks first/last timestamps. Returns sorted by count descending.
    param(
        [Parameter(Mandatory)]
        [array]$Entries
    )

    $groups = @{}
    foreach ($entry in $Entries) {
        $key = "[$($entry.Source)] $($entry.Message)"
        if (-not $groups.ContainsKey($key)) {
            $groups[$key] = @{
                ErrorType       = $key
                Level           = $entry.Level
                Source          = $entry.Source
                Message         = $entry.Message
                Count           = 0
                FirstOccurrence = $entry.Timestamp
                LastOccurrence  = $entry.Timestamp
            }
        }
        $groups[$key].Count++
        $groups[$key].LastOccurrence = $entry.Timestamp
    }

    # Convert to objects and sort by count descending
    $result = @($groups.Values | ForEach-Object {
        [PSCustomObject]@{
            ErrorType       = $_.ErrorType
            Level           = $_.Level
            Source          = $_.Source
            Message         = $_.Message
            Count           = $_.Count
            FirstOccurrence = $_.FirstOccurrence
            LastOccurrence  = $_.LastOccurrence
        }
    } | Sort-Object -Property Count -Descending)

    return $result
}

function Format-FrequencyTable {
    # Formats the frequency table as a human-readable fixed-width table string.
    param(
        [Parameter(Mandatory)]
        [array]$FrequencyTable
    )

    $header = "{0,-5} {1,-8} {2,-45} {3,-25} {4,-25}" -f "Count", "Level", "Error Type", "First Occurrence", "Last Occurrence"
    $separator = "-" * $header.Length
    $lines = @($header, $separator)

    foreach ($row in $FrequencyTable) {
        $lines += "{0,-5} {1,-8} {2,-45} {3,-25} {4,-25}" -f $row.Count, $row.Level, $row.ErrorType, $row.FirstOccurrence, $row.LastOccurrence
    }

    return ($lines -join "`n")
}

function Export-AnalysisJson {
    # Exports the frequency table to a JSON file with summary metadata.
    param(
        [Parameter(Mandatory)]
        [array]$FrequencyTable,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $totalOccurrences = ($FrequencyTable | Measure-Object -Property Count -Sum).Sum

    $output = [ordered]@{
        summary = [ordered]@{
            generated_at       = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            total_error_types  = $FrequencyTable.Count
            total_occurrences  = [int]$totalOccurrences
        }
        entries = @($FrequencyTable | ForEach-Object {
            [ordered]@{
                error_type       = $_.ErrorType
                level            = $_.Level
                source           = $_.Source
                message          = $_.Message
                count            = $_.Count
                first_occurrence = $_.FirstOccurrence
                last_occurrence  = $_.LastOccurrence
            }
        })
    }

    $output | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding utf8
}

function Invoke-LogAnalysis {
    # Main entry point: reads a log file, extracts errors/warnings,
    # builds a frequency table, outputs a human-readable table, and exports JSON.
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$JsonOutputPath
    )

    $entries = Get-LogEntries -Path $Path

    if ($entries.Count -eq 0) {
        return "No errors or warnings found in '$Path'."
    }

    $issues = Select-ErrorsAndWarnings $entries

    if ($issues.Count -eq 0) {
        return "No errors or warnings found in '$Path'."
    }

    $freqTable = Get-FrequencyTable $issues
    $formatted = Format-FrequencyTable $freqTable
    Export-AnalysisJson -FrequencyTable $freqTable -OutputPath $JsonOutputPath

    return $formatted
}
