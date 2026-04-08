# LogAnalyzer.Tests.ps1 - TDD tests for log file analyzer
# Uses Pester to verify parsing, filtering, frequency analysis, and output generation.

BeforeAll {
    . "$PSScriptRoot/LogAnalyzer.ps1"
}

Describe "Parse-LogLine" {
    Context "Syslog-style lines" {
        It "parses a standard syslog ERROR line" {
            $line = "2024-01-15 08:23:01 ERROR [AuthService] Authentication failed for user admin - invalid credentials"
            $result = Parse-LogLine $line
            $result | Should -Not -BeNullOrEmpty
            $result.Timestamp | Should -Be "2024-01-15 08:23:01"
            $result.Level | Should -Be "ERROR"
            $result.Source | Should -Be "AuthService"
            $result.Message | Should -Be "Authentication failed for user admin - invalid credentials"
        }

        It "parses a standard syslog WARNING line" {
            $line = "2024-01-15 08:24:12 WARNING [DiskMonitor] Disk usage at 85% on /dev/sda1"
            $result = Parse-LogLine $line
            $result.Level | Should -Be "WARNING"
            $result.Source | Should -Be "DiskMonitor"
        }

        It "parses a standard syslog INFO line" {
            $line = "2024-01-15 08:23:05 INFO [AuthService] User jdoe logged in successfully"
            $result = Parse-LogLine $line
            $result.Level | Should -Be "INFO"
        }
    }

    Context "JSON-structured lines" {
        It "parses a JSON log entry" {
            $line = '{"timestamp":"2024-01-15T08:26:00Z","level":"ERROR","service":"PaymentGateway","message":"Payment processing timeout after 30s","code":"PG-5001"}'
            $result = Parse-LogLine $line
            $result | Should -Not -BeNullOrEmpty
            $result.Timestamp | Should -Be "2024-01-15T08:26:00Z"
            $result.Level | Should -Be "ERROR"
            $result.Source | Should -Be "PaymentGateway"
            $result.Message | Should -Be "Payment processing timeout after 30s"
        }
    }

    Context "Unparseable lines" {
        It "returns null for garbage input" {
            $result = Parse-LogLine "this is not a log line"
            $result | Should -BeNullOrEmpty
        }

        It "returns null for empty input" {
            $result = Parse-LogLine ""
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe "Get-LogEntries" {
    It "reads and parses all lines from a log file" {
        $entries = Get-LogEntries -Path "$PSScriptRoot/fixtures/sample.log"
        # 16 total lines, 1 blank = 16 parseable (all lines match one format)
        $entries.Count | Should -Be 16
    }

    It "throws a meaningful error for a missing file" {
        { Get-LogEntries -Path "/nonexistent/file.log" } | Should -Throw "*does not exist*"
    }
}

Describe "Select-ErrorsAndWarnings" {
    It "filters to only ERROR and WARNING entries" {
        $entries = @(
            [PSCustomObject]@{ Timestamp = "t1"; Level = "ERROR";   Source = "A"; Message = "m1" }
            [PSCustomObject]@{ Timestamp = "t2"; Level = "INFO";    Source = "B"; Message = "m2" }
            [PSCustomObject]@{ Timestamp = "t3"; Level = "WARNING"; Source = "C"; Message = "m3" }
            [PSCustomObject]@{ Timestamp = "t4"; Level = "DEBUG";   Source = "D"; Message = "m4" }
        )
        $filtered = Select-ErrorsAndWarnings $entries
        $filtered.Count | Should -Be 2
        $filtered[0].Level | Should -Be "ERROR"
        $filtered[1].Level | Should -Be "WARNING"
    }

    It "returns empty array when no errors or warnings exist" {
        $entries = @(
            [PSCustomObject]@{ Timestamp = "t1"; Level = "INFO"; Source = "A"; Message = "m1" }
        )
        $filtered = Select-ErrorsAndWarnings $entries
        $filtered.Count | Should -Be 0
    }
}

Describe "Get-FrequencyTable" {
    It "groups entries by source+message and counts occurrences" {
        $entries = @(
            [PSCustomObject]@{ Timestamp = "2024-01-15 08:00:00"; Level = "ERROR"; Source = "Auth"; Message = "Login failed" }
            [PSCustomObject]@{ Timestamp = "2024-01-15 09:00:00"; Level = "ERROR"; Source = "Auth"; Message = "Login failed" }
            [PSCustomObject]@{ Timestamp = "2024-01-15 10:00:00"; Level = "ERROR"; Source = "Auth"; Message = "Login failed" }
            [PSCustomObject]@{ Timestamp = "2024-01-15 08:30:00"; Level = "WARNING"; Source = "Disk"; Message = "Low space" }
        )
        $table = Get-FrequencyTable $entries
        $table.Count | Should -Be 2

        $authEntry = $table | Where-Object { $_.Source -eq "Auth" }
        $authEntry.Count | Should -Be 3
        $authEntry.FirstOccurrence | Should -Be "2024-01-15 08:00:00"
        $authEntry.LastOccurrence | Should -Be "2024-01-15 10:00:00"
        $authEntry.Level | Should -Be "ERROR"
        $authEntry.ErrorType | Should -Be "[Auth] Login failed"
    }

    It "handles a single entry" {
        $entries = @(
            [PSCustomObject]@{ Timestamp = "2024-01-15 08:00:00"; Level = "ERROR"; Source = "X"; Message = "fail" }
        )
        $table = Get-FrequencyTable $entries
        $table.Count | Should -Be 1
        $table[0].Count | Should -Be 1
        $table[0].FirstOccurrence | Should -Be "2024-01-15 08:00:00"
        $table[0].LastOccurrence | Should -Be "2024-01-15 08:00:00"
    }

    It "returns results sorted by count descending" {
        $entries = @(
            [PSCustomObject]@{ Timestamp = "t1"; Level = "ERROR"; Source = "A"; Message = "m1" }
            [PSCustomObject]@{ Timestamp = "t2"; Level = "ERROR"; Source = "B"; Message = "m2" }
            [PSCustomObject]@{ Timestamp = "t3"; Level = "ERROR"; Source = "B"; Message = "m2" }
            [PSCustomObject]@{ Timestamp = "t4"; Level = "ERROR"; Source = "B"; Message = "m2" }
        )
        $table = Get-FrequencyTable $entries
        $table[0].Count | Should -Be 3
        $table[0].Source | Should -Be "B"
    }
}

Describe "Format-FrequencyTable" {
    It "produces a human-readable table string with header and rows" {
        $table = @(
            [PSCustomObject]@{ ErrorType = "[Auth] Login failed"; Level = "ERROR"; Source = "Auth"; Message = "Login failed"; Count = 3; FirstOccurrence = "2024-01-15 08:00:00"; LastOccurrence = "2024-01-15 10:00:00" }
            [PSCustomObject]@{ ErrorType = "[Disk] Low space"; Level = "WARNING"; Source = "Disk"; Message = "Low space"; Count = 1; FirstOccurrence = "2024-01-15 09:00:00"; LastOccurrence = "2024-01-15 09:00:00" }
        )
        $output = Format-FrequencyTable $table
        $output | Should -Not -BeNullOrEmpty
        # Should contain the header labels
        $output | Should -Match "Count"
        $output | Should -Match "Level"
        $output | Should -Match "Error Type"
        $output | Should -Match "First Occurrence"
        $output | Should -Match "Last Occurrence"
        # Should contain actual data
        $output | Should -Match "Login failed"
        $output | Should -Match "Low space"
    }
}

Describe "Export-AnalysisJson" {
    BeforeAll {
        $script:testOutputPath = Join-Path $TestDrive "analysis.json"
    }

    It "writes valid JSON to a file" {
        $table = @(
            [PSCustomObject]@{ ErrorType = "[Auth] Login failed"; Level = "ERROR"; Source = "Auth"; Message = "Login failed"; Count = 3; FirstOccurrence = "2024-01-15 08:00:00"; LastOccurrence = "2024-01-15 10:00:00" }
        )
        Export-AnalysisJson -FrequencyTable $table -OutputPath $script:testOutputPath
        Test-Path $script:testOutputPath | Should -Be $true

        $json = Get-Content $script:testOutputPath -Raw | ConvertFrom-Json
        $json.summary | Should -Not -BeNullOrEmpty
        $json.summary.total_error_types | Should -Be 1
        $json.entries.Count | Should -Be 1
        $json.entries[0].error_type | Should -Be "[Auth] Login failed"
        $json.entries[0].count | Should -Be 3
    }

    It "includes analysis metadata" {
        $table = @(
            [PSCustomObject]@{ ErrorType = "[A] m1"; Level = "ERROR"; Source = "A"; Message = "m1"; Count = 2; FirstOccurrence = "t1"; LastOccurrence = "t2" }
        )
        Export-AnalysisJson -FrequencyTable $table -OutputPath $script:testOutputPath
        $json = Get-Content $script:testOutputPath -Raw | ConvertFrom-Json
        $json.summary.generated_at | Should -Not -BeNullOrEmpty
        $json.summary.total_occurrences | Should -Be 2
    }
}

Describe "Invoke-LogAnalysis (integration)" {
    BeforeAll {
        $script:jsonOut = Join-Path $TestDrive "integration-output.json"
    }

    It "runs the full pipeline on the sample fixture and produces correct output" {
        $result = Invoke-LogAnalysis -Path "$PSScriptRoot/fixtures/sample.log" -JsonOutputPath $script:jsonOut
        # The result should be the formatted table string
        $result | Should -Not -BeNullOrEmpty
        $result | Should -Match "Count"

        # JSON file should be created
        Test-Path $script:jsonOut | Should -Be $true
        $json = Get-Content $script:jsonOut -Raw | ConvertFrom-Json

        # From sample.log: we have 11 error/warning entries across several types
        $json.summary.total_error_types | Should -BeGreaterThan 0
        $json.summary.total_occurrences | Should -Be 13
    }

    It "handles an empty log file gracefully" {
        $emptyLog = Join-Path $TestDrive "empty.log"
        Set-Content -Path $emptyLog -Value ""
        $emptyJsonOut = Join-Path $TestDrive "empty-output.json"

        $result = Invoke-LogAnalysis -Path $emptyLog -JsonOutputPath $emptyJsonOut
        $result | Should -Match "No errors or warnings found"
    }
}
