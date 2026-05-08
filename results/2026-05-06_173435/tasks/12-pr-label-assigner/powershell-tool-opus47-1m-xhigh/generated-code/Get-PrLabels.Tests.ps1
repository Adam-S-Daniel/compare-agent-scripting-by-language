# Pester tests for the PR label assigner.
#
# These tests are developed using red/green TDD: each test was written to fail
# first, then the minimum code was added to Get-PrLabels.psm1 to make it pass.
# They cover:
#   * the glob -> regex translation (helper)
#   * the public Get-PrLabels function
#   * configuration loading
#   * error handling

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot 'Get-PrLabels.psm1'
    Import-Module $ModulePath -Force
}

Describe 'Convert-GlobToRegex' {
    It 'matches a directory-prefix glob like docs/**' {
        $rx = Convert-GlobToRegex 'docs/**'
        'docs/intro.md'      | Should -Match $rx
        'docs/sub/page.md'   | Should -Match $rx
        'src/foo.md'         | Should -Not -Match $rx
        'documentation/x.md' | Should -Not -Match $rx
    }

    It 'matches a leading **/ wildcard' {
        $rx = Convert-GlobToRegex '**/*.test.*'
        'foo.test.js'                   | Should -Match $rx
        'src/foo.test.js'               | Should -Match $rx
        'src/utils/bar.test.ts'         | Should -Match $rx
        'src/foo.js'                    | Should -Not -Match $rx
    }

    It 'matches a middle ** between literal segments' {
        $rx = Convert-GlobToRegex 'a/**/b'
        'a/b'        | Should -Match $rx
        'a/x/b'      | Should -Match $rx
        'a/x/y/b'    | Should -Match $rx
        'a/c'        | Should -Not -Match $rx
        'a/x/b/foo'  | Should -Not -Match $rx
    }

    It 'a single * does not cross directory boundaries' {
        $rx = Convert-GlobToRegex 'src/*.cs'
        'src/Foo.cs'      | Should -Match $rx
        'src/api/Foo.cs'  | Should -Not -Match $rx
    }

    It 'escapes regex metacharacters in literal segments' {
        $rx = Convert-GlobToRegex 'pkg.json'
        'pkg.json'  | Should -Match $rx
        'pkgXjson'  | Should -Not -Match $rx
    }

    It 'matches the bare ** wildcard against any path' {
        $rx = Convert-GlobToRegex '**'
        'foo'         | Should -Match $rx
        'a/b/c.txt'   | Should -Match $rx
    }
}

Describe 'Get-PrLabels - matching' {
    It 'returns no labels for an empty file list' {
        $rules = @(@{ pattern = 'docs/**'; labels = @('documentation') })
        $result = Get-PrLabels -ChangedFiles @() -Rules $rules
        $result | Should -BeNullOrEmpty
    }

    It 'returns no labels when nothing matches' {
        $rules = @(@{ pattern = 'docs/**'; labels = @('documentation') })
        $result = Get-PrLabels -ChangedFiles @('src/foo.cs') -Rules $rules
        $result | Should -BeNullOrEmpty
    }

    It 'applies a single label when one rule matches' {
        $rules = @(@{ pattern = 'docs/**'; labels = @('documentation') })
        $result = Get-PrLabels -ChangedFiles @('docs/intro.md') -Rules $rules
        $result | Should -Be @('documentation')
    }

    It 'applies multiple labels when a single file matches multiple rules' {
        $rules = @(
            @{ pattern = 'src/api/**'; labels = @('api') },
            @{ pattern = '**/*.cs';    labels = @('csharp') }
        )
        $result = Get-PrLabels -ChangedFiles @('src/api/UserController.cs') -Rules $rules
        ($result | Sort-Object) | Should -Be @('api', 'csharp')
    }

    It 'deduplicates labels across multiple files' {
        $rules = @(@{ pattern = 'docs/**'; labels = @('documentation') })
        $result = Get-PrLabels -ChangedFiles @('docs/a.md', 'docs/b.md', 'docs/c.md') -Rules $rules
        $result | Should -Be @('documentation')
    }

    It 'returns the union of labels from all matching files' {
        $rules = @(
            @{ pattern = 'docs/**';    labels = @('documentation') },
            @{ pattern = 'src/api/**'; labels = @('api') }
        )
        $result = Get-PrLabels -ChangedFiles @('docs/a.md', 'src/api/User.cs') -Rules $rules
        ($result | Sort-Object) | Should -Be @('api', 'documentation')
    }

    It 'normalizes backslash separators to forward slashes' {
        $rules = @(@{ pattern = 'docs/**'; labels = @('documentation') })
        $result = Get-PrLabels -ChangedFiles @('docs\sub\intro.md') -Rules $rules
        $result | Should -Be @('documentation')
    }

    It 'supports a rule contributing multiple labels at once' {
        $rules = @(@{ pattern = 'src/api/**'; labels = @('api', 'backend') })
        $result = Get-PrLabels -ChangedFiles @('src/api/User.cs') -Rules $rules
        ($result | Sort-Object) | Should -Be @('api', 'backend')
    }
}

Describe 'Get-PrLabels - priority ordering' {
    It 'orders the output by descending priority' {
        $rules = @(
            @{ pattern = 'docs/**';    labels = @('documentation'); priority = 1  },
            @{ pattern = 'src/api/**'; labels = @('api');           priority = 10 }
        )
        $result = Get-PrLabels -ChangedFiles @('docs/a.md', 'src/api/User.cs') -Rules $rules
        $result | Should -Be @('api', 'documentation')
    }

    It 'falls back to rule declaration order when priorities tie' {
        # Both rules have priority 0 (the default), so the rule listed first wins
        # the tie-break and its label appears first in the output.
        $rules = @(
            @{ pattern = '**/*.md';    labels = @('docs')     },
            @{ pattern = '**/README*'; labels = @('readme')   }
        )
        $result = Get-PrLabels -ChangedFiles @('README.md') -Rules $rules
        $result | Should -Be @('docs', 'readme')
    }

    It 'when the same label is contributed by rules of different priorities, the higher priority wins for ordering' {
        $rules = @(
            @{ pattern = 'docs/**';    labels = @('documentation'); priority = 1  },
            @{ pattern = 'README.md';  labels = @('release-notes'); priority = 100 },
            @{ pattern = 'README.md';  labels = @('documentation'); priority = 50 }
        )
        # 'documentation' is contributed by two rules; it inherits priority 50
        # (the maximum). 'release-notes' is priority 100 and wins.
        $result = Get-PrLabels -ChangedFiles @('docs/a.md', 'README.md') -Rules $rules
        $result | Should -Be @('release-notes', 'documentation')
    }
}

Describe 'Get-PrLabels - configuration loading' {
    It 'loads rules from a JSON config file' {
        $cfg = [ordered]@{
            rules = @(
                @{ pattern = 'docs/**'; labels = @('documentation') },
                @{ pattern = '**/*.cs'; labels = @('csharp') }
            )
        }
        $cfgPath = Join-Path $TestDrive 'labels.json'
        $cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $cfgPath
        $result = Get-PrLabels -ChangedFiles @('docs/intro.md', 'src/Foo.cs') -ConfigPath $cfgPath
        ($result | Sort-Object) | Should -Be @('csharp', 'documentation')
    }

    It 'preserves priority values loaded from JSON' {
        $cfg = [ordered]@{
            rules = @(
                @{ pattern = 'docs/**';    labels = @('documentation'); priority = 1  },
                @{ pattern = 'src/api/**'; labels = @('api');           priority = 10 }
            )
        }
        $cfgPath = Join-Path $TestDrive 'labels-prio.json'
        $cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $cfgPath
        $result = Get-PrLabels -ChangedFiles @('docs/a.md', 'src/api/User.cs') -ConfigPath $cfgPath
        $result | Should -Be @('api', 'documentation')
    }
}

Describe 'Get-PrLabels - error handling' {
    It 'throws a clear error when the config file does not exist' {
        { Get-PrLabels -ChangedFiles @('docs/a.md') -ConfigPath '/no/such/file.json' } |
            Should -Throw '*Config file not found*'
    }

    It 'throws a clear error when the config file is not valid JSON' {
        $cfgPath = Join-Path $TestDrive 'broken.json'
        Set-Content -Path $cfgPath -Value '{ this is not JSON'
        { Get-PrLabels -ChangedFiles @('docs/a.md') -ConfigPath $cfgPath } |
            Should -Throw '*Failed to parse*'
    }

    It 'throws when the config has no rules array' {
        $cfgPath = Join-Path $TestDrive 'norules.json'
        '{}' | Set-Content -Path $cfgPath
        { Get-PrLabels -ChangedFiles @('docs/a.md') -ConfigPath $cfgPath } |
            Should -Throw '*no rules*'
    }

    It 'throws when a rule is missing a pattern' {
        $rules = @(@{ labels = @('documentation') })
        { Get-PrLabels -ChangedFiles @('docs/a.md') -Rules $rules } |
            Should -Throw '*missing*pattern*'
    }

    It 'throws when a rule has no labels' {
        $rules = @(@{ pattern = 'docs/**' })
        { Get-PrLabels -ChangedFiles @('docs/a.md') -Rules $rules } |
            Should -Throw '*no labels*'
    }
}
