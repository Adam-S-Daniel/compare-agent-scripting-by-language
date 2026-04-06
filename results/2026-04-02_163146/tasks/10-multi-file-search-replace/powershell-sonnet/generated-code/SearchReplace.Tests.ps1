# SearchReplace.Tests.ps1
# Pester tests for the multi-file search-and-replace tool.
# TDD approach: each Describe/It block was written BEFORE the corresponding
# implementation code in SearchReplace.ps1.

# Requires Pester v5+
BeforeAll {
    # Import the module under test
    . "$PSScriptRoot/SearchReplace.ps1"
}

# ---------------------------------------------------------------------------
# Helper: build a temporary directory tree with fixture files
# ---------------------------------------------------------------------------
function New-TestFixtureTree {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("SR_Tests_" + [System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $root | Out-Null

    # src/app.txt
    $src = Join-Path $root "src"
    New-Item -ItemType Directory -Path $src | Out-Null
    Set-Content -Path (Join-Path $src "app.txt") -Value @"
Hello World
This is a test file.
foo bar baz
The quick brown fox jumps over the lazy dog.
foo again
"@

    # src/readme.md
    Set-Content -Path (Join-Path $src "readme.md") -Value @"
# My Project
TODO: write docs
foo is a placeholder
"@

    # src/sub/util.txt
    $sub = Join-Path $src "sub"
    New-Item -ItemType Directory -Path $sub | Out-Null
    Set-Content -Path (Join-Path $sub "util.txt") -Value @"
utility functions
no match here
foo utility
"@

    # data/data.csv  (should NOT match *.txt glob)
    $data = Join-Path $root "data"
    New-Item -ItemType Directory -Path $data | Out-Null
    Set-Content -Path (Join-Path $data "data.csv") -Value @"
id,name,value
1,foo,100
"@

    return $root
}

# ---------------------------------------------------------------------------
# RED TEST 1 – Find-Matches: basic pattern search returns correct results
# ---------------------------------------------------------------------------
Describe 'Find-Matches' {
    BeforeEach {
        $script:fixtureRoot = New-TestFixtureTree
    }
    AfterEach {
        Remove-Item -Recurse -Force $script:fixtureRoot
    }

    It 'returns match objects for every occurrence of the pattern in matched files' {
        $results = Find-Matches -RootPath $script:fixtureRoot -GlobPattern '*.txt' -SearchPattern 'foo'

        # app.txt has 2 "foo" lines, util.txt has 1 — data.csv is excluded
        $results | Should -HaveCount 3
    }

    It 'each result contains FilePath, LineNumber, LineContent properties' {
        $results = Find-Matches -RootPath $script:fixtureRoot -GlobPattern '*.txt' -SearchPattern 'foo'
        $r = $results[0]
        $r.PSObject.Properties.Name | Should -Contain 'FilePath'
        $r.PSObject.Properties.Name | Should -Contain 'LineNumber'
        $r.PSObject.Properties.Name | Should -Contain 'LineContent'
    }

    It 'LineNumber is the 1-based line number of the match' {
        $results = Find-Matches -RootPath $script:fixtureRoot -GlobPattern '*.txt' -SearchPattern 'foo'
        # In app.txt, "foo bar baz" is line 3
        $appMatches = $results | Where-Object { $_.FilePath -like '*app.txt' } | Sort-Object LineNumber
        $appMatches[0].LineNumber | Should -Be 3
    }

    It 'returns empty collection when pattern has no matches' {
        $results = Find-Matches -RootPath $script:fixtureRoot -GlobPattern '*.txt' -SearchPattern 'NOMATCH_XYZ'
        $results | Should -HaveCount 0
    }

    It 'respects the glob pattern — csv files are excluded for *.txt' {
        $results = Find-Matches -RootPath $script:fixtureRoot -GlobPattern '*.txt' -SearchPattern 'foo'
        $csvMatches = $results | Where-Object { $_.FilePath -like '*.csv' }
        $csvMatches | Should -HaveCount 0
    }

    It 'supports regex patterns' {
        $results = Find-Matches -RootPath $script:fixtureRoot -GlobPattern '*.txt' -SearchPattern 'foo\s+\w+'
        # "foo bar baz", "foo again", "foo utility" all match
        $results | Should -HaveCount 3
    }
}

# ---------------------------------------------------------------------------
# RED TEST 2 – Invoke-Preview: prints matches with context, no file changes
# ---------------------------------------------------------------------------
Describe 'Invoke-Preview' {
    BeforeEach {
        $script:fixtureRoot = New-TestFixtureTree
    }
    AfterEach {
        Remove-Item -Recurse -Force $script:fixtureRoot
    }

    It 'returns preview objects without modifying files' {
        $before = Get-Content (Join-Path $script:fixtureRoot 'src/app.txt') -Raw

        $previews = Invoke-Preview -RootPath $script:fixtureRoot -GlobPattern '*.txt' `
                                   -SearchPattern 'foo' -ReplacePattern 'BAR'

        $after = Get-Content (Join-Path $script:fixtureRoot 'src/app.txt') -Raw
        $before | Should -Be $after   # file must be unchanged
        $previews | Should -Not -BeNullOrEmpty
    }

    It 'each preview object has OldText and NewText properties' {
        $previews = Invoke-Preview -RootPath $script:fixtureRoot -GlobPattern '*.txt' `
                                   -SearchPattern 'foo' -ReplacePattern 'BAR'
        $p = $previews[0]
        $p.PSObject.Properties.Name | Should -Contain 'OldText'
        $p.PSObject.Properties.Name | Should -Contain 'NewText'
        $p.PSObject.Properties.Name | Should -Contain 'FilePath'
        $p.PSObject.Properties.Name | Should -Contain 'LineNumber'
    }

    It 'NewText shows the result of the replacement on that line' {
        $previews = Invoke-Preview -RootPath $script:fixtureRoot -GlobPattern '*.txt' `
                                   -SearchPattern 'foo' -ReplacePattern 'BAR'
        $p = $previews | Where-Object { $_.OldText -eq 'foo bar baz' } | Select-Object -First 1
        $p.NewText | Should -Be 'BAR bar baz'
    }
}

# ---------------------------------------------------------------------------
# RED TEST 3 – Invoke-SearchReplace: performs actual replacement
# ---------------------------------------------------------------------------
Describe 'Invoke-SearchReplace' {
    BeforeEach {
        $script:fixtureRoot = New-TestFixtureTree
    }
    AfterEach {
        Remove-Item -Recurse -Force $script:fixtureRoot
    }

    It 'replaces matching text in files' {
        Invoke-SearchReplace -RootPath $script:fixtureRoot -GlobPattern '*.txt' `
                             -SearchPattern 'foo' -ReplacePattern 'BAR' | Out-Null

        $content = Get-Content (Join-Path $script:fixtureRoot 'src/app.txt') -Raw
        $content | Should -Match 'BAR bar baz'
        $content | Should -Not -Match '^foo\b'
    }

    It 'returns a summary report array' {
        $report = Invoke-SearchReplace -RootPath $script:fixtureRoot -GlobPattern '*.txt' `
                                       -SearchPattern 'foo' -ReplacePattern 'BAR'
        $report | Should -Not -BeNullOrEmpty
    }

    It 'summary report entries have required properties' {
        $report = Invoke-SearchReplace -RootPath $script:fixtureRoot -GlobPattern '*.txt' `
                                       -SearchPattern 'foo' -ReplacePattern 'BAR'
        $entry = $report[0]
        $entry.PSObject.Properties.Name | Should -Contain 'FilePath'
        $entry.PSObject.Properties.Name | Should -Contain 'LineNumber'
        $entry.PSObject.Properties.Name | Should -Contain 'OldText'
        $entry.PSObject.Properties.Name | Should -Contain 'NewText'
    }

    It 'does not modify files that have no matches' {
        $csvPath = Join-Path $script:fixtureRoot 'data/data.csv'
        $before = Get-Content $csvPath -Raw

        Invoke-SearchReplace -RootPath $script:fixtureRoot -GlobPattern '*.txt' `
                             -SearchPattern 'foo' -ReplacePattern 'BAR' | Out-Null

        $after = Get-Content $csvPath -Raw
        $before | Should -Be $after
    }

    It 'report contains one entry per changed line' {
        $report = Invoke-SearchReplace -RootPath $script:fixtureRoot -GlobPattern '*.txt' `
                                       -SearchPattern 'foo' -ReplacePattern 'BAR'
        # app.txt: 2 foo lines; util.txt: 1 foo line
        $report | Should -HaveCount 3
    }
}

# ---------------------------------------------------------------------------
# RED TEST 4 – Backup creation
# ---------------------------------------------------------------------------
Describe 'Backup Creation' {
    BeforeEach {
        $script:fixtureRoot = New-TestFixtureTree
    }
    AfterEach {
        Remove-Item -Recurse -Force $script:fixtureRoot
    }

    It 'creates a .bak file alongside each modified file' {
        Invoke-SearchReplace -RootPath $script:fixtureRoot -GlobPattern '*.txt' `
                             -SearchPattern 'foo' -ReplacePattern 'BAR' -Backup | Out-Null

        $bakFiles = Get-ChildItem -Recurse -Path $script:fixtureRoot -Filter '*.bak'
        # app.txt and util.txt have matches, so 2 bak files
        $bakFiles | Should -HaveCount 2
    }

    It 'the .bak file preserves the original content' {
        $originalContent = Get-Content (Join-Path $script:fixtureRoot 'src/app.txt') -Raw

        Invoke-SearchReplace -RootPath $script:fixtureRoot -GlobPattern '*.txt' `
                             -SearchPattern 'foo' -ReplacePattern 'BAR' -Backup | Out-Null

        $bakContent = Get-Content (Join-Path $script:fixtureRoot 'src/app.txt.bak') -Raw
        $bakContent | Should -Be $originalContent
    }

    It 'does NOT create a .bak file when -Backup switch is absent' {
        Invoke-SearchReplace -RootPath $script:fixtureRoot -GlobPattern '*.txt' `
                             -SearchPattern 'foo' -ReplacePattern 'BAR' | Out-Null

        $bakFiles = Get-ChildItem -Recurse -Path $script:fixtureRoot -Filter '*.bak'
        $bakFiles | Should -HaveCount 0
    }
}

# ---------------------------------------------------------------------------
# RED TEST 5 – Error handling
# ---------------------------------------------------------------------------
Describe 'Error Handling' {
    It 'throws a meaningful error when RootPath does not exist' {
        { Find-Matches -RootPath 'C:\NonExistent\Path\XYZ' -GlobPattern '*.txt' -SearchPattern 'foo' } |
            Should -Throw -ExpectedMessage '*does not exist*'
    }

    It 'throws a meaningful error when SearchPattern is an invalid regex' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("SR_Err_" + [System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            { Find-Matches -RootPath $tmp -GlobPattern '*.txt' -SearchPattern '[invalid(regex' } |
                Should -Throw -ExpectedMessage '*invalid*'
        } finally {
            Remove-Item -Recurse -Force $tmp
        }
    }
}
