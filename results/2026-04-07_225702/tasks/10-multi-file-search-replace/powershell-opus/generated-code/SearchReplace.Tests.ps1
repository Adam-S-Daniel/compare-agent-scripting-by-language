# Tests for Search-Replace functionality using Pester
# TDD approach: each Describe block was written as a failing test first,
# then the minimum code was added to make it pass.

BeforeAll {
    . "$PSScriptRoot/SearchReplace.ps1"
}

Describe "Invoke-SearchReplace - Preview Mode" {
    BeforeEach {
        # Create a temporary directory structure with test files
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "sr-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:testDir "sub") -Force | Out-Null

        # Create test files with known content
        Set-Content -Path (Join-Path $script:testDir "file1.txt") -Value @(
            "Hello world"
            "This is a test"
            "Hello again"
        )
        Set-Content -Path (Join-Path $script:testDir "sub/file2.txt") -Value @(
            "Goodbye world"
            "Hello from sub"
        )
        # A non-matching file
        Set-Content -Path (Join-Path $script:testDir "data.csv") -Value @(
            "name,value"
            "Hello,42"
        )
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It "Should find all matches without modifying files" {
        $result = Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "Hello" -ReplaceWith "Hi" -Preview

        # Files should NOT be modified in preview mode
        $content1 = Get-Content (Join-Path $script:testDir "file1.txt") -Raw
        $content1 | Should -Match "Hello"

        # Result should contain match info
        $result.Matches.Count | Should -BeGreaterThan 0
    }

    It "Should return matches with file path, line number, and context" {
        $result = Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "Hello" -ReplaceWith "Hi" -Preview

        $firstMatch = $result.Matches[0]
        $firstMatch.FilePath | Should -Not -BeNullOrEmpty
        $firstMatch.LineNumber | Should -BeGreaterThan 0
        $firstMatch.OldText | Should -Not -BeNullOrEmpty
        $firstMatch.NewText | Should -Not -BeNullOrEmpty
    }

    It "Should find matches recursively in subdirectories" {
        $result = Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "Hello" -ReplaceWith "Hi" -Preview

        # Should find matches in both file1.txt and sub/file2.txt
        $matchedFiles = $result.Matches | Select-Object -ExpandProperty FilePath -Unique
        $matchedFiles.Count | Should -Be 2
    }

    It "Should only search files matching the glob pattern" {
        $result = Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "Hello" -ReplaceWith "Hi" -Preview

        # data.csv has "Hello" but should not be matched since pattern is *.txt
        $matchedFiles = $result.Matches | Select-Object -ExpandProperty FilePath -Unique
        $matchedFiles | ForEach-Object { $_ | Should -BeLike "*.txt" }
    }

    It "Should show what the replacement would look like" {
        $result = Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "Hello" -ReplaceWith "Hi" -Preview

        $match = $result.Matches | Where-Object { $_.OldText -match "Hello world" }
        $match | Should -Not -BeNullOrEmpty
        $match.NewText | Should -Match "Hi world"
    }
}

Describe "Invoke-SearchReplace - Backup and Replace" {
    BeforeEach {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "sr-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:testDir "sub") -Force | Out-Null

        Set-Content -Path (Join-Path $script:testDir "file1.txt") -Value @(
            "Hello world"
            "This is a test"
            "Hello again"
        )
        Set-Content -Path (Join-Path $script:testDir "sub/file2.txt") -Value @(
            "Goodbye world"
            "Hello from sub"
        )
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It "Should replace text in files when not in preview mode" {
        Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "Hello" -ReplaceWith "Hi"

        $content = Get-Content (Join-Path $script:testDir "file1.txt") -Raw
        $content | Should -Match "Hi world"
        $content | Should -Not -Match "Hello world"
        $content | Should -Match "Hi again"
    }

    It "Should create .bak backup files when -Backup is specified" {
        Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "Hello" -ReplaceWith "Hi" -Backup

        # Backup files should exist with original content
        $bakPath = Join-Path $script:testDir "file1.txt.bak"
        Test-Path $bakPath | Should -BeTrue
        $bakContent = Get-Content $bakPath -Raw
        $bakContent | Should -Match "Hello world"

        # Original file should be modified
        $content = Get-Content (Join-Path $script:testDir "file1.txt") -Raw
        $content | Should -Match "Hi world"
    }

    It "Should create backups in subdirectories too" {
        Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "Hello" -ReplaceWith "Hi" -Backup

        $bakPath = Join-Path $script:testDir "sub/file2.txt.bak"
        Test-Path $bakPath | Should -BeTrue
    }

    It "Should not create backups for files with no matches" {
        Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "ZZZZZ" -ReplaceWith "Hi" -Backup

        # No files should have backups since nothing matched
        $bakFiles = Get-ChildItem -Path $script:testDir -Filter "*.bak" -Recurse
        $bakFiles.Count | Should -Be 0
    }

    It "Should return list of changed files" {
        $result = Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "Hello" -ReplaceWith "Hi"

        $result.FilesChanged.Count | Should -Be 2
    }

    It "Should return list of backup file paths when -Backup is used" {
        $result = Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "Hello" -ReplaceWith "Hi" -Backup

        $result.BackupFiles.Count | Should -Be 2
        $result.BackupFiles | ForEach-Object { Test-Path $_ | Should -BeTrue }
    }
}

Describe "Invoke-SearchReplace - Summary Report" {
    BeforeEach {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "sr-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:testDir "sub") -Force | Out-Null

        Set-Content -Path (Join-Path $script:testDir "file1.txt") -Value @(
            "Hello world"
            "This is a test"
            "Hello again"
        )
        Set-Content -Path (Join-Path $script:testDir "sub/file2.txt") -Value @(
            "Goodbye world"
            "Hello from sub"
        )
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It "Should produce a summary report with correct match count" {
        $result = Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "Hello" -ReplaceWith "Hi"

        # 3 total matches: 2 in file1.txt, 1 in sub/file2.txt
        $result.Matches.Count | Should -Be 3
    }

    It "Should include correct line numbers in summary" {
        $result = Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "Hello" -ReplaceWith "Hi" -Preview

        $file1Matches = $result.Matches | Where-Object {
            $_.FilePath -like "*file1.txt"
        } | Sort-Object LineNumber

        $file1Matches[0].LineNumber | Should -Be 1
        $file1Matches[1].LineNumber | Should -Be 3
    }

    It "Should format a human-readable summary via Format-SearchReplaceSummary" {
        $result = Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "Hello" -ReplaceWith "Hi" -Preview

        $summary = Format-SearchReplaceSummary -Result $result
        $summary | Should -Not -BeNullOrEmpty
        # Summary should mention the number of matches and files
        $summary | Should -Match "3 match"
        $summary | Should -Match "2 file"
    }

    It "Should include old and new text in the formatted summary" {
        $result = Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "Hello" -ReplaceWith "Hi" -Preview

        $summary = Format-SearchReplaceSummary -Result $result
        $summary | Should -Match "Hello world"
        $summary | Should -Match "Hi world"
    }
}

Describe "Invoke-SearchReplace - Edge Cases" {
    BeforeEach {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "sr-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:testDir -ErrorAction SilentlyContinue
    }

    It "Should handle regex patterns correctly" {
        Set-Content -Path (Join-Path $script:testDir "code.txt") -Value @(
            "foo123bar"
            "foo456bar"
            "no match here"
        )

        $result = Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "foo(\d+)bar" -ReplaceWith 'baz$1qux'

        $content = Get-Content (Join-Path $script:testDir "code.txt") -Raw
        $content | Should -Match "baz123qux"
        $content | Should -Match "baz456qux"
    }

    It "Should return empty matches when no files match the glob pattern" {
        Set-Content -Path (Join-Path $script:testDir "readme.md") -Value "Hello world"

        $result = Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "Hello" -ReplaceWith "Hi" -Preview

        $result.Matches.Count | Should -Be 0
    }

    It "Should return empty matches when search pattern not found" {
        Set-Content -Path (Join-Path $script:testDir "file.txt") -Value "Hello world"

        $result = Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "ZZZZZ" -ReplaceWith "Hi" -Preview

        $result.Matches.Count | Should -Be 0
    }

    It "Should throw an error for an invalid directory path" {
        { Invoke-SearchReplace -Path "/nonexistent/path" -FilePattern "*.txt" `
            -SearchPattern "x" -ReplaceWith "y" } | Should -Throw "Directory not found*"
    }

    It "Should handle empty files gracefully" {
        Set-Content -Path (Join-Path $script:testDir "empty.txt") -Value ""

        $result = Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "Hello" -ReplaceWith "Hi" -Preview

        $result.Matches.Count | Should -Be 0
    }

    It "Should handle multiple matches on the same line" {
        Set-Content -Path (Join-Path $script:testDir "multi.txt") -Value "cat and cat and cat"

        $result = Invoke-SearchReplace -Path $script:testDir -FilePattern "*.txt" `
            -SearchPattern "cat" -ReplaceWith "dog"

        $content = Get-Content (Join-Path $script:testDir "multi.txt") -Raw
        $content | Should -Match "dog and dog and dog"
        # The line should appear once in matches (one line, one entry)
        $result.Matches.Count | Should -Be 1
        $result.Matches[0].NewText | Should -Be "dog and dog and dog"
    }
}
