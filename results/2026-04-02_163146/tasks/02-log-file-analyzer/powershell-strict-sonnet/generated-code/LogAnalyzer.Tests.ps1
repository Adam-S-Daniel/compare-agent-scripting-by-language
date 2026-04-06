#Requires -Modules Pester
# TDD test suite for LogAnalyzer module
# RED/GREEN cycle: each Describe block was written as failing tests first,
# then minimum code was written to make them pass.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Resolve paths relative to this test file
$here = $PSScriptRoot
$modulePath = Join-Path $here 'LogAnalyzer.psm1'
$fixturesDir = Join-Path $here 'fixtures'
$sampleLogPath = Join-Path $fixturesDir 'sample.log'

# Import the module under test
Import-Module $modulePath -Force

# ---------------------------------------------------------------------------
# RED CYCLE 1: Fixture loading
# Test that the sample log fixture exists and is non-empty.
# This is the first test — it will fail until we create fixtures/sample.log.
# ---------------------------------------------------------------------------
Describe 'Test Fixtures' {
    It 'should have a sample log fixture file' {
        $sampleLogPath | Should -Exist
    }

    It 'should contain at least 10 lines' {
        $lines = Get-Content $sampleLogPath
        $lines.Count | Should -BeGreaterOrEqual 10
    }

    It 'should contain syslog-style lines' {
        $content = Get-Content $sampleLogPath -Raw
        # Syslog format: "MMM DD HH:MM:SS hostname process[pid]: message"
        $content | Should -Match '\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}'
    }

    It 'should contain JSON-structured lines' {
        $content = Get-Content $sampleLogPath -Raw
        $content | Should -Match '\{"timestamp":'
    }

    It 'should contain ERROR entries' {
        $content = Get-Content $sampleLogPath -Raw
        $content | Should -Match 'ERROR'
    }

    It 'should contain WARNING entries' {
        $content = Get-Content $sampleLogPath -Raw
        $content | Should -Match 'WARN'
    }
}

# ---------------------------------------------------------------------------
# RED CYCLE 2: Syslog line parsing
# Test Parse-SyslogLine function
# ---------------------------------------------------------------------------
Describe 'Parse-SyslogLine' {
    It 'should parse a valid syslog ERROR line' {
        $line = 'Apr  2 10:15:30 webserver nginx[1234]: ERROR: Connection refused to upstream'
        $result = Parse-SyslogLine -Line $line
        $result | Should -Not -BeNullOrEmpty
        $result.Level | Should -Be 'ERROR'
        $result.ErrorType | Should -Be 'Connection refused to upstream'
        $result.Source | Should -Be 'nginx'
    }

    It 'should parse a valid syslog WARNING line' {
        $line = 'Apr  2 10:16:00 appserver myapp[5678]: WARNING: Disk usage at 85%'
        $result = Parse-SyslogLine -Line $line
        $result.Level | Should -Be 'WARNING'
        $result.ErrorType | Should -Be 'Disk usage at 85%'
    }

    It 'should return null for INFO lines' {
        $line = 'Apr  2 10:17:00 webserver nginx[1234]: INFO: Request processed successfully'
        $result = Parse-SyslogLine -Line $line
        $result | Should -BeNullOrEmpty
    }

    It 'should return null for non-syslog lines' {
        $line = 'This is not a syslog line'
        $result = Parse-SyslogLine -Line $line
        $result | Should -BeNullOrEmpty
    }

    It 'should parse the timestamp correctly' {
        $line = 'Apr  2 10:15:30 webserver nginx[1234]: ERROR: Connection refused to upstream'
        $result = Parse-SyslogLine -Line $line
        $result.Timestamp | Should -Not -BeNullOrEmpty
        $result.Timestamp | Should -BeOfType [datetime]
    }

    It 'should handle WARN (abbreviated) level' {
        $line = 'Apr  2 11:00:00 dbserver postgres[999]: WARN: Slow query detected'
        $result = Parse-SyslogLine -Line $line
        $result | Should -Not -BeNullOrEmpty
        $result.Level | Should -Be 'WARN'
    }
}

# ---------------------------------------------------------------------------
# RED CYCLE 3: JSON line parsing
# Test Parse-JsonLogLine function
# ---------------------------------------------------------------------------
Describe 'Parse-JsonLogLine' {
    It 'should parse a valid JSON ERROR line' {
        $line = '{"timestamp":"2026-04-02T10:20:00Z","level":"ERROR","message":"Database connection timeout","service":"auth-service"}'
        $result = Parse-JsonLogLine -Line $line
        $result | Should -Not -BeNullOrEmpty
        $result.Level | Should -Be 'ERROR'
        $result.ErrorType | Should -Be 'Database connection timeout'
        $result.Source | Should -Be 'auth-service'
    }

    It 'should parse a valid JSON WARN line' {
        $line = '{"timestamp":"2026-04-02T10:21:00Z","level":"WARN","message":"Memory usage high","service":"cache-service"}'
        $result = Parse-JsonLogLine -Line $line
        $result.Level | Should -Be 'WARN'
        $result.ErrorType | Should -Be 'Memory usage high'
    }

    It 'should return null for INFO-level JSON lines' {
        $line = '{"timestamp":"2026-04-02T10:22:00Z","level":"INFO","message":"Service started","service":"api"}'
        $result = Parse-JsonLogLine -Line $line
        $result | Should -BeNullOrEmpty
    }

    It 'should return null for non-JSON lines' {
        $line = 'plain text line, not JSON'
        $result = Parse-JsonLogLine -Line $line
        $result | Should -BeNullOrEmpty
    }

    It 'should parse timestamp from JSON correctly' {
        $line = '{"timestamp":"2026-04-02T10:20:00Z","level":"ERROR","message":"Test error","service":"svc"}'
        $result = Parse-JsonLogLine -Line $line
        $result.Timestamp | Should -BeOfType [datetime]
    }

    It 'should handle ERROR level with error_type field when present' {
        $line = '{"timestamp":"2026-04-02T10:23:00Z","level":"ERROR","message":"Disk full","error_type":"DiskFullError","service":"storage"}'
        $result = Parse-JsonLogLine -Line $line
        $result.ErrorType | Should -Be 'DiskFullError'
    }
}

# ---------------------------------------------------------------------------
# RED CYCLE 4: Log file parsing (mixed format)
# Test Get-LogEntries function which parses the whole file
# ---------------------------------------------------------------------------
Describe 'Get-LogEntries' {
    It 'should parse the sample log and return entries' {
        $entries = Get-LogEntries -LogPath $sampleLogPath
        $entries | Should -Not -BeNullOrEmpty
        $entries.Count | Should -BeGreaterThan 0
    }

    It 'should only return ERROR and WARNING entries' {
        $entries = Get-LogEntries -LogPath $sampleLogPath
        foreach ($entry in $entries) {
            $entry.Level | Should -BeIn @('ERROR', 'WARNING', 'WARN')
        }
    }

    It 'should throw a meaningful error for non-existent file' {
        { Get-LogEntries -LogPath 'C:\nonexistent\file.log' } | Should -Throw
    }

    It 'should return entries with required properties' {
        $entries = Get-LogEntries -LogPath $sampleLogPath
        $first = $entries[0]
        $first.PSObject.Properties.Name | Should -Contain 'Timestamp'
        $first.PSObject.Properties.Name | Should -Contain 'Level'
        $first.PSObject.Properties.Name | Should -Contain 'ErrorType'
        $first.PSObject.Properties.Name | Should -Contain 'Source'
    }

    It 'should parse entries from both syslog and JSON lines' {
        $entries = Get-LogEntries -LogPath $sampleLogPath
        # Verify we get entries from multiple sources (mix of syslog and JSON)
        $sources = $entries | Select-Object -ExpandProperty Source -Unique
        $sources.Count | Should -BeGreaterThan 1
    }
}

# ---------------------------------------------------------------------------
# RED CYCLE 5: Frequency table generation
# Test Get-ErrorFrequencyTable function
# ---------------------------------------------------------------------------
Describe 'Get-ErrorFrequencyTable' {
    # Build a known set of test entries
    $testEntries = @(
        [PSCustomObject]@{ Timestamp = [datetime]'2026-04-02 10:00:00'; Level = 'ERROR'; ErrorType = 'Connection refused'; Source = 'nginx' }
        [PSCustomObject]@{ Timestamp = [datetime]'2026-04-02 10:05:00'; Level = 'ERROR'; ErrorType = 'Connection refused'; Source = 'nginx' }
        [PSCustomObject]@{ Timestamp = [datetime]'2026-04-02 10:10:00'; Level = 'ERROR'; ErrorType = 'Connection refused'; Source = 'nginx' }
        [PSCustomObject]@{ Timestamp = [datetime]'2026-04-02 10:02:00'; Level = 'WARN';  ErrorType = 'Disk usage high';    Source = 'monitor' }
        [PSCustomObject]@{ Timestamp = [datetime]'2026-04-02 10:15:00'; Level = 'WARN';  ErrorType = 'Disk usage high';    Source = 'monitor' }
        [PSCustomObject]@{ Timestamp = [datetime]'2026-04-02 10:08:00'; Level = 'ERROR'; ErrorType = 'Timeout';            Source = 'api' }
    )

    It 'should return one row per unique error type' {
        $table = Get-ErrorFrequencyTable -Entries $testEntries
        $table.Count | Should -Be 3
    }

    It 'should count occurrences correctly' {
        $table = Get-ErrorFrequencyTable -Entries $testEntries
        $connRefused = $table | Where-Object { $_.ErrorType -eq 'Connection refused' }
        $connRefused.Count | Should -Be 3
    }

    It 'should record the first occurrence timestamp' {
        $table = Get-ErrorFrequencyTable -Entries $testEntries
        $connRefused = $table | Where-Object { $_.ErrorType -eq 'Connection refused' }
        $connRefused.FirstSeen | Should -Be ([datetime]'2026-04-02 10:00:00')
    }

    It 'should record the last occurrence timestamp' {
        $table = Get-ErrorFrequencyTable -Entries $testEntries
        $connRefused = $table | Where-Object { $_.ErrorType -eq 'Connection refused' }
        $connRefused.LastSeen | Should -Be ([datetime]'2026-04-02 10:10:00')
    }

    It 'should include the Level in the table' {
        $table = Get-ErrorFrequencyTable -Entries $testEntries
        $row = $table | Where-Object { $_.ErrorType -eq 'Disk usage high' }
        $row.Level | Should -Be 'WARN'
    }

    It 'should return an empty array for empty input' {
        $table = Get-ErrorFrequencyTable -Entries @()
        $table.Count | Should -Be 0
    }

    It 'should sort by count descending' {
        $table = Get-ErrorFrequencyTable -Entries $testEntries
        $table[0].Count | Should -BeGreaterOrEqual $table[1].Count
        $table[1].Count | Should -BeGreaterOrEqual $table[2].Count
    }
}

# ---------------------------------------------------------------------------
# RED CYCLE 6: Human-readable table output
# Test Format-FrequencyTable function
# ---------------------------------------------------------------------------
Describe 'Format-FrequencyTable' {
    $testTable = @(
        [PSCustomObject]@{ ErrorType = 'Connection refused'; Level = 'ERROR'; Count = 3; FirstSeen = [datetime]'2026-04-02 10:00:00'; LastSeen = [datetime]'2026-04-02 10:10:00' }
        [PSCustomObject]@{ ErrorType = 'Disk usage high';   Level = 'WARN';  Count = 2; FirstSeen = [datetime]'2026-04-02 10:02:00'; LastSeen = [datetime]'2026-04-02 10:15:00' }
    )

    It 'should return a non-empty string' {
        $output = Format-FrequencyTable -FrequencyTable $testTable
        $output | Should -Not -BeNullOrEmpty
        $output | Should -BeOfType [string]
    }

    It 'should include a header line with column names' {
        $output = Format-FrequencyTable -FrequencyTable $testTable
        $output | Should -Match 'ErrorType'
        $output | Should -Match 'Count'
        $output | Should -Match 'First'
        $output | Should -Match 'Last'
    }

    It 'should include error type names' {
        $output = Format-FrequencyTable -FrequencyTable $testTable
        $output | Should -Match 'Connection refused'
        $output | Should -Match 'Disk usage high'
    }

    It 'should include occurrence counts' {
        $output = Format-FrequencyTable -FrequencyTable $testTable
        $output | Should -Match '3'
        $output | Should -Match '2'
    }

    It 'should return a message for empty table' {
        $output = Format-FrequencyTable -FrequencyTable @()
        $output | Should -Match 'No error'
    }
}

# ---------------------------------------------------------------------------
# RED CYCLE 7: JSON output
# Test Export-AnalysisJson function
# ---------------------------------------------------------------------------
Describe 'Export-AnalysisJson' {
    $testTable = @(
        [PSCustomObject]@{ ErrorType = 'Connection refused'; Level = 'ERROR'; Count = 3; FirstSeen = [datetime]'2026-04-02 10:00:00'; LastSeen = [datetime]'2026-04-02 10:10:00' }
    )

    It 'should create a JSON file at the specified path' {
        $outPath = Join-Path $TestDrive 'analysis.json'
        Export-AnalysisJson -FrequencyTable $testTable -OutputPath $outPath
        $outPath | Should -Exist
    }

    It 'should produce valid JSON' {
        $outPath = Join-Path $TestDrive 'analysis.json'
        Export-AnalysisJson -FrequencyTable $testTable -OutputPath $outPath
        { Get-Content $outPath -Raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'should include error entries in the JSON' {
        $outPath = Join-Path $TestDrive 'analysis.json'
        Export-AnalysisJson -FrequencyTable $testTable -OutputPath $outPath
        $json = Get-Content $outPath -Raw | ConvertFrom-Json
        $json | Should -Not -BeNullOrEmpty
    }

    It 'should include metadata with generation timestamp' {
        $outPath = Join-Path $TestDrive 'analysis.json'
        Export-AnalysisJson -FrequencyTable $testTable -OutputPath $outPath
        $json = Get-Content $outPath -Raw | ConvertFrom-Json
        $json.generatedAt | Should -Not -BeNullOrEmpty
    }

    It 'should include summary counts' {
        $outPath = Join-Path $TestDrive 'analysis.json'
        Export-AnalysisJson -FrequencyTable $testTable -OutputPath $outPath
        $json = Get-Content $outPath -Raw | ConvertFrom-Json
        $json.summary | Should -Not -BeNullOrEmpty
    }
}

# ---------------------------------------------------------------------------
# RED CYCLE 8: End-to-end integration
# Test Invoke-LogAnalysis (the main orchestration function)
# ---------------------------------------------------------------------------
Describe 'Invoke-LogAnalysis' {
    It 'should produce a JSON output file' {
        $jsonOut = Join-Path $TestDrive 'result.json'
        Invoke-LogAnalysis -LogPath $sampleLogPath -JsonOutputPath $jsonOut
        $jsonOut | Should -Exist
    }

    It 'should return a human-readable report string' {
        $jsonOut = Join-Path $TestDrive 'result2.json'
        $report = Invoke-LogAnalysis -LogPath $sampleLogPath -JsonOutputPath $jsonOut
        $report | Should -Not -BeNullOrEmpty
        $report | Should -BeOfType [string]
    }

    It 'should include error count summary in the report' {
        $jsonOut = Join-Path $TestDrive 'result3.json'
        $report = Invoke-LogAnalysis -LogPath $sampleLogPath -JsonOutputPath $jsonOut
        $report | Should -Match 'ERROR\|WARN'
    }

    It 'should throw for missing log file' {
        $jsonOut = Join-Path $TestDrive 'result4.json'
        { Invoke-LogAnalysis -LogPath 'missing.log' -JsonOutputPath $jsonOut } | Should -Throw
    }
}
