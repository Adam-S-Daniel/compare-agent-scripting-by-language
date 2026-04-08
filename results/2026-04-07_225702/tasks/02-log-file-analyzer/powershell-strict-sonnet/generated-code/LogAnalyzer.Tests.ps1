# LogAnalyzer.Tests.ps1
# TDD test suite for the Log File Analyzer
# Approach: Red/Green/Refactor - write failing tests first, then implement minimum code to pass

# Note: Set-StrictMode is intentionally NOT placed here at the top level.
# Pester intercepts Set-StrictMode during discovery and its wrapper does not
# support -Latest, which would cause discovery to fail.
# Strict mode is enforced inside LogAnalyzer.psm1 (the code under test).

# Import the module inside BeforeAll so it runs during the execution phase,
# not during Pester's discovery phase (when cmdlet interceptors are active).
BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot 'LogAnalyzer.psm1'
    Import-Module $ModulePath -Force
}

Describe 'LogAnalyzer - Syslog Line Parsing' {
    BeforeAll {
        # Syslog format: "Jan 15 10:23:45 hostname process[pid]: LEVEL message"
        $script:SyslogError = 'Jan 15 10:23:45 myhost myapp[1234]: ERROR Failed to connect to database'
        $script:SyslogWarning = 'Jan 15 10:24:00 myhost myapp[1234]: WARNING Retry attempt 1 of 3'
        $script:SyslogInfo = 'Jan 15 10:24:01 myhost myapp[1234]: INFO Connection established'
    }

    It 'Should parse a syslog ERROR line into a LogEntry object' {
        $result = ConvertFrom-SyslogLine -Line $script:SyslogError

        $result | Should -Not -BeNullOrEmpty
        $result.Level | Should -Be 'ERROR'
        $result.Message | Should -Be 'Failed to connect to database'
        $result.Source | Should -Be 'myapp'
        $result.Timestamp | Should -Not -BeNullOrEmpty
    }

    It 'Should parse a syslog WARNING line correctly' {
        $result = ConvertFrom-SyslogLine -Line $script:SyslogWarning

        $result.Level | Should -Be 'WARNING'
        $result.Message | Should -Be 'Retry attempt 1 of 3'
    }

    It 'Should parse a syslog INFO line correctly' {
        $result = ConvertFrom-SyslogLine -Line $script:SyslogInfo

        $result.Level | Should -Be 'INFO'
        $result.Message | Should -Be 'Connection established'
    }

    It 'Should return null for unrecognized syslog format' {
        $result = ConvertFrom-SyslogLine -Line 'this is not a syslog line'
        $result | Should -BeNullOrEmpty
    }
}

Describe 'LogAnalyzer - JSON Line Parsing' {
    BeforeAll {
        $script:JsonError = '{"timestamp":"2024-01-15T10:23:46Z","level":"ERROR","message":"Database connection failed","source":"db-service"}'
        $script:JsonWarning = '{"timestamp":"2024-01-15T10:25:00Z","level":"WARN","message":"High memory usage","source":"monitor"}'
        $script:JsonInfo = '{"timestamp":"2024-01-15T10:26:00Z","level":"INFO","message":"Request completed","source":"api"}'
        $script:InvalidJson = '{"timestamp":"broken json'
    }

    It 'Should parse a JSON ERROR line into a LogEntry object' {
        $result = ConvertFrom-JsonLogLine -Line $script:JsonError

        $result | Should -Not -BeNullOrEmpty
        $result.Level | Should -Be 'ERROR'
        $result.Message | Should -Be 'Database connection failed'
        $result.Source | Should -Be 'db-service'
        $result.Timestamp | Should -Not -BeNullOrEmpty
    }

    It 'Should parse a JSON WARN line and normalise level to WARNING' {
        $result = ConvertFrom-JsonLogLine -Line $script:JsonWarning

        $result.Level | Should -Be 'WARNING'
        $result.Message | Should -Be 'High memory usage'
    }

    It 'Should parse a JSON INFO line correctly' {
        $result = ConvertFrom-JsonLogLine -Line $script:JsonInfo

        $result.Level | Should -Be 'INFO'
        $result.Source | Should -Be 'api'
    }

    It 'Should return null for invalid JSON' {
        $result = ConvertFrom-JsonLogLine -Line $script:InvalidJson
        $result | Should -BeNullOrEmpty
    }

    It 'Should return null for a non-JSON line' {
        $result = ConvertFrom-JsonLogLine -Line 'Jan 15 10:23:45 myhost myapp[1234]: ERROR msg'
        $result | Should -BeNullOrEmpty
    }
}

Describe 'LogAnalyzer - Mixed Log File Parsing' {
    BeforeAll {
        # Create a temporary fixture file with mixed log content
        $script:FixtureDir = Join-Path $PSScriptRoot 'fixtures'
        if (-not (Test-Path $script:FixtureDir)) {
            New-Item -ItemType Directory -Path $script:FixtureDir | Out-Null
        }
        $script:MixedLogPath = Join-Path $script:FixtureDir 'mixed.log'
        $content = @(
            'Jan 15 10:23:45 myhost myapp[1234]: ERROR Failed to connect to database'
            'Jan 15 10:24:00 myhost myapp[1234]: WARNING Retry attempt 1 of 3'
            'Jan 15 10:24:01 myhost myapp[1234]: INFO Connection established'
            '{"timestamp":"2024-01-15T10:23:46Z","level":"ERROR","message":"Database connection failed","source":"db-service"}'
            '{"timestamp":"2024-01-15T10:25:00Z","level":"WARN","message":"High memory usage","source":"monitor"}'
            '{"timestamp":"2024-01-15T10:26:00Z","level":"INFO","message":"Request completed","source":"api"}'
            'This line has no recognizable format'
            'Jan 15 10:27:00 myhost myapp[1234]: ERROR Disk write failed'
        )
        Set-Content -Path $script:MixedLogPath -Value $content
    }

    AfterAll {
        if (Test-Path $script:MixedLogPath) {
            Remove-Item $script:MixedLogPath -Force
        }
    }

    It 'Should parse all recognizable lines from a mixed log file' {
        $entries = Read-LogFile -Path $script:MixedLogPath

        # 8 lines: 7 recognized (3 syslog + 3 json + 1 more syslog) + 1 unrecognized skipped
        $entries.Count | Should -Be 7
    }

    It 'Should include entries from both syslog and JSON formats' {
        $entries = Read-LogFile -Path $script:MixedLogPath

        $syslogEntries = $entries | Where-Object { $_.Format -eq 'syslog' }
        $jsonEntries = $entries | Where-Object { $_.Format -eq 'json' }

        $syslogEntries.Count | Should -Be 4
        $jsonEntries.Count | Should -Be 3
    }

    It 'Should throw a meaningful error when log file does not exist' {
        { Read-LogFile -Path 'C:\nonexistent\log.txt' } | Should -Throw
    }
}

Describe 'LogAnalyzer - Error and Warning Filtering' {
    BeforeAll {
        $script:AllEntries = @(
            [PSCustomObject]@{ Level = 'ERROR';   Message = 'DB failed';      Timestamp = [datetime]'2024-01-15 10:00:00'; Source = 'db';  Format = 'syslog' }
            [PSCustomObject]@{ Level = 'WARNING'; Message = 'High CPU';       Timestamp = [datetime]'2024-01-15 10:01:00'; Source = 'sys'; Format = 'json'   }
            [PSCustomObject]@{ Level = 'INFO';    Message = 'Started';        Timestamp = [datetime]'2024-01-15 10:02:00'; Source = 'app'; Format = 'syslog' }
            [PSCustomObject]@{ Level = 'ERROR';   Message = 'Disk write fail';Timestamp = [datetime]'2024-01-15 10:03:00'; Source = 'io';  Format = 'syslog' }
            [PSCustomObject]@{ Level = 'DEBUG';   Message = 'Verbose trace';  Timestamp = [datetime]'2024-01-15 10:04:00'; Source = 'app'; Format = 'json'   }
        )
    }

    It 'Should return only ERROR and WARNING entries' {
        $filtered = Select-ErrorsAndWarnings -Entries $script:AllEntries

        $filtered.Count | Should -Be 3
        $filtered | ForEach-Object { $_.Level | Should -BeIn @('ERROR', 'WARNING') }
    }

    It 'Should exclude INFO and DEBUG entries' {
        $filtered = Select-ErrorsAndWarnings -Entries $script:AllEntries

        $filtered | Where-Object { $_.Level -eq 'INFO' } | Should -BeNullOrEmpty
        $filtered | Where-Object { $_.Level -eq 'DEBUG' } | Should -BeNullOrEmpty
    }

    It 'Should return empty array when no errors or warnings exist' {
        $infoOnly = @(
            [PSCustomObject]@{ Level = 'INFO'; Message = 'ok'; Timestamp = [datetime]'2024-01-15 10:00:00'; Source = 'app'; Format = 'syslog' }
        )
        $filtered = Select-ErrorsAndWarnings -Entries $infoOnly
        $filtered | Should -BeNullOrEmpty
    }
}

Describe 'LogAnalyzer - Frequency Table Generation' {
    BeforeAll {
        $script:FilteredEntries = @(
            [PSCustomObject]@{ Level = 'ERROR';   Message = 'DB failed';      Timestamp = [datetime]'2024-01-15 10:00:00'; Source = 'db'  }
            [PSCustomObject]@{ Level = 'ERROR';   Message = 'DB failed';      Timestamp = [datetime]'2024-01-15 10:05:00'; Source = 'db'  }
            [PSCustomObject]@{ Level = 'ERROR';   Message = 'DB failed';      Timestamp = [datetime]'2024-01-15 10:10:00'; Source = 'db'  }
            [PSCustomObject]@{ Level = 'WARNING'; Message = 'High CPU';       Timestamp = [datetime]'2024-01-15 10:01:00'; Source = 'sys' }
            [PSCustomObject]@{ Level = 'WARNING'; Message = 'High CPU';       Timestamp = [datetime]'2024-01-15 10:06:00'; Source = 'sys' }
            [PSCustomObject]@{ Level = 'ERROR';   Message = 'Disk write fail';Timestamp = [datetime]'2024-01-15 10:03:00'; Source = 'io'  }
        )
    }

    It 'Should produce a frequency table grouped by Level and Message' {
        $table = Get-ErrorFrequencyTable -Entries $script:FilteredEntries

        $table.Count | Should -Be 3
    }

    It 'Should count occurrences correctly' {
        $table = Get-ErrorFrequencyTable -Entries $script:FilteredEntries

        $dbEntry = $table | Where-Object { $_.Message -eq 'DB failed' }
        $dbEntry.Count | Should -Be 3

        $cpuEntry = $table | Where-Object { $_.Message -eq 'High CPU' }
        $cpuEntry.Count | Should -Be 2

        $diskEntry = $table | Where-Object { $_.Message -eq 'Disk write fail' }
        $diskEntry.Count | Should -Be 1
    }

    It 'Should record the first and last occurrence timestamps' {
        $table = Get-ErrorFrequencyTable -Entries $script:FilteredEntries

        $dbEntry = $table | Where-Object { $_.Message -eq 'DB failed' }
        $dbEntry.FirstSeen | Should -Be ([datetime]'2024-01-15 10:00:00')
        $dbEntry.LastSeen  | Should -Be ([datetime]'2024-01-15 10:10:00')
    }

    It 'Should include the Level in each frequency entry' {
        $table = Get-ErrorFrequencyTable -Entries $script:FilteredEntries

        $dbEntry = $table | Where-Object { $_.Message -eq 'DB failed' }
        $dbEntry.Level | Should -Be 'ERROR'
    }
}

Describe 'LogAnalyzer - Output Generation' {
    BeforeAll {
        $script:FrequencyTable = @(
            [PSCustomObject]@{
                Level     = 'ERROR'
                Message   = 'DB failed'
                Count     = 3
                FirstSeen = [datetime]'2024-01-15 10:00:00'
                LastSeen  = [datetime]'2024-01-15 10:10:00'
            }
            [PSCustomObject]@{
                Level     = 'WARNING'
                Message   = 'High CPU'
                Count     = 2
                FirstSeen = [datetime]'2024-01-15 10:01:00'
                LastSeen  = [datetime]'2024-01-15 10:06:00'
            }
        )
        $script:OutputDir = Join-Path $PSScriptRoot 'output'
        if (-not (Test-Path $script:OutputDir)) {
            New-Item -ItemType Directory -Path $script:OutputDir | Out-Null
        }
        $script:JsonOutputPath = Join-Path $script:OutputDir 'analysis.json'
    }

    AfterAll {
        if (Test-Path $script:OutputDir) {
            Remove-Item $script:OutputDir -Recurse -Force
        }
    }

    It 'Should write a JSON file with the frequency table' {
        Export-AnalysisJson -FrequencyTable $script:FrequencyTable -Path $script:JsonOutputPath

        Test-Path $script:JsonOutputPath | Should -BeTrue
    }

    It 'Should produce valid JSON that can be round-tripped' {
        Export-AnalysisJson -FrequencyTable $script:FrequencyTable -Path $script:JsonOutputPath

        $json = Get-Content $script:JsonOutputPath -Raw
        $parsed = $json | ConvertFrom-Json

        $parsed.Count | Should -Be 2
        $parsed[0].Level | Should -Be 'ERROR'
        $parsed[0].Count | Should -Be 3
    }

    It 'Should produce a non-empty human-readable text table' {
        $text = Format-AnalysisTable -FrequencyTable $script:FrequencyTable

        $text | Should -Not -BeNullOrEmpty
        $text | Should -Match 'ERROR'
        $text | Should -Match 'DB failed'
        $text | Should -Match '3'
    }

    It 'Should include column headers in the human-readable table' {
        $text = Format-AnalysisTable -FrequencyTable $script:FrequencyTable

        $text | Should -Match 'Level'
        $text | Should -Match 'Count'
        $text | Should -Match 'First'
    }
}

Describe 'LogAnalyzer - End-to-End Integration' {
    BeforeAll {
        $script:E2EFixtureDir = Join-Path $PSScriptRoot 'fixtures'
        if (-not (Test-Path $script:E2EFixtureDir)) {
            New-Item -ItemType Directory -Path $script:E2EFixtureDir | Out-Null
        }
        $script:E2ELogPath    = Join-Path $script:E2EFixtureDir 'e2e.log'
        $script:E2EOutputDir  = Join-Path $PSScriptRoot 'e2e-output'
        $script:E2EJsonPath   = Join-Path $script:E2EOutputDir 'analysis.json'

        # Write the sample log file used for integration
        New-SampleLogFile -Path $script:E2ELogPath

        if (-not (Test-Path $script:E2EOutputDir)) {
            New-Item -ItemType Directory -Path $script:E2EOutputDir | Out-Null
        }
    }

    AfterAll {
        if (Test-Path $script:E2ELogPath)   { Remove-Item $script:E2ELogPath   -Force }
        if (Test-Path $script:E2EOutputDir) { Remove-Item $script:E2EOutputDir -Recurse -Force }
    }

    It 'Should create the sample log fixture file with content' {
        Test-Path $script:E2ELogPath | Should -BeTrue
        (Get-Content $script:E2ELogPath).Count | Should -BeGreaterThan 0
    }

    It 'Should run the full analysis pipeline and produce a JSON output file' {
        Invoke-LogAnalysis -LogPath $script:E2ELogPath -OutputPath $script:E2EJsonPath

        Test-Path $script:E2EJsonPath | Should -BeTrue
        $json = Get-Content $script:E2EJsonPath -Raw | ConvertFrom-Json
        $json.Count | Should -BeGreaterThan 0
    }

    It 'Should produce a frequency table with correct structure in the JSON' {
        Invoke-LogAnalysis -LogPath $script:E2ELogPath -OutputPath $script:E2EJsonPath

        $json = Get-Content $script:E2EJsonPath -Raw | ConvertFrom-Json
        $entry = $json | Select-Object -First 1

        $entry.PSObject.Properties.Name | Should -Contain 'Level'
        $entry.PSObject.Properties.Name | Should -Contain 'Message'
        $entry.PSObject.Properties.Name | Should -Contain 'Count'
        $entry.PSObject.Properties.Name | Should -Contain 'FirstSeen'
        $entry.PSObject.Properties.Name | Should -Contain 'LastSeen'
    }
}
