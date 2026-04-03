# LogAnalyzer.Tests.ps1
# TDD test suite for the Log File Analyzer
# Tests are written FIRST (red), then implementation follows (green)

# Ensure Pester 5.x is available
$pesterModule = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pesterModule -or $pesterModule.Version.Major -lt 5) {
    Write-Host "Installing Pester 5.x..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 5.0.0 -Scope CurrentUser
}
Import-Module Pester -MinimumVersion 5.0.0

# Source the implementation (will fail until LogAnalyzer.ps1 exists)
. "$PSScriptRoot/LogAnalyzer.ps1"

# ============================================================
# RED PHASE 1: Parse syslog-style log lines
# Format: "2024-01-15 10:23:45 LEVEL component: message"
# ============================================================
Describe "Parse-SyslogLine" {
    It "parses a syslog ERROR line correctly" {
        $line = "2024-01-15 10:23:45 ERROR auth: Login failed for user admin"
        $result = Parse-SyslogLine -Line $line

        $result | Should -Not -BeNullOrEmpty
        $result.Timestamp | Should -Be ([datetime]"2024-01-15 10:23:45")
        $result.Level     | Should -Be "ERROR"
        $result.Component | Should -Be "auth"
        $result.Message   | Should -Be "Login failed for user admin"
        $result.Format    | Should -Be "syslog"
    }

    It "parses a syslog WARNING line correctly" {
        $line = "2024-01-15 10:24:00 WARNING disk: Disk usage at 90%"
        $result = Parse-SyslogLine -Line $line

        $result.Level   | Should -Be "WARNING"
        $result.Message | Should -Be "Disk usage at 90%"
    }

    It "parses a syslog INFO line correctly" {
        $line = "2024-01-15 10:25:00 INFO app: Server started on port 8080"
        $result = Parse-SyslogLine -Line $line

        $result.Level | Should -Be "INFO"
    }

    It "returns null for lines that don't match syslog format" {
        $line = "this is not a syslog line"
        $result = Parse-SyslogLine -Line $line
        $result | Should -BeNullOrEmpty
    }
}

# ============================================================
# RED PHASE 2: Parse JSON-structured log lines
# Format: {"timestamp":"...","level":"...","component":"...","message":"..."}
# ============================================================
Describe "Parse-JsonLogLine" {
    It "parses a JSON ERROR line correctly" {
        $line = '{"timestamp":"2024-01-15T10:23:45Z","level":"ERROR","component":"auth","message":"Authentication failed"}'
        $result = Parse-JsonLogLine -Line $line

        $result | Should -Not -BeNullOrEmpty
        $result.Level     | Should -Be "ERROR"
        $result.Component | Should -Be "auth"
        $result.Message   | Should -Be "Authentication failed"
        $result.Format    | Should -Be "json"
    }

    It "parses a JSON WARNING line correctly" {
        $line = '{"timestamp":"2024-01-15T10:24:00Z","level":"WARN","component":"db","message":"Slow query detected"}'
        $result = Parse-JsonLogLine -Line $line

        # WARN should be normalized to WARNING
        $result.Level | Should -Be "WARNING"
    }

    It "returns null for lines that are not valid JSON" {
        $line = "not json at all"
        $result = Parse-JsonLogLine -Line $line
        $result | Should -BeNullOrEmpty
    }

    It "returns null for JSON without required fields" {
        $line = '{"foo":"bar"}'
        $result = Parse-JsonLogLine -Line $line
        $result | Should -BeNullOrEmpty
    }
}

# ============================================================
# RED PHASE 3: Parse a mixed log file (auto-detect format per line)
# ============================================================
Describe "Parse-LogFile" {
    BeforeAll {
        # Create a temp file with mixed-format log content
        $script:TempLogPath = [System.IO.Path]::GetTempFileName()
        $mixedLog = @"
2024-01-15 10:00:00 INFO app: Application starting
2024-01-15 10:00:05 ERROR auth: Login failed for user admin
{"timestamp":"2024-01-15T10:00:10Z","level":"ERROR","component":"db","message":"Connection timeout"}
2024-01-15 10:00:15 WARNING disk: Disk usage at 85%
{"timestamp":"2024-01-15T10:00:20Z","level":"WARN","component":"api","message":"Rate limit approaching"}
2024-01-15 10:00:25 INFO app: Request processed
this is a malformed line that should be skipped
{"timestamp":"2024-01-15T10:00:30Z","level":"ERROR","component":"auth","message":"Login failed for user admin"}
"@
        Set-Content -Path $script:TempLogPath -Value $mixedLog
    }

    AfterAll {
        Remove-Item -Path $script:TempLogPath -ErrorAction SilentlyContinue
    }

    It "returns a collection of parsed log entries" {
        $results = Parse-LogFile -Path $script:TempLogPath
        $results | Should -Not -BeNullOrEmpty
    }

    It "correctly parses both syslog and JSON lines" {
        $results = Parse-LogFile -Path $script:TempLogPath
        $syslogEntries = $results | Where-Object { $_.Format -eq "syslog" }
        $jsonEntries   = $results | Where-Object { $_.Format -eq "json" }

        $syslogEntries.Count | Should -Be 4
        $jsonEntries.Count   | Should -Be 3
    }

    It "skips malformed lines without throwing" {
        # Total valid lines = 7 (4 syslog + 3 json), 1 malformed
        $results = Parse-LogFile -Path $script:TempLogPath
        $results.Count | Should -Be 7
    }

    It "throws a meaningful error when file does not exist" {
        { Parse-LogFile -Path "C:\nonexistent\file.log" } | Should -Throw "*not found*"
    }
}

# ============================================================
# RED PHASE 4: Filter errors and warnings
# ============================================================
Describe "Get-ErrorsAndWarnings" {
    BeforeAll {
        $script:AllEntries = @(
            [PSCustomObject]@{ Level = "INFO";    Message = "App started";         Component = "app";  Timestamp = [datetime]"2024-01-15 10:00:00"; Format = "syslog" }
            [PSCustomObject]@{ Level = "ERROR";   Message = "Login failed";        Component = "auth"; Timestamp = [datetime]"2024-01-15 10:00:05"; Format = "syslog" }
            [PSCustomObject]@{ Level = "ERROR";   Message = "Connection timeout";  Component = "db";   Timestamp = [datetime]"2024-01-15 10:00:10"; Format = "json" }
            [PSCustomObject]@{ Level = "WARNING"; Message = "Disk usage at 85%";   Component = "disk"; Timestamp = [datetime]"2024-01-15 10:00:15"; Format = "syslog" }
            [PSCustomObject]@{ Level = "WARNING"; Message = "Rate limit approaching"; Component = "api"; Timestamp = [datetime]"2024-01-15 10:00:20"; Format = "json" }
            [PSCustomObject]@{ Level = "INFO";    Message = "Request processed";   Component = "app";  Timestamp = [datetime]"2024-01-15 10:00:25"; Format = "syslog" }
        )
    }

    It "returns only ERROR and WARNING entries" {
        $filtered = Get-ErrorsAndWarnings -Entries $script:AllEntries
        $filtered.Count | Should -Be 4
    }

    It "excludes INFO entries" {
        $filtered = Get-ErrorsAndWarnings -Entries $script:AllEntries
        $infoEntries = $filtered | Where-Object { $_.Level -eq "INFO" }
        $infoEntries | Should -BeNullOrEmpty
    }

    It "returns empty array when no errors or warnings exist" {
        $infoOnly = $script:AllEntries | Where-Object { $_.Level -eq "INFO" }
        $filtered = Get-ErrorsAndWarnings -Entries $infoOnly
        $filtered.Count | Should -Be 0
    }
}

# ============================================================
# RED PHASE 5: Build frequency table (group by error type/message)
# ============================================================
Describe "Build-FrequencyTable" {
    BeforeAll {
        $script:ErrorEntries = @(
            [PSCustomObject]@{ Level = "ERROR";   Message = "Login failed";       Component = "auth"; Timestamp = [datetime]"2024-01-15 10:00:05" }
            [PSCustomObject]@{ Level = "ERROR";   Message = "Login failed";       Component = "auth"; Timestamp = [datetime]"2024-01-15 10:01:00" }
            [PSCustomObject]@{ Level = "ERROR";   Message = "Login failed";       Component = "auth"; Timestamp = [datetime]"2024-01-15 10:05:00" }
            [PSCustomObject]@{ Level = "ERROR";   Message = "Connection timeout"; Component = "db";   Timestamp = [datetime]"2024-01-15 10:00:10" }
            [PSCustomObject]@{ Level = "WARNING"; Message = "Disk usage at 85%";  Component = "disk"; Timestamp = [datetime]"2024-01-15 10:00:15" }
            [PSCustomObject]@{ Level = "WARNING"; Message = "Disk usage at 85%";  Component = "disk"; Timestamp = [datetime]"2024-01-15 10:10:00" }
        )
    }

    It "returns a frequency table with correct count" {
        $table = Build-FrequencyTable -Entries $script:ErrorEntries
        $table.Count | Should -Be 3  # Login failed, Connection timeout, Disk usage at 85%
    }

    It "groups by message and level" {
        $table = Build-FrequencyTable -Entries $script:ErrorEntries
        $loginEntry = $table | Where-Object { $_.Message -eq "Login failed" }
        $loginEntry.Count | Should -Be 3
    }

    It "records first occurrence timestamp" {
        $table = Build-FrequencyTable -Entries $script:ErrorEntries
        $loginEntry = $table | Where-Object { $_.Message -eq "Login failed" }
        $loginEntry.FirstOccurrence | Should -Be ([datetime]"2024-01-15 10:00:05")
    }

    It "records last occurrence timestamp" {
        $table = Build-FrequencyTable -Entries $script:ErrorEntries
        $loginEntry = $table | Where-Object { $_.Message -eq "Login failed" }
        $loginEntry.LastOccurrence | Should -Be ([datetime]"2024-01-15 10:05:00")
    }

    It "includes Level and Component in each table entry" {
        $table = Build-FrequencyTable -Entries $script:ErrorEntries
        $entry = $table | Select-Object -First 1
        $entry.PSObject.Properties.Name | Should -Contain "Level"
        $entry.PSObject.Properties.Name | Should -Contain "Component"
    }

    It "sorts table by count descending" {
        $table = Build-FrequencyTable -Entries $script:ErrorEntries
        $table[0].Count | Should -Be 3  # Login failed appears most
    }
}

# ============================================================
# RED PHASE 6: Export analysis as JSON
# ============================================================
Describe "Export-AnalysisJson" {
    BeforeAll {
        $script:FreqTable = @(
            [PSCustomObject]@{
                Level           = "ERROR"
                Component       = "auth"
                Message         = "Login failed"
                Count           = 3
                FirstOccurrence = [datetime]"2024-01-15 10:00:05"
                LastOccurrence  = [datetime]"2024-01-15 10:05:00"
            }
        )
        $script:JsonOutputPath = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.json'
    }

    AfterAll {
        Remove-Item -Path $script:JsonOutputPath -ErrorAction SilentlyContinue
    }

    It "creates a JSON file at the specified path" {
        Export-AnalysisJson -FrequencyTable $script:FreqTable -OutputPath $script:JsonOutputPath
        Test-Path $script:JsonOutputPath | Should -BeTrue
    }

    It "produces valid JSON" {
        Export-AnalysisJson -FrequencyTable $script:FreqTable -OutputPath $script:JsonOutputPath
        $content = Get-Content $script:JsonOutputPath -Raw
        { $content | ConvertFrom-Json } | Should -Not -Throw
    }

    It "includes all frequency table fields in JSON output" {
        Export-AnalysisJson -FrequencyTable $script:FreqTable -OutputPath $script:JsonOutputPath
        $parsed = Get-Content $script:JsonOutputPath -Raw | ConvertFrom-Json
        $firstEntry = $parsed.entries[0]
        $firstEntry.level     | Should -Be "ERROR"
        $firstEntry.component | Should -Be "auth"
        $firstEntry.message   | Should -Be "Login failed"
        $firstEntry.count     | Should -Be 3
    }
}

# ============================================================
# RED PHASE 7: Format human-readable table
# ============================================================
Describe "Format-AnalysisTable" {
    BeforeAll {
        $script:FreqTable = @(
            [PSCustomObject]@{
                Level           = "ERROR"
                Component       = "auth"
                Message         = "Login failed"
                Count           = 3
                FirstOccurrence = [datetime]"2024-01-15 10:00:05"
                LastOccurrence  = [datetime]"2024-01-15 10:05:00"
            }
            [PSCustomObject]@{
                Level           = "WARNING"
                Component       = "disk"
                Message         = "Disk usage at 85%"
                Count           = 2
                FirstOccurrence = [datetime]"2024-01-15 10:00:15"
                LastOccurrence  = [datetime]"2024-01-15 10:10:00"
            }
        )
    }

    It "returns a non-empty string" {
        $output = Format-AnalysisTable -FrequencyTable $script:FreqTable
        $output | Should -Not -BeNullOrEmpty
    }

    It "includes a header row" {
        $output = Format-AnalysisTable -FrequencyTable $script:FreqTable
        $output | Should -Match "Level"
        $output | Should -Match "Count"
        $output | Should -Match "Message"
    }

    It "includes data rows for each entry" {
        $output = Format-AnalysisTable -FrequencyTable $script:FreqTable
        $output | Should -Match "ERROR"
        $output | Should -Match "Login failed"
        $output | Should -Match "WARNING"
        $output | Should -Match "Disk usage at 85%"
    }

    It "includes occurrence timestamps" {
        $output = Format-AnalysisTable -FrequencyTable $script:FreqTable
        $output | Should -Match "2024-01-15"
    }
}

# ============================================================
# RED PHASE 8: End-to-end integration test using fixture file
# ============================================================
Describe "Invoke-LogAnalysis (Integration)" {
    BeforeAll {
        $script:FixturePath  = "$PSScriptRoot/fixtures/sample.log"
        $script:JsonOutPath  = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.json'
    }

    AfterAll {
        Remove-Item -Path $script:JsonOutPath -ErrorAction SilentlyContinue
    }

    It "fixture file exists" {
        Test-Path $script:FixturePath | Should -BeTrue
    }

    It "runs end-to-end analysis and returns a result object" {
        $result = Invoke-LogAnalysis -LogPath $script:FixturePath -JsonOutputPath $script:JsonOutPath
        $result | Should -Not -BeNullOrEmpty
    }

    It "result contains FrequencyTable" {
        $result = Invoke-LogAnalysis -LogPath $script:FixturePath -JsonOutputPath $script:JsonOutPath
        $result.FrequencyTable | Should -Not -BeNullOrEmpty
    }

    It "result contains HumanReadableTable string" {
        $result = Invoke-LogAnalysis -LogPath $script:FixturePath -JsonOutputPath $script:JsonOutPath
        $result.HumanReadableTable | Should -Not -BeNullOrEmpty
        $result.HumanReadableTable | Should -BeOfType [string]
    }

    It "JSON output file is created" {
        Invoke-LogAnalysis -LogPath $script:FixturePath -JsonOutputPath $script:JsonOutPath
        Test-Path $script:JsonOutPath | Should -BeTrue
    }

    It "JSON output contains summary metadata" {
        Invoke-LogAnalysis -LogPath $script:FixturePath -JsonOutputPath $script:JsonOutPath
        $json = Get-Content $script:JsonOutPath -Raw | ConvertFrom-Json
        $json.summary | Should -Not -BeNullOrEmpty
        $json.summary.totalErrors   | Should -BeGreaterThan 0
        $json.summary.totalWarnings | Should -BeGreaterThan 0
    }
}
