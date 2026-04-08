Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import the module under test
BeforeAll {
    . "$PSScriptRoot/SearchReplace.ps1"
}

Describe 'Find-MatchingFiles' {
    BeforeAll {
        # Create a temporary directory structure for testing
        $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "sr-test-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestRoot 'sub1') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestRoot 'sub2') -Force | Out-Null

        # Create test files
        Set-Content -Path (Join-Path $script:TestRoot 'file1.txt') -Value 'hello world'
        Set-Content -Path (Join-Path $script:TestRoot 'file2.log') -Value 'log entry'
        Set-Content -Path (Join-Path $script:TestRoot 'sub1/file3.txt') -Value 'nested hello'
        Set-Content -Path (Join-Path $script:TestRoot 'sub2/file4.txt') -Value 'deep nested'
        Set-Content -Path (Join-Path $script:TestRoot 'sub2/file5.log') -Value 'deep log'
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:TestRoot -ErrorAction SilentlyContinue
    }

    It 'Should find all .txt files recursively' {
        [array]$result = @(Find-MatchingFiles -Path $script:TestRoot -GlobPattern '*.txt')
        $result.Count | Should -Be 3
    }

    It 'Should find all .log files recursively' {
        [array]$result = @(Find-MatchingFiles -Path $script:TestRoot -GlobPattern '*.log')
        $result.Count | Should -Be 2
    }

    It 'Should return empty for non-matching pattern' {
        [array]$result = @(Find-MatchingFiles -Path $script:TestRoot -GlobPattern '*.csv')
        $result.Count | Should -Be 0
    }

    It 'Should throw for non-existent directory' {
        { Find-MatchingFiles -Path '/no/such/dir' -GlobPattern '*.txt' } | Should -Throw 'Directory not found*'
    }
}

Describe 'Search-FileContent (preview mode)' {
    BeforeAll {
        $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "sr-preview-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null

        # Multi-line file with known content for context testing
        $lines = @(
            'line one apple'
            'line two banana'
            'line three apple pie'
            'line four cherry'
            'line five apple sauce'
        )
        Set-Content -Path (Join-Path $script:TestRoot 'fruits.txt') -Value ($lines -join "`n") -NoNewline

        # File with no matches
        Set-Content -Path (Join-Path $script:TestRoot 'empty.txt') -Value 'no match here'
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:TestRoot -ErrorAction SilentlyContinue
    }

    It 'Should find all regex matches with line numbers' {
        [string]$file = Join-Path $script:TestRoot 'fruits.txt'
        [array]$matches = @(Search-FileContent -FilePath $file -SearchPattern 'apple')
        $matches.Count | Should -Be 3
        $matches[0].LineNumber | Should -Be 1
        $matches[0].LineText | Should -BeLike '*apple*'
        $matches[1].LineNumber | Should -Be 3
        $matches[2].LineNumber | Should -Be 5
    }

    It 'Should include context lines around matches' {
        [string]$file = Join-Path $script:TestRoot 'fruits.txt'
        [array]$matches = @(Search-FileContent -FilePath $file -SearchPattern 'banana' -ContextLines 1)
        $matches.Count | Should -Be 1
        $matches[0].ContextBefore.Count | Should -Be 1
        $matches[0].ContextAfter.Count | Should -Be 1
    }

    It 'Should return empty for no matches' {
        [string]$file = Join-Path $script:TestRoot 'empty.txt'
        [array]$matches = @(Search-FileContent -FilePath $file -SearchPattern 'zzz')
        $matches.Count | Should -Be 0
    }
}

Describe 'Backup-File' {
    BeforeAll {
        $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "sr-backup-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
        Set-Content -Path (Join-Path $script:TestRoot 'original.txt') -Value 'original content'
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:TestRoot -ErrorAction SilentlyContinue
    }

    It 'Should create a .bak copy of the file' {
        [string]$src = Join-Path $script:TestRoot 'original.txt'
        [string]$bakPath = Backup-File -FilePath $src
        $bakPath | Should -BeLike '*.bak'
        Test-Path -LiteralPath $bakPath | Should -BeTrue
        Get-Content -LiteralPath $bakPath | Should -Be 'original content'
    }

    It 'Should preserve original file after backup' {
        [string]$src = Join-Path $script:TestRoot 'original.txt'
        Backup-File -FilePath $src | Out-Null
        Get-Content -LiteralPath $src | Should -Be 'original content'
    }
}

Describe 'Invoke-SearchReplace' {
    BeforeAll {
        $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "sr-replace-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestRoot 'sub') -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:TestRoot -ErrorAction SilentlyContinue
    }

    Context 'Preview mode' {
        BeforeAll {
            Set-Content -Path (Join-Path $script:TestRoot 'preview.txt') -Value "foo bar`nfoo baz`nqux"
        }

        It 'Should show matches without modifying the file' {
            [array]$report = @(Invoke-SearchReplace `
                -Path $script:TestRoot `
                -GlobPattern '*.txt' `
                -SearchPattern 'foo' `
                -ReplaceWith 'REPLACED' `
                -Preview)
            $report.Count | Should -BeGreaterThan 0
            # File should NOT be changed in preview mode
            [string]$content = Get-Content -LiteralPath (Join-Path $script:TestRoot 'preview.txt') -Raw
            $content | Should -BeLike '*foo*'
        }
    }

    Context 'Actual replacement with backup' {
        BeforeAll {
            Set-Content -Path (Join-Path $script:TestRoot 'replace.txt') -Value "hello world`nhello universe"
            Set-Content -Path (Join-Path $script:TestRoot 'sub/nested.txt') -Value "hello deep"
        }

        It 'Should replace matches and create backups' {
            [array]$report = @(Invoke-SearchReplace `
                -Path $script:TestRoot `
                -GlobPattern '*.txt' `
                -SearchPattern 'hello' `
                -ReplaceWith 'GREET')

            # Verify replacements happened
            [string]$content = Get-Content -LiteralPath (Join-Path $script:TestRoot 'replace.txt') -Raw
            $content | Should -BeLike '*GREET*'
            $content | Should -Not -BeLike '*hello*'

            # Verify backup exists
            Test-Path -LiteralPath (Join-Path $script:TestRoot 'replace.txt.bak') | Should -BeTrue
        }

        It 'Should return a summary report with file, line, old, new' {
            # Reset the file
            Set-Content -Path (Join-Path $script:TestRoot 'report.txt') -Value "cat dog`ncat fish"
            [array]$report = @(Invoke-SearchReplace `
                -Path $script:TestRoot `
                -GlobPattern 'report.txt' `
                -SearchPattern 'cat' `
                -ReplaceWith 'PET')

            $report.Count | Should -Be 2
            $report[0].File | Should -BeLike '*report.txt'
            $report[0].LineNumber | Should -Be 1
            $report[0].OldText | Should -Be 'cat dog'
            $report[0].NewText | Should -Be 'PET dog'
            $report[1].LineNumber | Should -Be 2
        }
    }

    Context 'No matches' {
        BeforeAll {
            Set-Content -Path (Join-Path $script:TestRoot 'nomatch.txt') -Value 'nothing here'
        }

        It 'Should return empty report when no matches found' {
            [array]$report = @(Invoke-SearchReplace `
                -Path $script:TestRoot `
                -GlobPattern 'nomatch.txt' `
                -SearchPattern 'zzzzz' `
                -ReplaceWith 'xxx')
            $report.Count | Should -Be 0
        }
    }

    Context 'Regex patterns with capture groups' {
        BeforeAll {
            Set-Content -Path (Join-Path $script:TestRoot 'regex.txt') -Value "version=1.2.3`nversion=4.5.6"
        }

        It 'Should support regex capture group references in replacement' {
            [array]$report = @(Invoke-SearchReplace `
                -Path $script:TestRoot `
                -GlobPattern 'regex.txt' `
                -SearchPattern 'version=(\d+\.\d+\.\d+)' `
                -ReplaceWith 'ver=$1')
            $report.Count | Should -Be 2
            $report[0].NewText | Should -Be 'ver=1.2.3'
            $report[1].NewText | Should -Be 'ver=4.5.6'
        }
    }

    Context 'Multiple replacements on same line' {
        BeforeAll {
            Set-Content -Path (Join-Path $script:TestRoot 'multi.txt') -Value 'aaa bbb aaa'
        }

        It 'Should replace all occurrences on a single line' {
            [array]$report = @(Invoke-SearchReplace `
                -Path $script:TestRoot `
                -GlobPattern 'multi.txt' `
                -SearchPattern 'aaa' `
                -ReplaceWith 'ZZZ')
            $report.Count | Should -Be 1
            $report[0].NewText | Should -Be 'ZZZ bbb ZZZ'
        }
    }

    Context 'Deeply nested directories' {
        BeforeAll {
            [string]$deep = Join-Path $script:TestRoot 'a/b/c'
            New-Item -ItemType Directory -Path $deep -Force | Out-Null
            Set-Content -Path (Join-Path $deep 'deep.txt') -Value 'deep match'
        }

        It 'Should find and replace in deeply nested files' {
            [array]$report = @(Invoke-SearchReplace `
                -Path $script:TestRoot `
                -GlobPattern '*.txt' `
                -SearchPattern 'deep' `
                -ReplaceWith 'DEEP' `
                -Preview)
            # At least the deep file should be found
            [array]$deepEntries = @($report | Where-Object { $_.File -like '*a*b*c*' })
            $deepEntries.Count | Should -BeGreaterThan 0
        }
    }
}

Describe 'Format-PreviewReport' {
    BeforeAll {
        $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "sr-format-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
        Set-Content -Path (Join-Path $script:TestRoot 'fmt.txt') -Value "alpha beta`ngamma alpha"
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:TestRoot -ErrorAction SilentlyContinue
    }

    It 'Should produce a human-readable string report' {
        [array]$entries = @(Invoke-SearchReplace `
            -Path $script:TestRoot `
            -GlobPattern '*.txt' `
            -SearchPattern 'alpha' `
            -ReplaceWith 'OMEGA' `
            -Preview)
        [string]$formatted = Format-PreviewReport -ReportEntries $entries
        $formatted | Should -BeLike '*fmt.txt*'
        $formatted | Should -BeLike '*alpha*'
        $formatted | Should -BeLike '*OMEGA*'
        $formatted | Should -BeLike '*Line 1*'
    }
}
