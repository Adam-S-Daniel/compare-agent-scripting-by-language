Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import the module under test
$modulePath = Join-Path $PSScriptRoot '..' 'LogAnalyzer.psm1'
Import-Module $modulePath -Force

# Resolve fixture paths
$fixturesDir = Join-Path $PSScriptRoot '..' 'fixtures'

Describe 'ConvertFrom-LogLine - Syslog format parsing' {
    # RED: These tests should fail first since ConvertFrom-LogLine doesn't exist yet

    It 'Should parse a syslog ERROR line correctly' {
        $line = '2024-01-15 08:23:01 server01 sshd[1234]: ERROR: Failed to authenticate user admin from 192.168.1.100'
        $result = ConvertFrom-LogLine -Line $line

        $result | Should -Not -BeNullOrEmpty
        $result.Timestamp | Should -Be ([datetime]'2024-01-15 08:23:01')
        $result.Level | Should -Be 'ERROR'
        $result.Source | Should -Be 'sshd'
        $result.Message | Should -Be 'Failed to authenticate user admin from 192.168.1.100'
        $result.Host | Should -Be 'server01'
        $result.Format | Should -Be 'syslog'
    }

    It 'Should parse a syslog WARNING line correctly' {
        $line = '2024-01-15 08:23:05 server01 kernel: WARNING: disk usage on /dev/sda1 exceeds 90%'
        $result = ConvertFrom-LogLine -Line $line

        $result.Level | Should -Be 'WARNING'
        $result.Source | Should -Be 'kernel'
        $result.Message | Should -Be 'disk usage on /dev/sda1 exceeds 90%'
    }

    It 'Should parse a syslog INFO line correctly' {
        $line = '2024-01-15 08:24:00 server01 nginx[5678]: INFO: Request served successfully GET /api/health 200'
        $result = ConvertFrom-LogLine -Line $line

        $result.Level | Should -Be 'INFO'
        $result.Source | Should -Be 'nginx'
    }
}

Describe 'ConvertFrom-LogLine - JSON format parsing' {
    It 'Should parse a JSON ERROR line correctly' {
        $line = '{"timestamp":"2024-01-15T08:25:00Z","level":"ERROR","service":"auth-service","message":"Connection refused to database","host":"server02"}'
        $result = ConvertFrom-LogLine -Line $line

        $result | Should -Not -BeNullOrEmpty
        $result.Timestamp | Should -Be ([datetime]'2024-01-15T08:25:00Z')
        $result.Level | Should -Be 'ERROR'
        $result.Source | Should -Be 'auth-service'
        $result.Message | Should -Be 'Connection refused to database'
        $result.Host | Should -Be 'server02'
        $result.Format | Should -Be 'json'
    }

    It 'Should parse a JSON WARNING line correctly' {
        $line = '{"timestamp":"2024-01-15T08:25:30Z","level":"WARNING","service":"auth-service","message":"Retry attempt 1 for database connection","host":"server02"}'
        $result = ConvertFrom-LogLine -Line $line

        $result.Level | Should -Be 'WARNING'
        $result.Source | Should -Be 'auth-service'
    }
}

Describe 'ConvertFrom-LogLine - Edge cases' {
    It 'Should return null for empty lines' {
        $result = ConvertFrom-LogLine -Line ''
        $result | Should -BeNullOrEmpty
    }

    It 'Should return null for whitespace-only lines' {
        $result = ConvertFrom-LogLine -Line '   '
        $result | Should -BeNullOrEmpty
    }

    It 'Should return an unparseable entry for malformed lines' {
        $result = ConvertFrom-LogLine -Line 'this is not a valid log line'
        $result | Should -Not -BeNullOrEmpty
        $result.Level | Should -Be 'UNKNOWN'
        $result.Format | Should -Be 'unknown'
    }
}

Describe 'Read-LogFile - File reading and parsing' {
    It 'Should parse all lines from the sample log file' {
        $logPath = Join-Path $fixturesDir 'sample.log'
        $results = @(Read-LogFile -Path $logPath)

        # sample.log has 16 non-empty lines
        $results.Count | Should -Be 16
    }

    It 'Should handle an empty log file gracefully' {
        $logPath = Join-Path $fixturesDir 'empty.log'
        $results = @(Read-LogFile -Path $logPath)

        $results.Count | Should -Be 0
    }

    It 'Should throw for a non-existent file' {
        { Read-LogFile -Path '/nonexistent/file.log' } | Should -Throw
    }

    It 'Should parse JSON-only log files' {
        $logPath = Join-Path $fixturesDir 'json-only.log'
        $results = @(Read-LogFile -Path $logPath)

        $results.Count | Should -Be 4
        $results[0].Format | Should -Be 'json'
    }

    It 'Should parse syslog-only log files' {
        $logPath = Join-Path $fixturesDir 'syslog-only.log'
        $results = @(Read-LogFile -Path $logPath)

        $results.Count | Should -Be 5
        $results[0].Format | Should -Be 'syslog'
    }
}

Describe 'Select-ErrorAndWarning - Filtering' {
    It 'Should filter only ERROR and WARNING entries' {
        $logPath = Join-Path $fixturesDir 'sample.log'
        $allEntries = @(Read-LogFile -Path $logPath)
        $filtered = @(Select-ErrorAndWarning -Entries $allEntries)

        # Count errors and warnings in sample.log:
        # ERRORs: lines 1, 4, 7, 8, 11, 14, 15 = 7 (syslog: 1,8,14; json: 4,7,11,15) => actually recount
        # Let me count: syslog ERRORs at lines 1,8,14 = 3; JSON ERRORs at lines 4,7,11,15 = 4 => 7 ERRORs
        # WARNINGs: lines 2,5,10,12,13,16 => syslog: 2,10,12 = 3; JSON: 5,13 = 2; syslog 16 = 1 => 6 WARNINGs
        # Total = 13
        $filtered.Count | Should -Be 13
    }

    It 'Should return empty array when no errors or warnings exist' {
        # Create entries with only INFO level
        $entries = @(
            [PSCustomObject]@{ Timestamp = [datetime]'2024-01-01'; Level = 'INFO'; Source = 'test'; Message = 'ok'; Host = 'h1'; Format = 'syslog' }
        )
        $filtered = @(Select-ErrorAndWarning -Entries $entries)

        $filtered.Count | Should -Be 0
    }

    It 'Should preserve all fields in filtered entries' {
        $entries = @(
            [PSCustomObject]@{ Timestamp = [datetime]'2024-01-01 10:00:00'; Level = 'ERROR'; Source = 'myapp'; Message = 'broken'; Host = 'host1'; Format = 'syslog' }
        )
        $filtered = @(Select-ErrorAndWarning -Entries $entries)

        $filtered[0].Source | Should -Be 'myapp'
        $filtered[0].Message | Should -Be 'broken'
    }
}

Describe 'Get-ErrorFrequencyTable - Frequency analysis' {
    It 'Should group errors by message and count occurrences' {
        $entries = @(
            [PSCustomObject]@{ Timestamp = [datetime]'2024-01-15 08:23:01'; Level = 'ERROR'; Source = 'sshd'; Message = 'Failed to authenticate'; Host = 'h1'; Format = 'syslog' }
            [PSCustomObject]@{ Timestamp = [datetime]'2024-01-15 08:28:00'; Level = 'ERROR'; Source = 'sshd'; Message = 'Failed to authenticate'; Host = 'h2'; Format = 'syslog' }
            [PSCustomObject]@{ Timestamp = [datetime]'2024-01-15 08:25:00'; Level = 'ERROR'; Source = 'auth'; Message = 'Connection refused'; Host = 'h1'; Format = 'json' }
        )
        $table = @(Get-ErrorFrequencyTable -Entries $entries)

        $table.Count | Should -Be 2

        $authFailure = $table | Where-Object { $_.Message -eq 'Failed to authenticate' }
        $authFailure.Count | Should -Be 2
        $authFailure.FirstOccurrence | Should -Be ([datetime]'2024-01-15 08:23:01')
        $authFailure.LastOccurrence | Should -Be ([datetime]'2024-01-15 08:28:00')
    }

    It 'Should include level in the frequency table' {
        $entries = @(
            [PSCustomObject]@{ Timestamp = [datetime]'2024-01-15 08:00:00'; Level = 'WARNING'; Source = 'kern'; Message = 'disk full'; Host = 'h1'; Format = 'syslog' }
            [PSCustomObject]@{ Timestamp = [datetime]'2024-01-15 09:00:00'; Level = 'WARNING'; Source = 'kern'; Message = 'disk full'; Host = 'h1'; Format = 'syslog' }
        )
        $table = @(Get-ErrorFrequencyTable -Entries $entries)

        $table[0].Level | Should -Be 'WARNING'
        $table[0].Count | Should -Be 2
    }

    It 'Should return empty array for empty input' {
        $table = @(Get-ErrorFrequencyTable -Entries @())
        $table.Count | Should -Be 0
    }

    It 'Should sort by count descending' {
        $entries = @(
            [PSCustomObject]@{ Timestamp = [datetime]'2024-01-15 08:00:00'; Level = 'ERROR'; Source = 'a'; Message = 'rare error'; Host = 'h1'; Format = 'syslog' }
            [PSCustomObject]@{ Timestamp = [datetime]'2024-01-15 08:01:00'; Level = 'ERROR'; Source = 'a'; Message = 'common error'; Host = 'h1'; Format = 'syslog' }
            [PSCustomObject]@{ Timestamp = [datetime]'2024-01-15 08:02:00'; Level = 'ERROR'; Source = 'a'; Message = 'common error'; Host = 'h1'; Format = 'syslog' }
            [PSCustomObject]@{ Timestamp = [datetime]'2024-01-15 08:03:00'; Level = 'ERROR'; Source = 'a'; Message = 'common error'; Host = 'h1'; Format = 'syslog' }
        )
        $table = @(Get-ErrorFrequencyTable -Entries $entries)

        $table[0].Message | Should -Be 'common error'
        $table[0].Count | Should -Be 3
        $table[1].Count | Should -Be 1
    }
}

Describe 'Format-AnalysisTable - Human-readable output' {
    It 'Should produce formatted table string output' {
        $tableData = @(
            [PSCustomObject]@{ Level = 'ERROR'; Message = 'Connection refused'; Count = [int]3; FirstOccurrence = [datetime]'2024-01-15 08:25:00'; LastOccurrence = [datetime]'2024-01-15 08:31:00' }
            [PSCustomObject]@{ Level = 'WARNING'; Message = 'disk full'; Count = [int]2; FirstOccurrence = [datetime]'2024-01-15 08:23:05'; LastOccurrence = [datetime]'2024-01-15 08:30:00' }
        )
        $output = Format-AnalysisTable -FrequencyTable $tableData

        $output | Should -Not -BeNullOrEmpty
        # Should contain header elements
        $output | Should -Match 'Level'
        $output | Should -Match 'Message'
        $output | Should -Match 'Count'
        $output | Should -Match 'First Occurrence'
        $output | Should -Match 'Last Occurrence'
        # Should contain actual data
        $output | Should -Match 'Connection refused'
        $output | Should -Match 'ERROR'
    }

    It 'Should handle empty frequency table gracefully' {
        $output = Format-AnalysisTable -FrequencyTable @()
        $output | Should -Not -BeNullOrEmpty
        $output | Should -Match 'No error or warning entries found'
    }
}

Describe 'Export-AnalysisJson - JSON output' {
    It 'Should write valid JSON to a file' {
        $tableData = @(
            [PSCustomObject]@{ Level = 'ERROR'; Message = 'test error'; Count = [int]1; FirstOccurrence = [datetime]'2024-01-15 08:25:00'; LastOccurrence = [datetime]'2024-01-15 08:25:00' }
        )
        $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "test-output-$(New-Guid).json"

        try {
            Export-AnalysisJson -FrequencyTable $tableData -OutputPath $tempFile

            Test-Path $tempFile | Should -BeTrue
            $content = Get-Content -Path $tempFile -Raw
            # Should be valid JSON
            $parsed = $content | ConvertFrom-Json
            $parsed | Should -Not -BeNullOrEmpty
        }
        finally {
            if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        }
    }

    It 'Should include summary metadata in JSON output' {
        $tableData = @(
            [PSCustomObject]@{ Level = 'ERROR'; Message = 'err1'; Count = [int]3; FirstOccurrence = [datetime]'2024-01-15 08:00:00'; LastOccurrence = [datetime]'2024-01-15 09:00:00' }
            [PSCustomObject]@{ Level = 'WARNING'; Message = 'warn1'; Count = [int]2; FirstOccurrence = [datetime]'2024-01-15 08:30:00'; LastOccurrence = [datetime]'2024-01-15 08:45:00' }
        )
        $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "test-output-$(New-Guid).json"

        try {
            Export-AnalysisJson -FrequencyTable $tableData -OutputPath $tempFile

            $parsed = Get-Content -Path $tempFile -Raw | ConvertFrom-Json
            $parsed.summary | Should -Not -BeNullOrEmpty
            $parsed.summary.total_unique_issues | Should -Be 2
            $parsed.summary.total_occurrences | Should -Be 5
            $parsed.entries | Should -Not -BeNullOrEmpty
            $parsed.entries.Count | Should -Be 2
        }
        finally {
            if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        }
    }
}

Describe 'Invoke-LogAnalysis - Integration test' {
    It 'Should analyze a log file and produce both outputs' {
        $logPath = Join-Path $fixturesDir 'sample.log'
        $tempJson = Join-Path ([System.IO.Path]::GetTempPath()) "integration-test-$(New-Guid).json"

        try {
            $result = Invoke-LogAnalysis -Path $logPath -JsonOutputPath $tempJson

            # Should return the human-readable table
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match 'ERROR'

            # Should create the JSON file
            Test-Path $tempJson | Should -BeTrue
            $jsonContent = Get-Content -Path $tempJson -Raw | ConvertFrom-Json
            $jsonContent.entries.Count | Should -BeGreaterThan 0
        }
        finally {
            if (Test-Path $tempJson) { Remove-Item $tempJson -Force }
        }
    }

    It 'Should work with the syslog-only fixture' {
        $logPath = Join-Path $fixturesDir 'syslog-only.log'
        $tempJson = Join-Path ([System.IO.Path]::GetTempPath()) "integration-test-$(New-Guid).json"

        try {
            $result = Invoke-LogAnalysis -Path $logPath -JsonOutputPath $tempJson
            $result | Should -Not -BeNullOrEmpty

            $jsonContent = Get-Content -Path $tempJson -Raw | ConvertFrom-Json
            $jsonContent.entries.Count | Should -BeGreaterThan 0
        }
        finally {
            if (Test-Path $tempJson) { Remove-Item $tempJson -Force }
        }
    }

    It 'Should work with the JSON-only fixture' {
        $logPath = Join-Path $fixturesDir 'json-only.log'
        $tempJson = Join-Path ([System.IO.Path]::GetTempPath()) "integration-test-$(New-Guid).json"

        try {
            $result = Invoke-LogAnalysis -Path $logPath -JsonOutputPath $tempJson
            $result | Should -Not -BeNullOrEmpty

            $jsonContent = Get-Content -Path $tempJson -Raw | ConvertFrom-Json
            $jsonContent.entries.Count | Should -BeGreaterThan 0
        }
        finally {
            if (Test-Path $tempJson) { Remove-Item $tempJson -Force }
        }
    }

    It 'Should handle empty log file gracefully' {
        $logPath = Join-Path $fixturesDir 'empty.log'
        $tempJson = Join-Path ([System.IO.Path]::GetTempPath()) "integration-test-$(New-Guid).json"

        try {
            $result = Invoke-LogAnalysis -Path $logPath -JsonOutputPath $tempJson
            $result | Should -Match 'No error or warning entries found'
        }
        finally {
            if (Test-Path $tempJson) { Remove-Item $tempJson -Force }
        }
    }
}
