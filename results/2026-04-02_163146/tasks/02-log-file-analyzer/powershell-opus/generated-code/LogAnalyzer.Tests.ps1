# LogAnalyzer.Tests.ps1
# Pester tests for the log file analyzer - written FIRST following TDD red/green/refactor.
# Each Describe block covers a distinct piece of functionality.

BeforeAll {
    # Source the module under test
    . "$PSScriptRoot/LogAnalyzer.ps1"
}

# ---------------------------------------------------------------------------
# TDD Round 1: Parsing individual log lines
# ---------------------------------------------------------------------------
Describe 'Parse-LogLine' {

    Context 'Syslog-style lines' {
        It 'parses a syslog ERROR line correctly' {
            $line = '2025-01-15 08:25:13 server01 app[5678]: ERROR: Database connection timeout after 30s'
            $result = Parse-LogLine -Line $line

            $result | Should -Not -BeNullOrEmpty
            $result.Timestamp | Should -Be ([datetime]'2025-01-15 08:25:13')
            $result.Level      | Should -Be 'ERROR'
            $result.Source     | Should -Be 'server01 app[5678]'
            $result.Message    | Should -Be 'Database connection timeout after 30s'
        }

        It 'parses a syslog WARNING line correctly' {
            $line = '2025-01-15 09:00:22 server02 kernel: WARNING: High memory usage detected (92%)'
            $result = Parse-LogLine -Line $line

            $result.Timestamp | Should -Be ([datetime]'2025-01-15 09:00:22')
            $result.Level      | Should -Be 'WARNING'
            $result.Source     | Should -Be 'server02 kernel'
            $result.Message    | Should -Be 'High memory usage detected (92%)'
        }

        It 'parses a syslog INFO line correctly' {
            $line = '2025-01-15 08:23:01 server01 sshd[1234]: INFO: Accepted publickey for admin from 192.168.1.100'
            $result = Parse-LogLine -Line $line

            $result.Level | Should -Be 'INFO'
        }
    }

    Context 'JSON-structured lines' {
        It 'parses a JSON ERROR line correctly' {
            $line = '{"timestamp":"2025-01-15T08:30:00Z","level":"ERROR","service":"api-gateway","message":"Upstream service unavailable","code":"ERR_UPSTREAM"}'
            $result = Parse-LogLine -Line $line

            $result | Should -Not -BeNullOrEmpty
            $result.Timestamp | Should -Be ([datetime]'2025-01-15T08:30:00Z')
            $result.Level      | Should -Be 'ERROR'
            $result.Source     | Should -Be 'api-gateway'
            $result.Message    | Should -Be 'Upstream service unavailable'
        }

        It 'parses a JSON WARNING line correctly' {
            $line = '{"timestamp":"2025-01-15T10:00:00Z","level":"WARNING","service":"api-gateway","message":"Rate limit approaching threshold","code":"WARN_RATE"}'
            $result = Parse-LogLine -Line $line

            $result.Level   | Should -Be 'WARNING'
            $result.Message | Should -Be 'Rate limit approaching threshold'
        }

        It 'parses a JSON INFO line correctly' {
            $line = '{"timestamp":"2025-01-15T08:30:05Z","level":"INFO","service":"api-gateway","message":"Health check passed"}'
            $result = Parse-LogLine -Line $line

            $result.Level | Should -Be 'INFO'
        }
    }

    Context 'Unparseable lines' {
        It 'returns $null for garbage input' {
            $result = Parse-LogLine -Line 'this is not a valid log line at all'
            $result | Should -BeNullOrEmpty
        }

        It 'returns $null for malformed JSON' {
            $result = Parse-LogLine -Line '{invalid json here'
            $result | Should -BeNullOrEmpty
        }

        It 'returns $null for empty string' {
            $result = Parse-LogLine -Line ''
            $result | Should -BeNullOrEmpty
        }

        It 'returns $null for $null input' {
            $result = Parse-LogLine -Line $null
            $result | Should -BeNullOrEmpty
        }
    }
}

# ---------------------------------------------------------------------------
# TDD Round 2: Reading and parsing an entire log file
# ---------------------------------------------------------------------------
Describe 'Read-LogFile' {

    It 'parses all lines from the sample log file' {
        $entries = Read-LogFile -Path "$PSScriptRoot/fixtures/sample.log"
        # sample.log has 16 lines total; 2 are pure INFO (non-error/warning)
        # but Read-LogFile should parse ALL recognisable lines
        $entries.Count | Should -BeGreaterThan 0
    }

    It 'skips unparseable lines in a malformed file without throwing' {
        { Read-LogFile -Path "$PSScriptRoot/fixtures/malformed.log" } | Should -Not -Throw
        $entries = Read-LogFile -Path "$PSScriptRoot/fixtures/malformed.log"
        # malformed.log has 2 valid lines out of 5
        $entries.Count | Should -Be 2
    }

    It 'returns an empty array for an empty file' {
        $entries = Read-LogFile -Path "$PSScriptRoot/fixtures/empty.log"
        $entries.Count | Should -Be 0
    }

    It 'throws a meaningful error when the file does not exist' {
        { Read-LogFile -Path "$PSScriptRoot/fixtures/nonexistent.log" } |
            Should -Throw '*does not exist*'
    }
}

# ---------------------------------------------------------------------------
# TDD Round 3: Filtering errors and warnings
# ---------------------------------------------------------------------------
Describe 'Get-ErrorsAndWarnings' {

    It 'extracts only ERROR and WARNING entries' {
        $entries = Read-LogFile -Path "$PSScriptRoot/fixtures/sample.log"
        $filtered = Get-ErrorsAndWarnings -Entries $entries

        $filtered | ForEach-Object {
            $_.Level | Should -BeIn @('ERROR', 'WARNING')
        }
    }

    It 'returns the correct count from the sample file' {
        $entries = Read-LogFile -Path "$PSScriptRoot/fixtures/sample.log"
        $filtered = Get-ErrorsAndWarnings -Entries $entries
        # Count of ERROR + WARNING lines in sample.log = 13
        $filtered.Count | Should -Be 13
    }

    It 'returns an empty array when there are no errors or warnings' {
        $entries = Read-LogFile -Path "$PSScriptRoot/fixtures/info-only.log"
        $filtered = Get-ErrorsAndWarnings -Entries $entries
        $filtered.Count | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# TDD Round 4: Building the frequency table
# ---------------------------------------------------------------------------
Describe 'Build-FrequencyTable' {

    BeforeAll {
        $script:entries = Read-LogFile -Path "$PSScriptRoot/fixtures/sample.log"
        $script:filtered = Get-ErrorsAndWarnings -Entries $script:entries
        $script:table = Build-FrequencyTable -Entries $script:filtered
    }

    It 'returns a non-empty collection' {
        $script:table.Count | Should -BeGreaterThan 0
    }

    It 'groups by the error/warning message text' {
        # "Database connection timeout after 30s" appears twice as ERROR
        $dbError = $script:table | Where-Object { $_.Message -eq 'Database connection timeout after 30s' }
        $dbError | Should -Not -BeNullOrEmpty
        $dbError.Count | Should -Be 2
        $dbError.Level | Should -Be 'ERROR'
    }

    It 'records the first occurrence timestamp' {
        $dbError = $script:table | Where-Object { $_.Message -eq 'Database connection timeout after 30s' }
        $dbError.FirstOccurrence | Should -Be ([datetime]'2025-01-15 08:25:13')
    }

    It 'records the last occurrence timestamp' {
        $dbError = $script:table | Where-Object { $_.Message -eq 'Database connection timeout after 30s' }
        $dbError.LastOccurrence | Should -Be ([datetime]'2025-01-15 09:45:33')
    }

    It 'tracks "Upstream service unavailable" with count 2' {
        $upstream = $script:table | Where-Object { $_.Message -eq 'Upstream service unavailable' }
        $upstream.Count | Should -Be 2
    }

    It 'includes both ERROR and WARNING type entries' {
        $levels = $script:table | Select-Object -ExpandProperty Level -Unique
        $levels | Should -Contain 'ERROR'
        $levels | Should -Contain 'WARNING'
    }
}

# ---------------------------------------------------------------------------
# TDD Round 5: Human-readable table output
# ---------------------------------------------------------------------------
Describe 'Format-FrequencyTable' {

    BeforeAll {
        $script:entries = Read-LogFile -Path "$PSScriptRoot/fixtures/sample.log"
        $script:filtered = Get-ErrorsAndWarnings -Entries $script:entries
        $script:table = Build-FrequencyTable -Entries $script:filtered
        $script:output = Format-FrequencyTable -Table $script:table
    }

    It 'returns a non-empty string' {
        $script:output | Should -Not -BeNullOrEmpty
    }

    It 'contains a header row' {
        $script:output | Should -Match 'Level'
        $script:output | Should -Match 'Count'
        $script:output | Should -Match 'Message'
    }

    It 'contains data from the frequency table' {
        $script:output | Should -Match 'Database connection timeout'
        $script:output | Should -Match 'Upstream service unavailable'
    }
}

# ---------------------------------------------------------------------------
# TDD Round 6: JSON output
# ---------------------------------------------------------------------------
Describe 'Export-AnalysisJson' {

    BeforeAll {
        $script:entries = Read-LogFile -Path "$PSScriptRoot/fixtures/sample.log"
        $script:filtered = Get-ErrorsAndWarnings -Entries $script:entries
        $script:table = Build-FrequencyTable -Entries $script:filtered
        $script:outPath = Join-Path $TestDrive 'analysis.json'
    }

    It 'creates a valid JSON file' {
        Export-AnalysisJson -Table $script:table -OutputPath $script:outPath
        Test-Path $script:outPath | Should -BeTrue
    }

    It 'writes valid JSON that can be deserialized' {
        Export-AnalysisJson -Table $script:table -OutputPath $script:outPath
        $json = Get-Content $script:outPath -Raw | ConvertFrom-Json
        $json | Should -Not -BeNullOrEmpty
    }

    It 'contains the correct number of entries' {
        Export-AnalysisJson -Table $script:table -OutputPath $script:outPath
        $json = Get-Content $script:outPath -Raw | ConvertFrom-Json
        $json.Count | Should -Be $script:table.Count
    }

    It 'preserves count and message fields' {
        Export-AnalysisJson -Table $script:table -OutputPath $script:outPath
        $json = Get-Content $script:outPath -Raw | ConvertFrom-Json
        $dbEntry = $json | Where-Object { $_.Message -eq 'Database connection timeout after 30s' }
        $dbEntry | Should -Not -BeNullOrEmpty
        $dbEntry.Count | Should -Be 2
    }
}

# ---------------------------------------------------------------------------
# TDD Round 7: Main entry point / orchestration
# ---------------------------------------------------------------------------
Describe 'Invoke-LogAnalysis' {

    It 'produces both table output and a JSON file' {
        $jsonPath = Join-Path $TestDrive 'result.json'
        $result = Invoke-LogAnalysis -LogPath "$PSScriptRoot/fixtures/sample.log" -JsonOutputPath $jsonPath

        # Should return the human-readable table string
        $result | Should -Not -BeNullOrEmpty

        # JSON file should exist
        Test-Path $jsonPath | Should -BeTrue
    }

    It 'throws a meaningful error for a missing log file' {
        { Invoke-LogAnalysis -LogPath '/no/such/file.log' -JsonOutputPath (Join-Path $TestDrive 'x.json') } |
            Should -Throw '*does not exist*'
    }

    It 'handles a file with no errors gracefully' {
        $jsonPath = Join-Path $TestDrive 'info-result.json'
        $result = Invoke-LogAnalysis -LogPath "$PSScriptRoot/fixtures/info-only.log" -JsonOutputPath $jsonPath

        # Should still produce output (indicating no errors found)
        $result | Should -Not -BeNullOrEmpty
        $result | Should -Match 'No errors or warnings found'
    }
}
