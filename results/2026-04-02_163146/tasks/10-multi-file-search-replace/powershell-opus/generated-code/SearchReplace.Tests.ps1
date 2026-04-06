# SearchReplace.Tests.ps1
# Pester tests for the SearchReplace module.
# Written following red/green TDD methodology:
#   Round 1: Find-MatchingFiles - glob pattern search
#   Round 2: Search-InFiles - regex pattern matching
#   Round 3: Get-SearchPreview - preview mode with context
#   Round 4: New-FileBackup - backup creation
#   Round 5: Invoke-SearchReplace - search-and-replace with summary report
#   Round 6: Error handling across all functions

BeforeAll {
    Import-Module "$PSScriptRoot/SearchReplace.psm1" -Force
}

# ============================================================
# TDD Round 1 (RED then GREEN): Find files by glob pattern
# ============================================================
Describe "Find-MatchingFiles" {
    BeforeAll {
        # Create a mock directory structure for testing
        $script:testRoot = Join-Path $TestDrive "globtest"
        New-Item -Path $script:testRoot -ItemType Directory -Force | Out-Null
        New-Item -Path "$($script:testRoot)/src" -ItemType Directory -Force | Out-Null
        New-Item -Path "$($script:testRoot)/src/sub" -ItemType Directory -Force | Out-Null
        New-Item -Path "$($script:testRoot)/docs" -ItemType Directory -Force | Out-Null

        Set-Content -Path "$($script:testRoot)/src/app.txt" -Value "hello world"
        Set-Content -Path "$($script:testRoot)/src/main.log" -Value "log entry"
        Set-Content -Path "$($script:testRoot)/src/sub/util.txt" -Value "utility"
        Set-Content -Path "$($script:testRoot)/docs/readme.txt" -Value "documentation"
        Set-Content -Path "$($script:testRoot)/docs/notes.md" -Value "markdown notes"
    }

    It "Should find all .txt files recursively" {
        $results = Find-MatchingFiles -Path $script:testRoot -GlobPattern "*.txt"
        $results.Count | Should -Be 3
    }

    It "Should find files only in a specific subdirectory" {
        $results = Find-MatchingFiles -Path "$($script:testRoot)/src" -GlobPattern "*.txt"
        $results.Count | Should -Be 2
    }

    It "Should return empty array when no files match" {
        $results = Find-MatchingFiles -Path $script:testRoot -GlobPattern "*.xyz"
        @($results).Count | Should -Be 0
    }

    It "Should find files matching .md pattern" {
        $results = Find-MatchingFiles -Path $script:testRoot -GlobPattern "*.md"
        $results.Count | Should -Be 1
        $results[0].Name | Should -Be "notes.md"
    }

    It "Should return FileInfo objects with full paths" {
        $results = Find-MatchingFiles -Path $script:testRoot -GlobPattern "*.txt"
        $results | ForEach-Object { $_ | Should -BeOfType [System.IO.FileInfo] }
    }
}

# ============================================================
# TDD Round 2 (RED then GREEN): Search for regex in files
# ============================================================
Describe "Search-InFiles" {
    BeforeAll {
        $script:testRoot = Join-Path $TestDrive "searchtest"
        New-Item -Path $script:testRoot -ItemType Directory -Force | Out-Null

        # Create files with known content for regex matching
        Set-Content -Path "$($script:testRoot)/file1.txt" -Value @(
            "The quick brown fox"
            "jumps over the lazy dog"
            "FOX is uppercase here"
        )
        Set-Content -Path "$($script:testRoot)/file2.txt" -Value @(
            "No matches in this file"
            "Just some random text"
        )
        Set-Content -Path "$($script:testRoot)/file3.txt" -Value @(
            "Another fox appears"
            "and a second fox too"
        )
    }

    It "Should find regex matches across multiple files" {
        $files = Get-ChildItem -Path $script:testRoot -Filter "*.txt"
        $results = Search-InFiles -Files $files -Pattern "fox"
        # file1.txt line 1, file3.txt lines 1 and 2
        $results.Count | Should -Be 3
    }

    It "Should return correct line numbers" {
        $files = @(Get-Item "$($script:testRoot)/file1.txt")
        $results = Search-InFiles -Files $files -Pattern "fox"
        $results[0].LineNumber | Should -Be 1
    }

    It "Should return file path in results" {
        $files = @(Get-Item "$($script:testRoot)/file1.txt")
        $results = Search-InFiles -Files $files -Pattern "fox"
        $results[0].FilePath | Should -Be "$($script:testRoot)/file1.txt"
    }

    It "Should return matched line text" {
        $files = @(Get-Item "$($script:testRoot)/file1.txt")
        $results = Search-InFiles -Files $files -Pattern "fox"
        $results[0].LineText | Should -Be "The quick brown fox"
    }

    It "Should be case-sensitive by default" {
        $files = @(Get-Item "$($script:testRoot)/file1.txt")
        $results = Search-InFiles -Files $files -Pattern "fox"
        # Only lowercase "fox" on line 1 (not "FOX" on line 3)
        $results.Count | Should -Be 1
    }

    It "Should support case-insensitive matching with -IgnoreCase" {
        $files = @(Get-Item "$($script:testRoot)/file1.txt")
        $results = Search-InFiles -Files $files -Pattern "fox" -IgnoreCase
        # "fox" on line 1 and "FOX" on line 3
        $results.Count | Should -Be 2
    }

    It "Should return empty when no matches found" {
        $files = Get-ChildItem -Path $script:testRoot -Filter "*.txt"
        $results = Search-InFiles -Files $files -Pattern "elephant"
        @($results).Count | Should -Be 0
    }
}

# ============================================================
# TDD Round 3 (RED then GREEN): Preview mode with context
# ============================================================
Describe "Get-SearchPreview" {
    BeforeAll {
        $script:testRoot = Join-Path $TestDrive "previewtest"
        New-Item -Path $script:testRoot -ItemType Directory -Force | Out-Null

        Set-Content -Path "$($script:testRoot)/sample.txt" -Value @(
            "line one"
            "line two"
            "the target line"
            "line four"
            "line five"
            "another target here"
            "line seven"
        )
    }

    It "Should show matches with surrounding context lines" {
        $files = @(Get-Item "$($script:testRoot)/sample.txt")
        $preview = Get-SearchPreview -Files $files -Pattern "target" -ContextLines 1
        # Should have 2 match groups (line 3 and line 6)
        $preview.Count | Should -Be 2
    }

    It "Should include correct context before and after match" {
        $files = @(Get-Item "$($script:testRoot)/sample.txt")
        $preview = Get-SearchPreview -Files $files -Pattern "target" -ContextLines 1
        # First match context: lines 2,3,4
        $preview[0].ContextBefore | Should -Contain "line two"
        $preview[0].MatchLine | Should -Be "the target line"
        $preview[0].ContextAfter | Should -Contain "line four"
    }

    It "Should handle context at beginning of file gracefully" {
        $files = @(Get-Item "$($script:testRoot)/sample.txt")
        # Create file where match is on line 1
        Set-Content -Path "$($script:testRoot)/edge.txt" -Value @(
            "target at start"
            "second line"
        )
        $edgeFiles = @(Get-Item "$($script:testRoot)/edge.txt")
        $preview = Get-SearchPreview -Files $edgeFiles -Pattern "target" -ContextLines 2
        $preview[0].ContextBefore.Count | Should -Be 0
        $preview[0].MatchLine | Should -Be "target at start"
    }

    It "Should handle context at end of file gracefully" {
        Set-Content -Path "$($script:testRoot)/edge2.txt" -Value @(
            "first line"
            "target at end"
        )
        $files = @(Get-Item "$($script:testRoot)/edge2.txt")
        $preview = Get-SearchPreview -Files $files -Pattern "target" -ContextLines 2
        $preview[0].ContextAfter.Count | Should -Be 0
    }

    It "Should include file path and line number in preview" {
        $files = @(Get-Item "$($script:testRoot)/sample.txt")
        $preview = Get-SearchPreview -Files $files -Pattern "target" -ContextLines 1
        $preview[0].FilePath | Should -Be "$($script:testRoot)/sample.txt"
        $preview[0].LineNumber | Should -Be 3
    }

    It "Should default to 2 context lines when not specified" {
        $files = @(Get-Item "$($script:testRoot)/sample.txt")
        $preview = Get-SearchPreview -Files $files -Pattern "target"
        # First match on line 3, context 2: lines 1,2 before, lines 4,5 after
        $preview[0].ContextBefore.Count | Should -Be 2
        $preview[0].ContextAfter.Count | Should -Be 2
    }
}

# ============================================================
# TDD Round 4 (RED then GREEN): Backup creation
# ============================================================
Describe "New-FileBackup" {
    BeforeAll {
        $script:testRoot = Join-Path $TestDrive "backuptest"
        New-Item -Path $script:testRoot -ItemType Directory -Force | Out-Null
        Set-Content -Path "$($script:testRoot)/original.txt" -Value "original content"
    }

    It "Should create a backup copy of the file" {
        $backupPath = New-FileBackup -FilePath "$($script:testRoot)/original.txt"
        Test-Path $backupPath | Should -Be $true
    }

    It "Should preserve original file content in backup" {
        $backupPath = New-FileBackup -FilePath "$($script:testRoot)/original.txt"
        Get-Content $backupPath -Raw | Should -BeLike "*original content*"
    }

    It "Should create backup with .bak extension by default" {
        $backupPath = New-FileBackup -FilePath "$($script:testRoot)/original.txt"
        $backupPath | Should -BeLike "*.bak"
    }

    It "Should support custom backup directory" {
        $backupDir = Join-Path $script:testRoot "backups"
        $backupPath = New-FileBackup -FilePath "$($script:testRoot)/original.txt" -BackupDirectory $backupDir
        $backupPath | Should -BeLike "*backups*"
        Test-Path $backupPath | Should -Be $true
    }

    It "Should not overwrite existing backups (timestamped names)" {
        $backup1 = New-FileBackup -FilePath "$($script:testRoot)/original.txt"
        Start-Sleep -Milliseconds 50
        $backup2 = New-FileBackup -FilePath "$($script:testRoot)/original.txt"
        $backup1 | Should -Not -Be $backup2
        (Test-Path $backup1) | Should -Be $true
        (Test-Path $backup2) | Should -Be $true
    }
}

# ============================================================
# TDD Round 5 (RED then GREEN): Search-and-replace with summary
# ============================================================
Describe "Invoke-SearchReplace" {
    BeforeAll {
        $script:testRoot = Join-Path $TestDrive "replacetest"
        New-Item -Path $script:testRoot -ItemType Directory -Force | Out-Null
        New-Item -Path "$($script:testRoot)/sub" -ItemType Directory -Force | Out-Null
    }

    BeforeEach {
        # Reset test files before each test
        Set-Content -Path "$($script:testRoot)/config.txt" -Value @(
            "server=localhost"
            "port=8080"
            "host=localhost"
        )
        Set-Content -Path "$($script:testRoot)/sub/settings.txt" -Value @(
            "url=http://localhost:3000"
            "debug=true"
        )
    }

    It "Should replace all matches in files" {
        $result = Invoke-SearchReplace -Path $script:testRoot -GlobPattern "*.txt" `
            -SearchPattern "localhost" -ReplaceWith "production.server"
        # Verify the file was actually modified
        $content = Get-Content "$($script:testRoot)/config.txt"
        $content[0] | Should -Be "server=production.server"
        $content[2] | Should -Be "host=production.server"
    }

    It "Should return a summary report with change details" {
        $result = Invoke-SearchReplace -Path $script:testRoot -GlobPattern "*.txt" `
            -SearchPattern "localhost" -ReplaceWith "production.server"
        $result.Changes.Count | Should -BeGreaterThan 0
    }

    It "Should include file path in summary changes" {
        $result = Invoke-SearchReplace -Path $script:testRoot -GlobPattern "*.txt" `
            -SearchPattern "localhost" -ReplaceWith "production.server"
        $result.Changes[0].FilePath | Should -Not -BeNullOrEmpty
    }

    It "Should include line number in summary changes" {
        $result = Invoke-SearchReplace -Path $script:testRoot -GlobPattern "*.txt" `
            -SearchPattern "localhost" -ReplaceWith "production.server"
        $result.Changes[0].LineNumber | Should -BeOfType [int]
    }

    It "Should include old and new text in summary changes" {
        $result = Invoke-SearchReplace -Path $script:testRoot -GlobPattern "*.txt" `
            -SearchPattern "localhost" -ReplaceWith "production.server"
        $result.Changes[0].OldText | Should -Not -BeNullOrEmpty
        $result.Changes[0].NewText | Should -Not -BeNullOrEmpty
    }

    It "Should report total files modified and total replacements" {
        $result = Invoke-SearchReplace -Path $script:testRoot -GlobPattern "*.txt" `
            -SearchPattern "localhost" -ReplaceWith "production.server"
        $result.TotalFilesModified | Should -Be 2
        $result.TotalReplacements | Should -Be 3
    }

    It "Should create backups before modifying files" {
        $result = Invoke-SearchReplace -Path $script:testRoot -GlobPattern "*.txt" `
            -SearchPattern "localhost" -ReplaceWith "production.server" -CreateBackup
        $result.Backups.Count | Should -BeGreaterThan 0
        $result.Backups | ForEach-Object { Test-Path $_ | Should -Be $true }
    }

    It "Should support preview mode without modifying files" {
        $result = Invoke-SearchReplace -Path $script:testRoot -GlobPattern "*.txt" `
            -SearchPattern "localhost" -ReplaceWith "production.server" -Preview
        # Files should NOT be modified in preview mode
        $content = Get-Content "$($script:testRoot)/config.txt"
        $content[0] | Should -Be "server=localhost"
        # But should still return the preview of changes
        $result.Changes.Count | Should -BeGreaterThan 0
        $result.PreviewOnly | Should -Be $true
    }

    It "Should handle regex replacement patterns" {
        Set-Content -Path "$($script:testRoot)/regex.txt" -Value @(
            "date: 2024-01-15"
            "date: 2024-06-30"
        )
        $result = Invoke-SearchReplace -Path $script:testRoot -GlobPattern "regex.txt" `
            -SearchPattern "(\d{4})-(\d{2})-(\d{2})" -ReplaceWith '$2/$3/$1'
        $content = Get-Content "$($script:testRoot)/regex.txt"
        $content[0] | Should -Be "date: 01/15/2024"
        $content[1] | Should -Be "date: 06/30/2024"
    }

    It "Should return empty changes when no matches found" {
        $result = Invoke-SearchReplace -Path $script:testRoot -GlobPattern "*.txt" `
            -SearchPattern "nonexistent_string" -ReplaceWith "replacement"
        @($result.Changes).Count | Should -Be 0
        $result.TotalFilesModified | Should -Be 0
        $result.TotalReplacements | Should -Be 0
    }
}

# ============================================================
# TDD Round 6 (RED then GREEN): Error handling
# ============================================================
Describe "Error Handling" {
    It "Find-MatchingFiles should throw for non-existent path" {
        { Find-MatchingFiles -Path "/nonexistent/path/xyz" -GlobPattern "*.txt" } |
            Should -Throw "*does not exist*"
    }

    It "Search-InFiles should handle empty file list gracefully" {
        $results = Search-InFiles -Files @() -Pattern "test"
        @($results).Count | Should -Be 0
    }

    It "Search-InFiles should throw for invalid regex" {
        $files = @()
        # Invalid regex pattern with unmatched bracket
        { Search-InFiles -Files $files -Pattern "[invalid" } |
            Should -Throw
    }

    It "New-FileBackup should throw for non-existent file" {
        { New-FileBackup -FilePath "/nonexistent/file.txt" } |
            Should -Throw "*does not exist*"
    }

    It "Invoke-SearchReplace should throw for non-existent path" {
        { Invoke-SearchReplace -Path "/nonexistent/path" -GlobPattern "*.txt" `
            -SearchPattern "a" -ReplaceWith "b" } |
            Should -Throw "*does not exist*"
    }
}
