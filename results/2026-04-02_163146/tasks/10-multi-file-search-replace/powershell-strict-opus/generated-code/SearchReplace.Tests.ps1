Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    . "$PSScriptRoot/SearchReplace.ps1"
}

Describe 'Find-PatternInFiles' {
    BeforeEach {
        # Create a temp directory with test files
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "sr-test-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:testDir) {
            Remove-Item -Recurse -Force $script:testDir
        }
    }

    It 'Should find matches in files matching a glob pattern' {
        # Arrange: create test files
        Set-Content -Path (Join-Path $script:testDir 'file1.txt') -Value "Hello World`nFoo Bar`nHello Again"
        Set-Content -Path (Join-Path $script:testDir 'file2.txt') -Value "No match here"
        Set-Content -Path (Join-Path $script:testDir 'file3.log') -Value "Hello Log"

        # Act: search for 'Hello' in *.txt files
        [array]$results = Find-PatternInFiles -Path $script:testDir -FilePattern '*.txt' -SearchPattern 'Hello'

        # Assert
        $results.Count | Should -Be 2  # file1.txt has 2 matches
        $results[0].FileName | Should -BeLike '*file1.txt'
        $results[0].LineNumber | Should -Be 1
        $results[0].LineText | Should -Be 'Hello World'
        $results[1].LineNumber | Should -Be 3
        $results[1].LineText | Should -Be 'Hello Again'
    }

    It 'Should search recursively in subdirectories' {
        # Arrange
        $subDir = Join-Path $script:testDir 'sub'
        New-Item -ItemType Directory -Path $subDir -Force | Out-Null
        Set-Content -Path (Join-Path $script:testDir 'root.txt') -Value "match here"
        Set-Content -Path (Join-Path $subDir 'nested.txt') -Value "match there"

        # Act
        [array]$results = Find-PatternInFiles -Path $script:testDir -FilePattern '*.txt' -SearchPattern 'match'

        # Assert
        $results.Count | Should -Be 2
    }

    It 'Should support regex patterns' {
        # Arrange
        Set-Content -Path (Join-Path $script:testDir 'code.txt') -Value "foo123`nbar456`nfoo789"

        # Act
        [array]$results = Find-PatternInFiles -Path $script:testDir -FilePattern '*.txt' -SearchPattern 'foo\d+'

        # Assert
        $results.Count | Should -Be 2
        $results[0].LineText | Should -Be 'foo123'
        $results[1].LineText | Should -Be 'foo789'
    }

    It 'Should return empty array when no matches found' {
        # Arrange
        Set-Content -Path (Join-Path $script:testDir 'empty.txt') -Value "nothing relevant"

        # Act
        [array]$results = Find-PatternInFiles -Path $script:testDir -FilePattern '*.txt' -SearchPattern 'ZZZZZ'

        # Assert: empty array when cast with [array] on $null gives single-element $null array,
        # so check the raw output
        $raw = Find-PatternInFiles -Path $script:testDir -FilePattern '*.txt' -SearchPattern 'ZZZZZ'
        $raw | Should -BeNullOrEmpty
    }
}

Describe 'Get-MatchPreview' {
    BeforeEach {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "sr-test-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:testDir) {
            Remove-Item -Recurse -Force $script:testDir
        }
    }

    It 'Should show matches with surrounding context lines' {
        # Arrange
        $content = @(
            "line 1"
            "line 2"
            "MATCH line 3"
            "line 4"
            "line 5"
        ) -join "`n"
        Set-Content -Path (Join-Path $script:testDir 'ctx.txt') -Value $content

        # Act
        [array]$previews = Get-MatchPreview -Path $script:testDir -FilePattern '*.txt' -SearchPattern 'MATCH' -ContextLines ([int]1)

        # Assert
        $previews.Count | Should -Be 1
        $previews[0].MatchLine | Should -Be 'MATCH line 3'
        $previews[0].ContextBefore | Should -Contain 'line 2'
        $previews[0].ContextAfter | Should -Contain 'line 4'
    }

    It 'Should show what the replacement would look like' {
        # Arrange
        Set-Content -Path (Join-Path $script:testDir 'rep.txt') -Value "Hello World"

        # Act
        [array]$previews = Get-MatchPreview -Path $script:testDir -FilePattern '*.txt' -SearchPattern 'Hello' -ReplacePattern 'Goodbye' -ContextLines ([int]0)

        # Assert
        $previews[0].MatchLine | Should -Be 'Hello World'
        $previews[0].ReplacementLine | Should -Be 'Goodbye World'
    }
}

Describe 'Invoke-SearchReplace' {
    BeforeEach {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "sr-test-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:testDir) {
            Remove-Item -Recurse -Force $script:testDir
        }
    }

    It 'Should replace matched text in files' {
        # Arrange
        Set-Content -Path (Join-Path $script:testDir 'target.txt') -Value "Hello World`nHello Again"

        # Act
        $report = Invoke-SearchReplace -Path $script:testDir -FilePattern '*.txt' -SearchPattern 'Hello' -ReplacePattern 'Goodbye'

        # Assert: file content changed
        $newContent = Get-Content -Path (Join-Path $script:testDir 'target.txt')
        $newContent[0] | Should -Be 'Goodbye World'
        $newContent[1] | Should -Be 'Goodbye Again'
    }

    It 'Should create backup files before modifying' {
        # Arrange
        $filePath = Join-Path $script:testDir 'backup-test.txt'
        Set-Content -Path $filePath -Value "Original Content"

        # Act
        $report = Invoke-SearchReplace -Path $script:testDir -FilePattern '*.txt' -SearchPattern 'Original' -ReplacePattern 'Modified' -CreateBackup

        # Assert: backup exists with original content
        $backupPath = "$filePath.bak"
        Test-Path $backupPath | Should -BeTrue
        (Get-Content $backupPath) | Should -Be 'Original Content'

        # Assert: original file was modified
        (Get-Content $filePath) | Should -Be 'Modified Content'
    }

    It 'Should return a summary report with all changes' {
        # Arrange
        Set-Content -Path (Join-Path $script:testDir 'r1.txt') -Value "foo bar`nbaz foo"
        Set-Content -Path (Join-Path $script:testDir 'r2.txt') -Value "foo only"

        # Act
        $report = Invoke-SearchReplace -Path $script:testDir -FilePattern '*.txt' -SearchPattern 'foo' -ReplacePattern 'qux'

        # Assert: report structure
        $report | Should -Not -BeNullOrEmpty
        $report.TotalFilesModified | Should -Be 2
        $report.TotalReplacements | Should -Be 3
        $report.Changes | Should -Not -BeNullOrEmpty
        $report.Changes.Count | Should -Be 3

        # Each change should have file, line number, old text, new text
        $firstChange = $report.Changes[0]
        $firstChange.FileName | Should -Not -BeNullOrEmpty
        $firstChange.LineNumber | Should -BeGreaterThan 0
        $firstChange.OldText | Should -Not -BeNullOrEmpty
        $firstChange.NewText | Should -Not -BeNullOrEmpty
    }

    It 'Should support regex replacement with capture groups' {
        # Arrange
        Set-Content -Path (Join-Path $script:testDir 'regex.txt') -Value "John Smith`nJane Doe"

        # Act
        $report = Invoke-SearchReplace -Path $script:testDir -FilePattern '*.txt' -SearchPattern '(\w+)\s(\w+)' -ReplacePattern '$2, $1'

        # Assert
        $content = Get-Content -Path (Join-Path $script:testDir 'regex.txt')
        $content[0] | Should -Be 'Smith, John'
        $content[1] | Should -Be 'Doe, Jane'
    }

    It 'Should not modify files that have no matches' {
        # Arrange
        $matchFile = Join-Path $script:testDir 'yes.txt'
        $noMatchFile = Join-Path $script:testDir 'no.txt'
        Set-Content -Path $matchFile -Value "replace me"
        Set-Content -Path $noMatchFile -Value "leave me alone"
        $originalTimestamp = (Get-Item $noMatchFile).LastWriteTime

        # Act
        $report = Invoke-SearchReplace -Path $script:testDir -FilePattern '*.txt' -SearchPattern 'replace' -ReplacePattern 'changed'

        # Assert
        $report.TotalFilesModified | Should -Be 1
        (Get-Content $noMatchFile) | Should -Be "leave me alone"
    }
}

Describe 'Error Handling' {
    It 'Should throw when path does not exist' {
        { Find-PatternInFiles -Path '/nonexistent/path' -FilePattern '*.txt' -SearchPattern 'test' } |
            Should -Throw
    }

    It 'Should throw when search pattern is empty' {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sr-err-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        try {
            { Find-PatternInFiles -Path $tempDir -FilePattern '*.txt' -SearchPattern '' } |
                Should -Throw
        }
        finally {
            Remove-Item -Recurse -Force $tempDir
        }
    }

    It 'Should throw for invalid regex pattern' {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sr-err-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Set-Content -Path (Join-Path $tempDir 'test.txt') -Value "test"
        try {
            { Find-PatternInFiles -Path $tempDir -FilePattern '*.txt' -SearchPattern '[invalid' } |
                Should -Throw
        }
        finally {
            Remove-Item -Recurse -Force $tempDir
        }
    }
}
