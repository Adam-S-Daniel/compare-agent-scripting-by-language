# Pester unit tests for the PR Label Assigner.
#
# These tests use Pester's red/green TDD methodology. They exercise the
# library functions in Invoke-PrLabelAssigner.ps1 directly so we can
# iterate on the matcher and rule engine without paying the cost of
# spinning up an act container for every assertion. Integration tests
# that drive the full workflow live in Run-ActHarness.ps1 and write
# act-result.txt as required by the benchmark.

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot 'Invoke-PrLabelAssigner.ps1'
    . $script:ScriptPath
}

Describe 'Convert-GlobToRegex' {
    It 'converts ** to multi-segment match' {
        Convert-GlobToRegex 'docs/**' | Should -Be '^docs/.*$'
    }

    It 'converts * to single-segment match' {
        Convert-GlobToRegex 'src/*.ps1' | Should -Be '^src/[^/]*\.ps1$'
    }

    It 'converts ? to single-character non-slash match' {
        Convert-GlobToRegex 'a?b' | Should -Be '^a[^/]b$'
    }

    It 'escapes regex metacharacters that are not glob syntax' {
        Convert-GlobToRegex 'foo.bar+baz' | Should -Be '^foo\.bar\+baz$'
    }

    It 'handles ** alone as match-anything' {
        Convert-GlobToRegex '**' | Should -Be '^.*$'
    }

    It 'handles **/ prefix as match-any-directory including root' {
        # **/*.md should match foo.md, a/foo.md, a/b/foo.md
        $regex = Convert-GlobToRegex '**/*.md'
        'foo.md' | Should -Match $regex
        'a/foo.md' | Should -Match $regex
        'a/b/foo.md' | Should -Match $regex
        'foo.txt' | Should -Not -Match $regex
    }

    It 'handles /**/ in middle as match-any-directory between segments' {
        # a/**/b should match a/b, a/x/b, a/x/y/b
        $regex = Convert-GlobToRegex 'a/**/b'
        'a/b' | Should -Match $regex
        'a/x/b' | Should -Match $regex
        'a/x/y/b' | Should -Match $regex
        'a/b/c' | Should -Not -Match $regex
    }
}

Describe 'Test-PathMatchesGlob' {
    It 'matches nested path with **' {
        Test-PathMatchesGlob -Path 'docs/setup/install.md' -Pattern 'docs/**' | Should -BeTrue
    }

    It 'does not match unrelated path' {
        Test-PathMatchesGlob -Path 'src/app.ps1' -Pattern 'docs/**' | Should -BeFalse
    }

    It 'matches *.test.* pattern at any depth via **/' {
        Test-PathMatchesGlob -Path 'src/lib/foo.test.js' -Pattern '**/*.test.*' | Should -BeTrue
    }

    It 'matches a file at root with **/*' {
        Test-PathMatchesGlob -Path 'README.md' -Pattern '**/*.md' | Should -BeTrue
    }
}

Describe 'Get-LabelsForFiles' {
    BeforeAll {
        $script:rules = @(
            [pscustomobject]@{ pattern = 'docs/**'; labels = @('documentation'); priority = 10 }
            [pscustomobject]@{ pattern = 'src/api/**'; labels = @('api', 'backend'); priority = 50 }
            [pscustomobject]@{ pattern = '**/*.test.*'; labels = @('tests'); priority = 30 }
            [pscustomobject]@{ pattern = '**/*.md'; labels = @('documentation'); priority = 5 }
        )
    }

    It 'returns documentation label for a single docs file' {
        $files = @('docs/intro.md')
        $labels = Get-LabelsForFiles -Files $files -Rules $script:rules
        # docs/intro.md hits docs/** AND **/*.md -> single dedup label
        $labels | Should -Be @('documentation')
    }

    It 'returns multiple labels when distinct rules match the same file' {
        $files = @('src/api/users.test.ps1')
        $labels = Get-LabelsForFiles -Files $files -Rules $script:rules
        # Sorted by priority descending: api (50, includes backend 50), tests (30)
        $labels | Should -Contain 'api'
        $labels | Should -Contain 'backend'
        $labels | Should -Contain 'tests'
        $labels.Count | Should -Be 3
    }

    It 'deduplicates labels across multiple files and rules' {
        $files = @('docs/a.md', 'docs/b.md', 'README.md')
        $labels = Get-LabelsForFiles -Files $files -Rules $script:rules
        $labels | Should -Be @('documentation')
    }

    It 'orders labels by descending rule priority' {
        $files = @('docs/intro.md', 'src/api/users.ps1', 'tests/foo.test.ps1')
        $labels = Get-LabelsForFiles -Files $files -Rules $script:rules
        # api (50) and backend (50) before tests (30) before documentation (10)
        $labels[0] | Should -BeIn @('api', 'backend')
        $labels[1] | Should -BeIn @('api', 'backend')
        $labels[2] | Should -Be 'tests'
        $labels[3] | Should -Be 'documentation'
    }

    It 'returns an empty array when no rules match' {
        $files = @('LICENSE', 'random/file.xyz')
        $labels = Get-LabelsForFiles -Files $files -Rules $script:rules
        # Pester quirk: empty PowerShell arrays compare to $null
        @($labels).Count | Should -Be 0
    }
}

Describe 'Invoke-PrLabelAssigner end-to-end (script-level)' {
    BeforeAll {
        $script:tmp = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'case1') -Force
        $script:configPath = Join-Path $script:tmp.FullName 'rules.json'
        $script:filesPath = Join-Path $script:tmp.FullName 'changed.txt'

        $config = @{
            rules = @(
                @{ pattern = 'docs/**'; labels = @('documentation'); priority = 10 }
                @{ pattern = 'src/api/**'; labels = @('api'); priority = 50 }
                @{ pattern = '**/*.test.*'; labels = @('tests'); priority = 30 }
            )
        } | ConvertTo-Json -Depth 5
        Set-Content -Path $script:configPath -Value $config

        @('docs/intro.md', 'src/api/users.ps1', 'src/api/users.test.ps1') |
            Set-Content -Path $script:filesPath
    }

    It 'invokes the script and outputs labels in priority order' {
        $output = & $script:ScriptPath -FilesPath $script:filesPath -ConfigPath $script:configPath -Format 'csv'
        $output.Trim() | Should -Be 'api,tests,documentation'
    }

    It 'emits JSON when -Format json is requested' {
        $output = & $script:ScriptPath -FilesPath $script:filesPath -ConfigPath $script:configPath -Format 'json'
        $obj = $output | ConvertFrom-Json
        $obj.labels | Should -Be @('api', 'tests', 'documentation')
    }

    It 'fails with a meaningful error when the config file is missing' {
        $missing = Join-Path $script:tmp.FullName 'does-not-exist.json'
        { & $script:ScriptPath -FilesPath $script:filesPath -ConfigPath $missing -Format 'csv' } |
            Should -Throw '*does-not-exist.json*'
    }

    It 'fails with a meaningful error when the files list is missing' {
        $missing = Join-Path $script:tmp.FullName 'no-files.txt'
        { & $script:ScriptPath -FilesPath $missing -ConfigPath $script:configPath -Format 'csv' } |
            Should -Throw '*no-files.txt*'
    }
}
