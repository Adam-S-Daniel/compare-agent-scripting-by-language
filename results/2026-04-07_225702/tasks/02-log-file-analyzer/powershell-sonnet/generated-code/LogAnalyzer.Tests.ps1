# LogAnalyzer.Tests.ps1
# TDD test suite for the Log File Analyzer
# Tests are written BEFORE the implementation (red/green TDD)

BeforeAll {
    # Load the module under test
    . "$PSScriptRoot/LogAnalyzer.ps1"
}

# ==============================================================================
# CYCLE 1: Parse a syslog-style log line
# ==============================================================================
Describe "Parse-SyslogLine" {
    It "parses a valid syslog ERROR line" {
        $line = "2024-01-15T10:30:45 ERROR [AppServer] Connection refused to database"
        $result = Parse-SyslogLine -Line $line
        $result | Should -Not -BeNullOrEmpty
        $result.Timestamp | Should -Be ([datetime]"2024-01-15T10:30:45")
        $result.Level     | Should -Be "ERROR"
        $result.Source    | Should -Be "AppServer"
        $result.Message   | Should -Be "Connection refused to database"
    }

    It "parses a valid syslog WARNING line" {
        $line = "2024-01-15T11:00:00 WARNING [AuthService] Token expiring soon"
        $result = Parse-SyslogLine -Line $line
        $result.Level   | Should -Be "WARNING"
        $result.Source  | Should -Be "AuthService"
        $result.Message | Should -Be "Token expiring soon"
    }

    It "parses a valid syslog INFO line" {
        $line = "2024-01-15T09:00:00 INFO [Scheduler] Job started"
        $result = Parse-SyslogLine -Line $line
        $result.Level   | Should -Be "INFO"
        $result.Message | Should -Be "Job started"
    }

    It "returns null for a non-matching line" {
        $result = Parse-SyslogLine -Line "this is not a syslog line"
        $result | Should -BeNullOrEmpty
    }
}

# ==============================================================================
# CYCLE 2: Parse a JSON-structured log line
# ==============================================================================
Describe "Parse-JsonLine" {
    It "parses a valid JSON log line" {
        $line = '{"timestamp":"2024-01-15T10:30:45","level":"ERROR","type":"ConnectionError","message":"Connection refused"}'
        $result = Parse-JsonLine -Line $line
        $result | Should -Not -BeNullOrEmpty
        $result.Timestamp | Should -Be ([datetime]"2024-01-15T10:30:45")
        $result.Level     | Should -Be "ERROR"
        $result.Type      | Should -Be "ConnectionError"
        $result.Message   | Should -Be "Connection refused"
    }

    It "parses a JSON WARNING line without a type field (defaults to level)" {
        $line = '{"timestamp":"2024-01-15T12:00:00","level":"WARNING","message":"Disk usage high"}'
        $result = Parse-JsonLine -Line $line
        $result.Level | Should -Be "WARNING"
        $result.Type  | Should -Be "WARNING"   # falls back to level when type absent
    }

    It "returns null for a non-JSON line" {
        $result = Parse-JsonLine -Line "plain text, not JSON"
        $result | Should -BeNullOrEmpty
    }

    It "returns null for invalid JSON" {
        $result = Parse-JsonLine -Line "{bad json here"
        $result | Should -BeNullOrEmpty
    }
}

# ==============================================================================
# CYCLE 3: Auto-detect format and parse any log line
# ==============================================================================
Describe "Parse-LogLine" {
    It "routes a syslog line to the syslog parser" {
        $line = "2024-01-15T10:30:45 ERROR [App] Something failed"
        $result = Parse-LogLine -Line $line
        $result.Level   | Should -Be "ERROR"
        $result.Format  | Should -Be "syslog"
    }

    It "routes a JSON line to the JSON parser" {
        $line = '{"timestamp":"2024-01-15T10:30:45","level":"ERROR","type":"DiskFull","message":"Disk full"}'
        $result = Parse-LogLine -Line $line
        $result.Level  | Should -Be "ERROR"
        $result.Format | Should -Be "json"
    }

    It "returns null for unrecognised lines" {
        $result = Parse-LogLine -Line "--- separator ---"
        $result | Should -BeNullOrEmpty
    }
}

# ==============================================================================
# CYCLE 4: Parse an entire log file (mixed formats)
# ==============================================================================
Describe "Parse-LogFile" {
    BeforeAll {
        # Build an in-memory temp file as our fixture
        $script:TempLogPath = [System.IO.Path]::GetTempFileName()
        @"
2024-01-15T09:00:00 INFO [Scheduler] Daily job started
2024-01-15T09:01:00 ERROR [DB] Connection timeout
{"timestamp":"2024-01-15T09:02:00","level":"ERROR","type":"ConnectionError","message":"Connection refused"}
2024-01-15T09:03:00 WARNING [Cache] Cache miss rate high
not a valid log line
{"timestamp":"2024-01-15T09:04:00","level":"INFO","message":"Health check OK"}
"@ | Set-Content $script:TempLogPath
    }

    AfterAll {
        Remove-Item $script:TempLogPath -ErrorAction SilentlyContinue
    }

    It "returns a collection of parsed entries" {
        $entries = Parse-LogFile -Path $script:TempLogPath
        $entries | Should -Not -BeNullOrEmpty
    }

    It "skips unrecognised lines without throwing" {
        { Parse-LogFile -Path $script:TempLogPath } | Should -Not -Throw
    }

    It "parses both syslog and JSON lines" {
        $entries = Parse-LogFile -Path $script:TempLogPath
        $formats = $entries.Format | Sort-Object -Unique
        $formats | Should -Contain "syslog"
        $formats | Should -Contain "json"
    }

    It "throws a meaningful error for a missing file" {
        { Parse-LogFile -Path "C:\does\not\exist.log" } | Should -Throw "*not found*"
    }
}

# ==============================================================================
# CYCLE 5: Filter to errors and warnings only
# ==============================================================================
Describe "Get-ErrorsAndWarnings" {
    BeforeAll {
        $script:AllEntries = @(
            [PSCustomObject]@{ Level = "INFO";    Message = "ok" }
            [PSCustomObject]@{ Level = "ERROR";   Message = "boom" }
            [PSCustomObject]@{ Level = "WARNING"; Message = "careful" }
            [PSCustomObject]@{ Level = "DEBUG";   Message = "verbose" }
            [PSCustomObject]@{ Level = "ERROR";   Message = "boom again" }
        )
    }

    It "returns only ERROR and WARNING entries" {
        $filtered = Get-ErrorsAndWarnings -Entries $script:AllEntries
        $filtered.Count | Should -Be 3
        $filtered.Level | Should -Not -Contain "INFO"
        $filtered.Level | Should -Not -Contain "DEBUG"
    }

    It "returns an empty collection when there are no errors or warnings" {
        $infoOnly = @([PSCustomObject]@{ Level = "INFO"; Message = "all good" })
        $filtered = Get-ErrorsAndWarnings -Entries $infoOnly
        $filtered.Count | Should -Be 0
    }
}

# ==============================================================================
# CYCLE 6: Build a frequency table with first/last occurrence timestamps
# ==============================================================================
Describe "Build-FrequencyTable" {
    BeforeAll {
        $script:Entries = @(
            [PSCustomObject]@{ Level = "ERROR";   Type = "ConnectionError"; Timestamp = [datetime]"2024-01-15T09:01:00" }
            [PSCustomObject]@{ Level = "ERROR";   Type = "ConnectionError"; Timestamp = [datetime]"2024-01-15T09:05:00" }
            [PSCustomObject]@{ Level = "WARNING"; Type = "DiskWarning";     Timestamp = [datetime]"2024-01-15T09:03:00" }
            [PSCustomObject]@{ Level = "ERROR";   Type = "ConnectionError"; Timestamp = [datetime]"2024-01-15T09:02:00" }
        )
    }

    It "returns one row per unique error type" {
        $table = Build-FrequencyTable -Entries $script:Entries
        $table.Count | Should -Be 2
    }

    It "counts occurrences correctly" {
        $table = Build-FrequencyTable -Entries $script:Entries
        $conn = $table | Where-Object { $_.Type -eq "ConnectionError" }
        $conn.Count | Should -Be 3
    }

    It "records the earliest first-occurrence timestamp" {
        $table = Build-FrequencyTable -Entries $script:Entries
        $conn = $table | Where-Object { $_.Type -eq "ConnectionError" }
        $conn.FirstOccurrence | Should -Be ([datetime]"2024-01-15T09:01:00")
    }

    It "records the latest last-occurrence timestamp" {
        $table = Build-FrequencyTable -Entries $script:Entries
        $conn = $table | Where-Object { $_.Type -eq "ConnectionError" }
        $conn.LastOccurrence | Should -Be ([datetime]"2024-01-15T09:05:00")
    }

    It "includes the dominant level for each type" {
        $table = Build-FrequencyTable -Entries $script:Entries
        $disk = $table | Where-Object { $_.Type -eq "DiskWarning" }
        $disk.Level | Should -Be "WARNING"
    }

    It "returns an empty array for empty input" {
        $table = Build-FrequencyTable -Entries @()
        $table.Count | Should -Be 0
    }
}

# ==============================================================================
# CYCLE 7: Format the frequency table as a human-readable string
# ==============================================================================
Describe "Format-FrequencyTable" {
    BeforeAll {
        $script:FreqTable = @(
            [PSCustomObject]@{
                Type            = "ConnectionError"
                Level           = "ERROR"
                Count           = 3
                FirstOccurrence = [datetime]"2024-01-15T09:01:00"
                LastOccurrence  = [datetime]"2024-01-15T09:05:00"
            }
            [PSCustomObject]@{
                Type            = "DiskWarning"
                Level           = "WARNING"
                Count           = 1
                FirstOccurrence = [datetime]"2024-01-15T09:03:00"
                LastOccurrence  = [datetime]"2024-01-15T09:03:00"
            }
        )
    }

    It "returns a non-empty string" {
        $output = Format-FrequencyTable -FrequencyTable $script:FreqTable
        $output | Should -Not -BeNullOrEmpty
    }

    It "contains a header line" {
        $output = Format-FrequencyTable -FrequencyTable $script:FreqTable
        $output | Should -Match "Type"
        $output | Should -Match "Count"
    }

    It "contains each error type name" {
        $output = Format-FrequencyTable -FrequencyTable $script:FreqTable
        $output | Should -Match "ConnectionError"
        $output | Should -Match "DiskWarning"
    }

    It "includes the occurrence counts" {
        $output = Format-FrequencyTable -FrequencyTable $script:FreqTable
        $output | Should -Match "3"
    }
}

# ==============================================================================
# CYCLE 8: Export analysis to JSON
# ==============================================================================
Describe "Export-AnalysisJson" {
    BeforeAll {
        $script:ExportTable = @(
            [PSCustomObject]@{
                Type            = "NullPointerException"
                Level           = "ERROR"
                Count           = 5
                FirstOccurrence = [datetime]"2024-01-15T08:00:00"
                LastOccurrence  = [datetime]"2024-01-15T16:00:00"
            }
        )
        $script:ExportPath = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.json'
    }

    AfterAll {
        Remove-Item $script:ExportPath -ErrorAction SilentlyContinue
    }

    It "creates a JSON file at the specified path" {
        Export-AnalysisJson -FrequencyTable $script:ExportTable -Path $script:ExportPath
        Test-Path $script:ExportPath | Should -Be $true
    }

    It "produces valid JSON" {
        Export-AnalysisJson -FrequencyTable $script:ExportTable -Path $script:ExportPath
        { Get-Content $script:ExportPath -Raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It "JSON contains expected fields" {
        Export-AnalysisJson -FrequencyTable $script:ExportTable -Path $script:ExportPath
        $json = Get-Content $script:ExportPath -Raw | ConvertFrom-Json
        $entry = $json[0]
        $entry.type            | Should -Be "NullPointerException"
        $entry.count           | Should -Be 5
        $entry.firstOccurrence | Should -Not -BeNullOrEmpty
        $entry.lastOccurrence  | Should -Not -BeNullOrEmpty
    }
}

# ==============================================================================
# CYCLE 9: End-to-end integration test using the sample fixture file
# ==============================================================================
Describe "Invoke-LogAnalysis (integration)" {
    BeforeAll {
        $script:FixturePath  = "$PSScriptRoot/fixtures/sample.log"
        $script:JsonOutPath  = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.json'
    }

    AfterAll {
        Remove-Item $script:JsonOutPath -ErrorAction SilentlyContinue
    }

    It "runs without throwing on the sample fixture" {
        { Invoke-LogAnalysis -LogPath $script:FixturePath -JsonOutputPath $script:JsonOutPath } |
            Should -Not -Throw
    }

    It "produces a JSON output file" {
        Invoke-LogAnalysis -LogPath $script:FixturePath -JsonOutputPath $script:JsonOutPath
        Test-Path $script:JsonOutPath | Should -Be $true
    }

    It "JSON output has at least one entry" {
        Invoke-LogAnalysis -LogPath $script:FixturePath -JsonOutputPath $script:JsonOutPath
        $json = Get-Content $script:JsonOutPath -Raw | ConvertFrom-Json
        $json.Count | Should -BeGreaterThan 0
    }

    It "returns a human-readable table string" {
        $result = Invoke-LogAnalysis -LogPath $script:FixturePath -JsonOutputPath $script:JsonOutPath
        $result | Should -Not -BeNullOrEmpty
        $result | Should -Match "Type"
    }
}
