# SearchReplace.Tests.ps1
# TDD tests for multi-file search and replace functionality.
# Uses Pester 5 as the test framework.
# All tests use strict mode as required.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Import the module under test via dot-sourcing.
# $PSScriptRoot resolves to the directory containing this test file.
[string]$modulePath = Join-Path $PSScriptRoot 'SearchReplace.ps1'
. $modulePath

# ============================================================
# Helper functions for creating and removing test fixtures
# ============================================================

function New-TestFixtures {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$BasePath
    )

    [string]$testDir = Join-Path $BasePath 'test-fixtures'

    # Create directory structure: root + two subdirs, one with a nested subdir
    $null = New-Item -Path $testDir -ItemType Directory -Force
    $null = New-Item -Path (Join-Path $testDir 'subdir1') -ItemType Directory -Force
    $null = New-Item -Path (Join-Path $testDir 'subdir2') -ItemType Directory -Force
    $null = New-Item -Path (Join-Path $testDir 'subdir2' 'nested') -ItemType Directory -Force

    # Root-level .txt files with known content
    Set-Content -Path (Join-Path $testDir 'file1.txt') -Value @(
        'Hello World',
        'This is a test file',
        'foo bar baz',
        'The quick brown fox'
    )

    Set-Content -Path (Join-Path $testDir 'file2.txt') -Value @(
        'Another file',
        'foo appears here too',
        'Nothing special'
    )

    # .txt file in subdir1
    Set-Content -Path (Join-Path $testDir 'subdir1' 'file3.txt') -Value @(
        'Subdirectory file',
        'foo and bar'
    )

    # .log file in subdir2 (should NOT match *.txt pattern)
    Set-Content -Path (Join-Path $testDir 'subdir2' 'file4.log') -Value @(
        'Log entry: foo',
        'Log entry: bar'
    )

    # Deeply nested .txt file
    Set-Content -Path (Join-Path $testDir 'subdir2' 'nested' 'file5.txt') -Value @(
        'Deeply nested',
        'foo is here'
    )

    # .txt file with no matches for negative testing
    Set-Content -Path (Join-Path $testDir 'nomatch.txt') -Value @(
        'This file has no matches',
        'for our pattern'
    )

    return [string]$testDir
}

function Remove-TestFixtures {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$BasePath
    )
    if (Test-Path $BasePath) {
        Remove-Item -Path $BasePath -Recurse -Force
    }
}

# ============================================================
# TDD Cycle 1: Get-FilesMatchingGlob
# Find files recursively matching a glob pattern
# ============================================================

Describe 'Get-FilesMatchingGlob' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "SRTests_$(New-Guid)"
        $script:fixtureDir = New-TestFixtures -BasePath $script:tempDir
    }

    AfterAll {
        Remove-TestFixtures -BasePath $script:tempDir
    }

    It 'should find all .txt files recursively' {
        [string[]]$files = Get-FilesMatchingGlob -RootPath $script:fixtureDir -GlobPattern '*.txt'
        [string[]]$fileNames = @($files | ForEach-Object { [System.IO.Path]::GetFileName($_) })

        $fileNames | Should -Contain 'file1.txt'
        $fileNames | Should -Contain 'file2.txt'
        $fileNames | Should -Contain 'nomatch.txt'
        $fileNames | Should -Contain 'file3.txt'
        $fileNames | Should -Contain 'file5.txt'
    }

    It 'should not return files that do not match the pattern' {
        [string[]]$files = Get-FilesMatchingGlob -RootPath $script:fixtureDir -GlobPattern '*.txt'
        [string[]]$fileNames = @($files | ForEach-Object { [System.IO.Path]::GetFileName($_) })

        $fileNames | Should -Not -Contain 'file4.log'
    }

    It 'should find only .log files when pattern is *.log' {
        [string[]]$files = Get-FilesMatchingGlob -RootPath $script:fixtureDir -GlobPattern '*.log'
        [string[]]$fileNames = @($files | ForEach-Object { [System.IO.Path]::GetFileName($_) })

        $fileNames | Should -Contain 'file4.log'
        $fileNames.Count | Should -Be 1
    }

    It 'should match files by prefix pattern' {
        [string[]]$files = Get-FilesMatchingGlob -RootPath $script:fixtureDir -GlobPattern 'file*.txt'
        [string[]]$fileNames = @($files | ForEach-Object { [System.IO.Path]::GetFileName($_) })

        $fileNames | Should -Contain 'file1.txt'
        $fileNames | Should -Contain 'file2.txt'
        $fileNames | Should -Not -Contain 'nomatch.txt'
    }

    It 'should return empty when no files match' {
        [string[]]$files = Get-FilesMatchingGlob -RootPath $script:fixtureDir -GlobPattern '*.xml'
        $files | Should -BeNullOrEmpty
    }

    It 'should throw when root path does not exist' {
        { Get-FilesMatchingGlob -RootPath '/nonexistent/path/xyz' -GlobPattern '*.txt' } | Should -Throw
    }
}

# ============================================================
# TDD Cycle 2: Search-FileForPattern
# Search a single file for regex pattern matches
# ============================================================

Describe 'Search-FileForPattern' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "SRTests_$(New-Guid)"
        $script:fixtureDir = New-TestFixtures -BasePath $script:tempDir
    }

    AfterAll {
        Remove-TestFixtures -BasePath $script:tempDir
    }

    It 'should return match with correct line number' {
        [string]$filePath = Join-Path $script:fixtureDir 'file1.txt'
        [PSCustomObject[]]$results = Search-FileForPattern -FilePath $filePath -SearchPattern 'foo'

        # file1.txt line 3: 'foo bar baz'
        $results | Should -Not -BeNullOrEmpty
        [int[]]$lineNums = @($results | ForEach-Object { [int]$_.LineNumber })
        $lineNums | Should -Contain 3
    }

    It 'should return the matching line text' {
        [string]$filePath = Join-Path $script:fixtureDir 'file1.txt'
        [PSCustomObject[]]$results = Search-FileForPattern -FilePath $filePath -SearchPattern 'foo'

        [string[]]$lineTexts = @($results | ForEach-Object { [string]$_.LineText })
        $lineTexts | Should -Contain 'foo bar baz'
    }

    It 'should return empty when no matches found' {
        [string]$filePath = Join-Path $script:fixtureDir 'nomatch.txt'
        [PSCustomObject[]]$results = Search-FileForPattern -FilePath $filePath -SearchPattern 'foo'

        $results | Should -BeNullOrEmpty
    }

    It 'should support regex quantifier patterns' {
        [string]$filePath = Join-Path $script:fixtureDir 'file1.txt'
        # 'fo+' matches 'foo'
        [PSCustomObject[]]$results = Search-FileForPattern -FilePath $filePath -SearchPattern 'fo+'

        $results | Should -Not -BeNullOrEmpty
        [string]$firstLine = [string]$results[0].LineText
        $firstLine | Should -Match 'foo'
    }

    It 'should include the file path in each result' {
        [string]$filePath = Join-Path $script:fixtureDir 'file1.txt'
        [PSCustomObject[]]$results = Search-FileForPattern -FilePath $filePath -SearchPattern 'foo'

        [string]$resultPath = [string]$results[0].FilePath
        $resultPath | Should -Be $filePath
    }

    It 'should find multiple matching lines in one file' {
        # file2.txt has 'foo' on line 2 only; subdir files have one each
        [string]$filePath = Join-Path $script:fixtureDir 'file2.txt'
        [PSCustomObject[]]$results = Search-FileForPattern -FilePath $filePath -SearchPattern 'foo'

        $results.Count | Should -BeGreaterOrEqual 1
    }

    It 'should throw when file does not exist' {
        { Search-FileForPattern -FilePath '/nonexistent/path/file.txt' -SearchPattern 'foo' } | Should -Throw
    }
}

# ============================================================
# TDD Cycle 3: Invoke-FileReplace
# Perform replacement in a single file, with optional backup
# ============================================================

Describe 'Invoke-FileReplace' {
    BeforeEach {
        # Use BeforeEach so each test gets a fresh fixture set
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "SRTests_$(New-Guid)"
        $script:fixtureDir = New-TestFixtures -BasePath $script:tempDir
    }

    AfterEach {
        Remove-TestFixtures -BasePath $script:tempDir
    }

    It 'should replace text in file content' {
        [string]$filePath = Join-Path $script:fixtureDir 'file1.txt'
        $null = Invoke-FileReplace -FilePath $filePath -SearchPattern 'foo' -Replacement 'BAR' -CreateBackup $false

        [string]$content = Get-Content -Path $filePath -Raw
        $content | Should -Match 'BAR'
        $content | Should -Not -Match '\bfoo\b'
    }

    It 'should return change records with OldText and NewText' {
        [string]$filePath = Join-Path $script:fixtureDir 'file1.txt'
        [PSCustomObject[]]$changes = Invoke-FileReplace -FilePath $filePath -SearchPattern 'foo' -Replacement 'BAR' -CreateBackup $false

        $changes | Should -Not -BeNullOrEmpty
        [PSCustomObject]$change = $changes | Where-Object { [string]$_.OldText -match 'foo' } | Select-Object -First 1
        $change | Should -Not -BeNullOrEmpty
        [string]$change.OldText | Should -Match 'foo'
        [string]$change.NewText | Should -Match 'BAR'
    }

    It 'should create .bak backup file when CreateBackup is true' {
        [string]$filePath = Join-Path $script:fixtureDir 'file1.txt'
        $null = Invoke-FileReplace -FilePath $filePath -SearchPattern 'foo' -Replacement 'BAR' -CreateBackup $true

        [string]$backupPath = [string]"$filePath.bak"
        Test-Path -Path $backupPath | Should -BeTrue
    }

    It 'should backup contain original content' {
        [string]$filePath = Join-Path $script:fixtureDir 'file1.txt'
        [string]$originalContent = Get-Content -Path $filePath -Raw

        $null = Invoke-FileReplace -FilePath $filePath -SearchPattern 'foo' -Replacement 'BAR' -CreateBackup $true

        [string]$backupContent = Get-Content -Path ([string]"$filePath.bak") -Raw
        $backupContent | Should -Be $originalContent
    }

    It 'should not create backup when CreateBackup is false' {
        [string]$filePath = Join-Path $script:fixtureDir 'file1.txt'
        $null = Invoke-FileReplace -FilePath $filePath -SearchPattern 'foo' -Replacement 'BAR' -CreateBackup $false

        Test-Path -Path ([string]"$filePath.bak") | Should -BeFalse
    }

    It 'should return empty and leave file unchanged when no matches found' {
        [string]$filePath = Join-Path $script:fixtureDir 'nomatch.txt'
        [string]$originalContent = Get-Content -Path $filePath -Raw
        [PSCustomObject[]]$changes = Invoke-FileReplace -FilePath $filePath -SearchPattern 'foo' -Replacement 'BAR' -CreateBackup $false

        $changes | Should -BeNullOrEmpty
        [string]$currentContent = Get-Content -Path $filePath -Raw
        $currentContent | Should -Be $originalContent
    }

    It 'should include line number in change records' {
        [string]$filePath = Join-Path $script:fixtureDir 'file1.txt'
        [PSCustomObject[]]$changes = Invoke-FileReplace -FilePath $filePath -SearchPattern 'foo' -Replacement 'BAR' -CreateBackup $false

        [int]$lineNum = [int]$changes[0].LineNumber
        $lineNum | Should -BeGreaterThan 0
    }

    It 'should throw when file does not exist' {
        { Invoke-FileReplace -FilePath '/nonexistent/path/file.txt' -SearchPattern 'foo' -Replacement 'BAR' -CreateBackup $false } | Should -Throw
    }
}

# ============================================================
# TDD Cycle 4: Invoke-MultiFileSearchReplace — Preview Mode
# Show matches without modifying any files
# ============================================================

Describe 'Invoke-MultiFileSearchReplace - Preview Mode' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "SRTests_$(New-Guid)"
        $script:fixtureDir = New-TestFixtures -BasePath $script:tempDir
    }

    AfterAll {
        Remove-TestFixtures -BasePath $script:tempDir
    }

    It 'should not modify files in preview mode' {
        [string]$filePath = Join-Path $script:fixtureDir 'file1.txt'
        [string]$originalContent = Get-Content -Path $filePath -Raw

        $null = Invoke-MultiFileSearchReplace `
            -RootPath $script:fixtureDir `
            -GlobPattern '*.txt' `
            -SearchPattern 'foo' `
            -Replacement 'BAR' `
            -Preview $true `
            -CreateBackup $false

        [string]$afterContent = Get-Content -Path $filePath -Raw
        $afterContent | Should -Be $originalContent
    }

    It 'should return results with FilePath, LineNumber, OldText, NewText' {
        [PSCustomObject[]]$results = Invoke-MultiFileSearchReplace `
            -RootPath $script:fixtureDir `
            -GlobPattern '*.txt' `
            -SearchPattern 'foo' `
            -Replacement 'BAR' `
            -Preview $true `
            -CreateBackup $false

        $results | Should -Not -BeNullOrEmpty
        [PSCustomObject]$first = $results[0]
        $first.PSObject.Properties.Name | Should -Contain 'FilePath'
        $first.PSObject.Properties.Name | Should -Contain 'LineNumber'
        $first.PSObject.Properties.Name | Should -Contain 'OldText'
        $first.PSObject.Properties.Name | Should -Contain 'NewText'
    }

    It 'should find matches across multiple files' {
        [PSCustomObject[]]$results = Invoke-MultiFileSearchReplace `
            -RootPath $script:fixtureDir `
            -GlobPattern '*.txt' `
            -SearchPattern 'foo' `
            -Replacement 'BAR' `
            -Preview $true `
            -CreateBackup $false

        [string[]]$distinctFiles = @($results | ForEach-Object { [string]$_.FilePath } | Select-Object -Unique)
        $distinctFiles.Count | Should -BeGreaterThan 1
    }

    It 'should not create backup files even when CreateBackup is true in preview mode' {
        $null = Invoke-MultiFileSearchReplace `
            -RootPath $script:fixtureDir `
            -GlobPattern '*.txt' `
            -SearchPattern 'foo' `
            -Replacement 'BAR' `
            -Preview $true `
            -CreateBackup $true

        # Preview must never write .bak files
        [object[]]$bakFiles = @(Get-ChildItem -Path $script:fixtureDir -Filter '*.bak' -Recurse -File)
        $bakFiles | Should -BeNullOrEmpty
    }
}

# ============================================================
# TDD Cycle 5: Invoke-MultiFileSearchReplace — Replace Mode
# Modify files and return a summary report
# ============================================================

Describe 'Invoke-MultiFileSearchReplace - Replace Mode' {
    BeforeEach {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "SRTests_$(New-Guid)"
        $script:fixtureDir = New-TestFixtures -BasePath $script:tempDir
    }

    AfterEach {
        Remove-TestFixtures -BasePath $script:tempDir
    }

    It 'should modify file content to replace pattern' {
        $null = Invoke-MultiFileSearchReplace `
            -RootPath $script:fixtureDir `
            -GlobPattern '*.txt' `
            -SearchPattern 'foo' `
            -Replacement 'REPLACED' `
            -Preview $false `
            -CreateBackup $false

        [string]$content = Get-Content -Path (Join-Path $script:fixtureDir 'file1.txt') -Raw
        $content | Should -Match 'REPLACED'
        $content | Should -Not -Match '\bfoo\b'
    }

    It 'should create backup files when CreateBackup is true' {
        $null = Invoke-MultiFileSearchReplace `
            -RootPath $script:fixtureDir `
            -GlobPattern '*.txt' `
            -SearchPattern 'foo' `
            -Replacement 'REPLACED' `
            -Preview $false `
            -CreateBackup $true

        [object[]]$bakFiles = @(Get-ChildItem -Path $script:fixtureDir -Filter '*.bak' -Recurse -File)
        $bakFiles | Should -Not -BeNullOrEmpty
    }

    It 'should return summary report with required fields' {
        [PSCustomObject[]]$report = Invoke-MultiFileSearchReplace `
            -RootPath $script:fixtureDir `
            -GlobPattern '*.txt' `
            -SearchPattern 'foo' `
            -Replacement 'REPLACED' `
            -Preview $false `
            -CreateBackup $false

        $report | Should -Not -BeNullOrEmpty
        [PSCustomObject]$entry = $report[0]
        $entry.PSObject.Properties.Name | Should -Contain 'FilePath'
        $entry.PSObject.Properties.Name | Should -Contain 'LineNumber'
        $entry.PSObject.Properties.Name | Should -Contain 'OldText'
        $entry.PSObject.Properties.Name | Should -Contain 'NewText'
    }

    It 'should report correct old and new text' {
        [PSCustomObject[]]$report = Invoke-MultiFileSearchReplace `
            -RootPath $script:fixtureDir `
            -GlobPattern '*.txt' `
            -SearchPattern 'foo' `
            -Replacement 'REPLACED' `
            -Preview $false `
            -CreateBackup $false

        [PSCustomObject]$entry = $report | Where-Object { [string]$_.OldText -match 'foo' } | Select-Object -First 1
        $entry | Should -Not -BeNullOrEmpty
        [string]$entry.OldText | Should -Match 'foo'
        [string]$entry.NewText | Should -Match 'REPLACED'
    }

    It 'should only replace in files matching glob pattern' {
        $null = Invoke-MultiFileSearchReplace `
            -RootPath $script:fixtureDir `
            -GlobPattern '*.log' `
            -SearchPattern 'foo' `
            -Replacement 'REPLACED' `
            -Preview $false `
            -CreateBackup $false

        # .txt files must be untouched
        [string]$txtContent = Get-Content -Path (Join-Path $script:fixtureDir 'file1.txt') -Raw
        $txtContent | Should -Match '\bfoo\b'
        $txtContent | Should -Not -Match 'REPLACED'

        # .log file must be changed
        [string]$logContent = Get-Content -Path (Join-Path $script:fixtureDir 'subdir2' 'file4.log') -Raw
        $logContent | Should -Match 'REPLACED'
    }

    It 'should return empty when no files have matches' {
        [PSCustomObject[]]$report = Invoke-MultiFileSearchReplace `
            -RootPath $script:fixtureDir `
            -GlobPattern '*.txt' `
            -SearchPattern 'ZZZNOMATCHPATTERN' `
            -Replacement 'REPLACED' `
            -Preview $false `
            -CreateBackup $false

        $report | Should -BeNullOrEmpty
    }

    It 'should process files in subdirectories recursively' {
        [PSCustomObject[]]$report = Invoke-MultiFileSearchReplace `
            -RootPath $script:fixtureDir `
            -GlobPattern '*.txt' `
            -SearchPattern 'foo' `
            -Replacement 'REPLACED' `
            -Preview $false `
            -CreateBackup $false

        [string[]]$filePaths = @($report | ForEach-Object { [string]$_.FilePath })
        [object[]]$subdirEntries = @($filePaths | Where-Object { $_ -match [regex]::Escape('subdir') })
        $subdirEntries | Should -Not -BeNullOrEmpty
    }
}

# ============================================================
# TDD Cycle 6: Get-SearchReplaceSummary
# Format a human-readable summary report from change records
# ============================================================

Describe 'Get-SearchReplaceSummary' {
    It 'should produce a non-empty string summary' {
        [PSCustomObject[]]$changes = @(
            [PSCustomObject]@{
                FilePath   = '/test/file1.txt'
                LineNumber = [int]3
                OldText    = 'foo bar baz'
                NewText    = 'BAR bar baz'
            },
            [PSCustomObject]@{
                FilePath   = '/test/file2.txt'
                LineNumber = [int]2
                OldText    = 'foo appears here too'
                NewText    = 'BAR appears here too'
            }
        )

        [string]$summary = Get-SearchReplaceSummary -Changes $changes

        $summary | Should -Not -BeNullOrEmpty
        $summary | Should -BeOfType [string]
        $summary | Should -Match 'file1\.txt'
        $summary | Should -Match 'file2\.txt'
    }

    It 'should include file path, line number, old text, and new text' {
        [PSCustomObject[]]$changes = @(
            [PSCustomObject]@{
                FilePath   = '/test/file1.txt'
                LineNumber = [int]3
                OldText    = 'foo bar baz'
                NewText    = 'BAR bar baz'
            }
        )

        [string]$summary = Get-SearchReplaceSummary -Changes $changes

        $summary | Should -Match '3'             # line number
        $summary | Should -Match 'foo bar baz'   # old text
        $summary | Should -Match 'BAR bar baz'   # new text
    }

    It 'should report total change count and file count' {
        [PSCustomObject[]]$changes = @(
            [PSCustomObject]@{ FilePath = '/f1.txt'; LineNumber = [int]1; OldText = 'a'; NewText = 'b' },
            [PSCustomObject]@{ FilePath = '/f1.txt'; LineNumber = [int]2; OldText = 'a'; NewText = 'b' },
            [PSCustomObject]@{ FilePath = '/f2.txt'; LineNumber = [int]1; OldText = 'a'; NewText = 'b' }
        )

        [string]$summary = Get-SearchReplaceSummary -Changes $changes

        # Should mention 3 total changes and 2 distinct files
        $summary | Should -Match '3'
        $summary | Should -Match '2'
    }

    It 'should return a no-changes message when changes array is empty' {
        [string]$summary = Get-SearchReplaceSummary -Changes @()

        $summary | Should -Not -BeNullOrEmpty
        $summary | Should -Match 'No changes'
    }
}
