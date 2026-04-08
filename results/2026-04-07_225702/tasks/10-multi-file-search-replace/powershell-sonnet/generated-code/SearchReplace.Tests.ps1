# SearchReplace.Tests.ps1
# TDD test suite for multi-file search-and-replace functionality using Pester 5.x

BeforeAll {
    . "$PSScriptRoot/SearchReplace.ps1"
}

Describe "Find-FileMatches" {
    BeforeAll {
        # Create a temp test fixture directory
        $script:TestRoot = Join-Path $TestDrive "fixture"
        New-Item -ItemType Directory -Path $script:TestRoot | Out-Null

        # Sub-dir structure:
        # fixture/
        #   a.txt       -> "Hello World\nFoo bar\n"
        #   b.txt       -> "no match here\n"
        #   sub/
        #     c.txt     -> "Hello again\n"
        #     d.log     -> "Hello log\n"

        Set-Content "$script:TestRoot/a.txt"       -Value "Hello World`nFoo bar"
        Set-Content "$script:TestRoot/b.txt"       -Value "no match here"
        New-Item -ItemType Directory "$script:TestRoot/sub" | Out-Null
        Set-Content "$script:TestRoot/sub/c.txt"   -Value "Hello again"
        Set-Content "$script:TestRoot/sub/d.log"   -Value "Hello log"
    }

    Context "basic match discovery" {
        It "returns match objects for files containing the pattern" {
            $results = Find-FileMatches -Path $script:TestRoot -GlobPattern "*.txt" -SearchPattern "Hello"
            # a.txt line 1 and sub/c.txt line 1 should match
            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -Be 2
        }

        It "each match object has File, LineNumber, LineText properties" {
            $results = Find-FileMatches -Path $script:TestRoot -GlobPattern "*.txt" -SearchPattern "Hello"
            $results[0].PSObject.Properties.Name | Should -Contain "File"
            $results[0].PSObject.Properties.Name | Should -Contain "LineNumber"
            $results[0].PSObject.Properties.Name | Should -Contain "LineText"
        }

        It "does not match files excluded by glob" {
            # *.log files should not be searched when glob is *.txt
            $results = Find-FileMatches -Path $script:TestRoot -GlobPattern "*.txt" -SearchPattern "Hello"
            $results | ForEach-Object { $_.File | Should -Match '\.txt$' }
        }

        It "returns empty when no files match glob" {
            $results = Find-FileMatches -Path $script:TestRoot -GlobPattern "*.xyz" -SearchPattern "Hello"
            $results | Should -BeNullOrEmpty
        }

        It "returns empty when pattern not found in any file" {
            $results = Find-FileMatches -Path $script:TestRoot -GlobPattern "*.txt" -SearchPattern "NOTFOUND"
            $results | Should -BeNullOrEmpty
        }
    }

    Context "line number accuracy" {
        It "reports correct line number for a match on line 2" {
            $results = Find-FileMatches -Path $script:TestRoot -GlobPattern "*.txt" -SearchPattern "Foo"
            $results.Count | Should -Be 1
            $results[0].LineNumber | Should -Be 2
            $results[0].LineText   | Should -Be "Foo bar"
        }
    }
}

Describe "Invoke-SearchReplace (preview mode)" {
    BeforeAll {
        $script:TestRoot = Join-Path $TestDrive "preview"
        New-Item -ItemType Directory -Path $script:TestRoot | Out-Null
        Set-Content "$script:TestRoot/file1.txt" -Value "cat sat on mat`nthe cat is fat"
        Set-Content "$script:TestRoot/file2.txt" -Value "no animals here"
    }

    It "returns a report without modifying files when -Preview is set" {
        $report = Invoke-SearchReplace `
            -Path          $script:TestRoot `
            -GlobPattern   "*.txt" `
            -SearchPattern "cat" `
            -Replacement   "dog" `
            -Preview

        # Files must be unchanged
        $content = Get-Content "$script:TestRoot/file1.txt" -Raw
        $content | Should -Match "cat"   # original still there
        $content | Should -Not -Match "dog"

        # But report should list the prospective changes
        $report | Should -Not -BeNullOrEmpty
    }

    It "report entries have File, LineNumber, OldText, NewText" {
        $report = Invoke-SearchReplace `
            -Path          $script:TestRoot `
            -GlobPattern   "*.txt" `
            -SearchPattern "cat" `
            -Replacement   "dog" `
            -Preview

        $report[0].PSObject.Properties.Name | Should -Contain "File"
        $report[0].PSObject.Properties.Name | Should -Contain "LineNumber"
        $report[0].PSObject.Properties.Name | Should -Contain "OldText"
        $report[0].PSObject.Properties.Name | Should -Contain "NewText"
    }

    It "NewText reflects the substitution" {
        $report = Invoke-SearchReplace `
            -Path          $script:TestRoot `
            -GlobPattern   "*.txt" `
            -SearchPattern "cat" `
            -Replacement   "dog" `
            -Preview

        $entry = $report | Where-Object { $_.LineNumber -eq 1 -and $_.OldText -match "cat sat" }
        $entry | Should -Not -BeNullOrEmpty
        $entry.NewText | Should -Be "dog sat on mat"
    }
}

Describe "Invoke-SearchReplace (live mode with backup)" {
    BeforeEach {
        # Fresh fixture for each test so mutations don't bleed
        $script:TestRoot = Join-Path $TestDrive ("live_" + [System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $script:TestRoot | Out-Null
        Set-Content "$script:TestRoot/alpha.txt" -Value "foo is great`nfoo again"
        Set-Content "$script:TestRoot/beta.txt"  -Value "nothing to see"
    }

    It "modifies file content in-place" {
        Invoke-SearchReplace `
            -Path          $script:TestRoot `
            -GlobPattern   "*.txt" `
            -SearchPattern "foo" `
            -Replacement   "bar"

        $content = Get-Content "$script:TestRoot/alpha.txt" -Raw
        $content | Should -Not -Match "\bfoo\b"
        $content | Should -Match "bar"
    }

    It "creates a .bak backup before modifying" {
        Invoke-SearchReplace `
            -Path          $script:TestRoot `
            -GlobPattern   "*.txt" `
            -SearchPattern "foo" `
            -Replacement   "bar"

        Test-Path "$script:TestRoot/alpha.bak" | Should -Be $true
    }

    It "backup contains original content" {
        Invoke-SearchReplace `
            -Path          $script:TestRoot `
            -GlobPattern   "*.txt" `
            -SearchPattern "foo" `
            -Replacement   "bar"

        $backup = Get-Content "$script:TestRoot/alpha.bak" -Raw
        $backup | Should -Match "foo"
    }

    It "does not create a backup for files with no matches" {
        Invoke-SearchReplace `
            -Path          $script:TestRoot `
            -GlobPattern   "*.txt" `
            -SearchPattern "foo" `
            -Replacement   "bar"

        Test-Path "$script:TestRoot/beta.bak" | Should -Be $false
    }

    It "returns a summary report" {
        $report = Invoke-SearchReplace `
            -Path          $script:TestRoot `
            -GlobPattern   "*.txt" `
            -SearchPattern "foo" `
            -Replacement   "bar"

        $report | Should -Not -BeNullOrEmpty
        $report.Count | Should -Be 2   # two lines with "foo"
    }

    It "report entries contain correct metadata" {
        $report = Invoke-SearchReplace `
            -Path          $script:TestRoot `
            -GlobPattern   "*.txt" `
            -SearchPattern "foo" `
            -Replacement   "bar"

        $entry = $report | Where-Object { $_.LineNumber -eq 1 }
        $entry.OldText | Should -Be "foo is great"
        $entry.NewText | Should -Be "bar is great"
    }
}

Describe "Error handling" {
    It "throws a meaningful error when path does not exist" {
        { Find-FileMatches -Path "/nonexistent/path" -GlobPattern "*.txt" -SearchPattern "x" } |
            Should -Throw "*does not exist*"
    }

    It "throws a meaningful error for an invalid regex" {
        $root = Join-Path $TestDrive "err_regex"
        New-Item -ItemType Directory $root | Out-Null
        Set-Content "$root/f.txt" -Value "hello"

        { Find-FileMatches -Path $root -GlobPattern "*.txt" -SearchPattern "[invalid" } |
            Should -Throw "*invalid*"
    }
}
