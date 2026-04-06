# LogAnalyzer.ps1
# Parses mixed-format log files (syslog + JSON), extracts errors/warnings,
# builds a frequency table, and outputs results as a human-readable table and JSON.
#
# TDD GREEN phase: each function is implemented to satisfy the corresponding tests
# in LogAnalyzer.Tests.ps1.

# ---------------------------------------------------------------------------
# Parse-LogLine: Parse a single log line (syslog or JSON format)
# Returns a PSCustomObject with Timestamp, Level, Source, Message — or $null.
# ---------------------------------------------------------------------------
function Parse-LogLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Line
    )

    # Guard: null or empty
    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $null
    }

    # --- Try JSON first (lines starting with '{') ---
    if ($Line.TrimStart().StartsWith('{')) {
        try {
            $obj = $Line | ConvertFrom-Json -ErrorAction Stop

            # Require the minimum fields
            if (-not $obj.timestamp -or -not $obj.level -or -not $obj.message) {
                return $null
            }

            return [PSCustomObject]@{
                Timestamp = [datetime]$obj.timestamp
                Level     = $obj.level.ToUpper()
                Source    = if ($obj.service) { $obj.service } else { 'unknown' }
                Message   = $obj.message
            }
        }
        catch {
            # Malformed JSON — skip
            return $null
        }
    }

    # --- Try syslog format ---
    # Pattern: YYYY-MM-DD HH:MM:SS <host> <process>: <LEVEL>: <message>
    $syslogPattern = '^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(\S+\s+\S+):\s+(INFO|ERROR|WARNING|WARN|DEBUG|CRITICAL):\s+(.+)$'

    if ($Line -match $syslogPattern) {
        $ts      = [datetime]$Matches[1]
        $source  = $Matches[2]
        $level   = $Matches[3].ToUpper()
        $message = $Matches[4]

        # Normalize WARN -> WARNING for consistency
        if ($level -eq 'WARN') { $level = 'WARNING' }

        return [PSCustomObject]@{
            Timestamp = $ts
            Level     = $level
            Source    = $source
            Message   = $message
        }
    }

    # Unrecognised format
    return $null
}

# ---------------------------------------------------------------------------
# Read-LogFile: Read all lines from a log file and parse each one.
# Returns an array of parsed entry objects (skips unparseable lines).
# ---------------------------------------------------------------------------
function Read-LogFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Validate file exists — throw a meaningful error if not
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Log file '$Path' does not exist."
    }

    $lines = Get-Content -LiteralPath $Path -ErrorAction Stop
    $entries = @()

    foreach ($line in $lines) {
        $parsed = Parse-LogLine -Line $line
        if ($null -ne $parsed) {
            $entries += $parsed
        }
    }

    return , $entries
}

# ---------------------------------------------------------------------------
# Get-ErrorsAndWarnings: Filter parsed entries to only ERROR and WARNING levels.
# ---------------------------------------------------------------------------
function Get-ErrorsAndWarnings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Entries
    )

    if ($Entries.Count -eq 0) {
        return , @()
    }

    $filtered = @($Entries | Where-Object { $_.Level -eq 'ERROR' -or $_.Level -eq 'WARNING' })
    return , $filtered
}

# ---------------------------------------------------------------------------
# Build-FrequencyTable: Group errors/warnings by (Level + Message) and compute
# count, first occurrence, and last occurrence for each group.
# ---------------------------------------------------------------------------
function Build-FrequencyTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Entries
    )

    if ($Entries.Count -eq 0) {
        return , @()
    }

    # Group by composite key of Level and Message
    $groups = $Entries | Group-Object -Property { "$($_.Level)|$($_.Message)" }

    $table = @()
    foreach ($group in $groups) {
        $sorted = $group.Group | Sort-Object Timestamp
        $first  = $sorted | Select-Object -First 1
        $last   = $sorted | Select-Object -Last 1

        $table += [PSCustomObject]@{
            Level           = $first.Level
            Message         = $first.Message
            Count           = $group.Count
            FirstOccurrence = $first.Timestamp
            LastOccurrence  = $last.Timestamp
        }
    }

    # Sort by count descending for readability
    $table = @($table | Sort-Object Count -Descending)
    return , $table
}

# ---------------------------------------------------------------------------
# Format-FrequencyTable: Render the frequency table as a human-readable string.
# ---------------------------------------------------------------------------
function Format-FrequencyTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Table
    )

    if ($Table.Count -eq 0) {
        return 'No errors or warnings found.'
    }

    $sb = [System.Text.StringBuilder]::new()

    # Header
    $header = '{0,-9} {1,-6} {2,-22} {3,-22} {4}' -f 'Level', 'Count', 'First Occurrence', 'Last Occurrence', 'Message'
    $separator = '-' * ($header.Length + 20)

    [void]$sb.AppendLine('Log Analysis — Error/Warning Frequency Table')
    [void]$sb.AppendLine($separator)
    [void]$sb.AppendLine($header)
    [void]$sb.AppendLine($separator)

    foreach ($row in $Table) {
        $line = '{0,-9} {1,-6} {2,-22} {3,-22} {4}' -f `
            $row.Level,
            $row.Count,
            $row.FirstOccurrence.ToString('yyyy-MM-dd HH:mm:ss'),
            $row.LastOccurrence.ToString('yyyy-MM-dd HH:mm:ss'),
            $row.Message
        [void]$sb.AppendLine($line)
    }

    [void]$sb.AppendLine($separator)
    [void]$sb.AppendLine("Total distinct error/warning types: $($Table.Count)")

    return $sb.ToString()
}

# ---------------------------------------------------------------------------
# Export-AnalysisJson: Write the frequency table to a JSON file.
# ---------------------------------------------------------------------------
function Export-AnalysisJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Table,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    # Convert datetime fields to ISO 8601 strings for clean JSON serialization
    $jsonData = $Table | ForEach-Object {
        [PSCustomObject]@{
            Level           = $_.Level
            Message         = $_.Message
            Count           = $_.Count
            FirstOccurrence = $_.FirstOccurrence.ToString('o')
            LastOccurrence  = $_.LastOccurrence.ToString('o')
        }
    }

    # Use -InputObject (not pipeline) to ensure a JSON array even for a single entry
    ConvertTo-Json -InputObject @($jsonData) -Depth 5 |
        Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

# ---------------------------------------------------------------------------
# Invoke-LogAnalysis: Main entry point — orchestrates the full pipeline.
# Returns the human-readable table string and writes a JSON file.
# ---------------------------------------------------------------------------
function Invoke-LogAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath,

        [Parameter(Mandatory = $true)]
        [string]$JsonOutputPath
    )

    # Read and parse the log file (will throw if file missing)
    $entries = Read-LogFile -Path $LogPath

    # Filter to errors and warnings
    $filtered = Get-ErrorsAndWarnings -Entries $entries

    # Handle the no-errors case
    if ($filtered.Count -eq 0) {
        # Still write an empty JSON array
        '[]' | Set-Content -LiteralPath $JsonOutputPath -Encoding UTF8
        return 'No errors or warnings found.'
    }

    # Build frequency table
    $table = Build-FrequencyTable -Entries $filtered

    # Export JSON
    Export-AnalysisJson -Table $table -OutputPath $JsonOutputPath

    # Return human-readable output
    $output = Format-FrequencyTable -Table $table
    return $output
}

# ---------------------------------------------------------------------------
# CLI entry point — only runs when the script is executed directly (not dot-sourced)
# ---------------------------------------------------------------------------
if ($MyInvocation.InvocationName -ne '.') {
    # Only run main logic if arguments are provided (not being sourced by tests)
    if ($args.Count -ge 1) {
        $logFile    = $args[0]
        $jsonOutput = if ($args.Count -ge 2) { $args[1] } else { 'analysis-output.json' }

        try {
            $result = Invoke-LogAnalysis -LogPath $logFile -JsonOutputPath $jsonOutput
            Write-Output $result
            Write-Output "`nJSON output written to: $jsonOutput"
        }
        catch {
            Write-Error "Error: $_"
            exit 1
        }
    }
}
