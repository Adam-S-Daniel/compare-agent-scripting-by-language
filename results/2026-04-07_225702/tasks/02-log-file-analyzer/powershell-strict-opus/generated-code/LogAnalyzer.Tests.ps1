# Import the module under test; strict mode is enforced inside the module itself
BeforeAll {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    . "$PSScriptRoot/LogAnalyzer.ps1"
}

Describe 'ConvertFrom-SyslogLine' {
    It 'parses a syslog-style ERROR line into a structured object' {
        $line = '2024-01-15 08:24:12 ERROR [app.db] Connection timeout after 30s: host=db01.internal port=5432'
        $result = ConvertFrom-SyslogLine -Line $line

        $result | Should -Not -BeNullOrEmpty
        $result.Timestamp | Should -Be '2024-01-15 08:24:12'
        $result.Level | Should -Be 'ERROR'
        $result.Source | Should -Be 'app.db'
        $result.Message | Should -Be 'Connection timeout after 30s: host=db01.internal port=5432'
    }

    It 'parses a syslog-style WARN line' {
        $line = '2024-01-15 08:23:05 WARN  [app.config] Deprecated config key used'
        $result = ConvertFrom-SyslogLine -Line $line

        $result.Level | Should -Be 'WARN'
        $result.Source | Should -Be 'app.config'
    }

    It 'returns $null for non-matching lines' {
        $result = ConvertFrom-SyslogLine -Line 'some random text'
        $result | Should -BeNullOrEmpty
    }
}

Describe 'ConvertFrom-JsonLogLine' {
    It 'parses a JSON log line into a structured object' {
        $line = '{"timestamp":"2024-01-15T08:25:33Z","level":"ERROR","service":"payment-gateway","message":"Transaction failed: insufficient funds","error_code":"PAY_001"}'
        $result = ConvertFrom-JsonLogLine -Line $line

        $result | Should -Not -BeNullOrEmpty
        $result.Timestamp | Should -Be '2024-01-15T08:25:33Z'
        $result.Level | Should -Be 'ERROR'
        $result.Source | Should -Be 'payment-gateway'
        $result.Message | Should -Be 'Transaction failed: insufficient funds'
    }

    It 'normalizes WARNING level to WARN' {
        $line = '{"timestamp":"2024-01-15T08:27:00Z","level":"WARNING","service":"notification-service","message":"Email delivery delayed"}'
        $result = ConvertFrom-JsonLogLine -Line $line

        $result.Level | Should -Be 'WARN'
    }

    It 'returns $null for non-JSON lines' {
        $result = ConvertFrom-JsonLogLine -Line 'not json at all'
        $result | Should -BeNullOrEmpty
    }
}

Describe 'Read-LogFile' {
    It 'reads a log file and returns parsed entries for all lines' {
        $fixturePath = "$PSScriptRoot/fixtures/sample.log"
        $results = Read-LogFile -Path $fixturePath

        # sample.log has 20 lines total, all should parse (syslog or JSON)
        $results.Count | Should -BeGreaterThan 0
    }

    It 'correctly identifies both syslog and JSON entries' {
        $fixturePath = "$PSScriptRoot/fixtures/sample.log"
        $results = Read-LogFile -Path $fixturePath

        # Check we got entries from both formats
        $syslogSources = $results | Where-Object { $_.Source -like 'app.*' }
        $jsonSources = $results | Where-Object { $_.Source -like '*-service' -or $_.Source -like '*-gateway' }

        $syslogSources.Count | Should -BeGreaterThan 0
        $jsonSources.Count | Should -BeGreaterThan 0
    }

    It 'throws on non-existent file' {
        { Read-LogFile -Path '/nonexistent/file.log' } | Should -Throw
    }
}

Describe 'Get-ErrorAndWarningEntries' {
    It 'filters to only ERROR and WARN entries' {
        $entries = @(
            [PSCustomObject]@{ Timestamp = '2024-01-15 08:23:01'; Level = 'INFO'; Source = 'app.server'; Message = 'started' }
            [PSCustomObject]@{ Timestamp = '2024-01-15 08:24:12'; Level = 'ERROR'; Source = 'app.db'; Message = 'timeout' }
            [PSCustomObject]@{ Timestamp = '2024-01-15 08:23:05'; Level = 'WARN'; Source = 'app.config'; Message = 'deprecated' }
        )

        $result = Get-ErrorAndWarningEntries -Entries $entries
        $result.Count | Should -Be 2
        $result[0].Level | Should -Be 'ERROR'
        $result[1].Level | Should -Be 'WARN'
    }

    It 'returns empty array when no errors or warnings exist' {
        $entries = @(
            [PSCustomObject]@{ Timestamp = '2024-01-15 08:23:01'; Level = 'INFO'; Source = 'app.server'; Message = 'started' }
        )

        $result = Get-ErrorAndWarningEntries -Entries $entries
        @($result).Count | Should -Be 0
    }
}

Describe 'Get-FrequencyTable' {
    It 'groups entries by error type and computes count, first, and last timestamps' {
        $entries = @(
            [PSCustomObject]@{ Timestamp = '2024-01-15 08:24:12'; Level = 'ERROR'; Source = 'app.db'; Message = 'Connection timeout' }
            [PSCustomObject]@{ Timestamp = '2024-01-15 08:28:45'; Level = 'ERROR'; Source = 'app.db'; Message = 'Connection timeout' }
            [PSCustomObject]@{ Timestamp = '2024-01-15 08:38:00'; Level = 'ERROR'; Source = 'app.db'; Message = 'Connection timeout' }
            [PSCustomObject]@{ Timestamp = '2024-01-15 08:23:05'; Level = 'WARN'; Source = 'app.config'; Message = 'Deprecated config' }
        )

        $result = Get-FrequencyTable -Entries $entries

        $result.Count | Should -Be 2

        $dbError = $result | Where-Object { $_.ErrorType -eq 'ERROR [app.db] Connection timeout' }
        $dbError.Count | Should -Be 3
        $dbError.FirstSeen | Should -Be '2024-01-15 08:24:12'
        $dbError.LastSeen | Should -Be '2024-01-15 08:38:00'

        $configWarn = $result | Where-Object { $_.ErrorType -eq 'WARN [app.config] Deprecated config' }
        $configWarn.Count | Should -Be 1
    }
}

Describe 'Format-FrequencyTable' {
    It 'returns a formatted string table' {
        $tableData = @(
            [PSCustomObject]@{ ErrorType = 'ERROR [app.db] Timeout'; Count = [int]3; FirstSeen = '2024-01-15 08:24:12'; LastSeen = '2024-01-15 08:38:00' }
        )

        $result = Format-FrequencyTable -TableData $tableData
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeLike '*ERROR*app.db*Timeout*'
        $result | Should -BeLike '*3*'
    }
}

Describe 'Export-FrequencyTableJson' {
    It 'writes valid JSON to the specified path' {
        $tableData = @(
            [PSCustomObject]@{ ErrorType = 'ERROR [app.db] Timeout'; Count = [int]3; FirstSeen = '2024-01-15 08:24:12'; LastSeen = '2024-01-15 08:38:00' }
        )
        $outPath = Join-Path $TestDrive 'output.json'

        Export-FrequencyTableJson -TableData $tableData -OutputPath $outPath

        Test-Path $outPath | Should -BeTrue
        [array]$json = Get-Content -Path $outPath -Raw | ConvertFrom-Json
        $json.Count | Should -Be 1
        $json[0].ErrorType | Should -Be 'ERROR [app.db] Timeout'
        $json[0].Count | Should -Be 3
    }
}

Describe 'Invoke-LogAnalysis (integration)' {
    It 'runs end-to-end on the sample fixture and produces both outputs' {
        $fixturePath = "$PSScriptRoot/fixtures/sample.log"
        $jsonOutPath = Join-Path $TestDrive 'analysis.json'

        $tableText = Invoke-LogAnalysis -LogPath $fixturePath -JsonOutputPath $jsonOutPath

        # Human-readable table should contain data
        $tableText | Should -Not -BeNullOrEmpty

        # JSON file should exist and be valid
        Test-Path $jsonOutPath | Should -BeTrue
        $json = Get-Content -Path $jsonOutPath -Raw | ConvertFrom-Json
        $json.Count | Should -BeGreaterThan 0

        # Verify known error types appear
        $errorTypes = $json | ForEach-Object { $_.ErrorType }
        $errorTypes | Should -Contain 'ERROR [app.db] Connection timeout after 30s: host=db01.internal port=5432'
    }
}
