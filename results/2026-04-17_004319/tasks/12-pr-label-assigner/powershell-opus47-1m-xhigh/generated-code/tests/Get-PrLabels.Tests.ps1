# Pester tests for Get-PrLabels.ps1
# Approach: TDD - red/green/refactor. Each Describe/It targets a single piece of
# functionality, building from primitive (glob matching) to composed behavior
# (label resolution with priority ordering across many rules and files).

BeforeAll {
    # Resolve script path from the test file's location so tests run from any cwd.
    $script:ScriptPath = Join-Path $PSScriptRoot '..' 'Get-PrLabels.ps1'
    if (-not (Test-Path $script:ScriptPath)) {
        throw "Cannot locate Get-PrLabels.ps1 at $script:ScriptPath"
    }
    # Dot-source so the internal functions become available in this scope.
    . $script:ScriptPath
}

Describe 'Test-GlobMatch (primitive matcher)' {
    Context 'literal segments' {
        It 'matches exact path' {
            Test-GlobMatch -Path 'README.md' -Pattern 'README.md' | Should -BeTrue
        }
        It 'rejects different path' {
            Test-GlobMatch -Path 'CHANGELOG.md' -Pattern 'README.md' | Should -BeFalse
        }
    }

    Context 'single * wildcard' {
        It 'matches within a single path segment' {
            Test-GlobMatch -Path 'foo.test.js' -Pattern '*.test.js' | Should -BeTrue
        }
        It 'does NOT cross directory boundaries when the pattern is anchored with a slash' {
            # Anchored pattern: '/' means literal-from-root, single * stops at /
            Test-GlobMatch -Path 'src/sub/foo.test.js' -Pattern 'src/*.test.js' | Should -BeFalse
        }
    }

    Context 'double ** wildcard' {
        It 'matches arbitrary nested paths via prefix' {
            Test-GlobMatch -Path 'docs/guide/intro.md' -Pattern 'docs/**' | Should -BeTrue
        }
        It 'matches direct children too' {
            Test-GlobMatch -Path 'docs/intro.md' -Pattern 'docs/**' | Should -BeTrue
        }
        It 'does not match files outside the prefix' {
            Test-GlobMatch -Path 'src/intro.md' -Pattern 'docs/**' | Should -BeFalse
        }
        It 'matches with explicit suffix glob' {
            Test-GlobMatch -Path 'docs/sub/page.md' -Pattern 'docs/**/*.md' | Should -BeTrue
        }
        It 'matches direct child with **/*.md' {
            Test-GlobMatch -Path 'docs/page.md' -Pattern 'docs/**/*.md' | Should -BeTrue
        }
    }

    Context 'basename-only patterns (gitignore-style)' {
        It 'matches a basename pattern at any depth when no slash present' {
            # When the pattern has no "/", we treat it as basename (so "*.test.*"
            # finds any .test. file regardless of directory depth).
            Test-GlobMatch -Path 'src/api/users.test.ts' -Pattern '*.test.*' | Should -BeTrue
        }
        It 'matches the file at root level too' {
            Test-GlobMatch -Path 'foo.test.js' -Pattern '*.test.*' | Should -BeTrue
        }
    }

    Context 'regex special characters in pattern are escaped' {
        It 'treats dots as literal characters' {
            Test-GlobMatch -Path 'fooXmd' -Pattern 'foo.md' | Should -BeFalse
        }
    }
}

Describe 'Get-PrLabels (label resolution)' {
    Context 'no rules match' {
        It 'returns an empty list when nothing matches' {
            $rules = @(
                [pscustomobject]@{ pattern = 'docs/**'; labels = @('documentation'); priority = 0 }
            )
            $result = Get-PrLabels -ChangedFiles @('src/main.ps1') -Rules $rules
            # The function returns @() (an empty array). PowerShell collapses this
            # to $null when assigned out of a function call site, so BeNullOrEmpty
            # is the right expectation here.
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'single matching rule' {
        It 'returns the rule label when one file matches' {
            $rules = @(
                [pscustomobject]@{ pattern = 'docs/**'; labels = @('documentation'); priority = 0 }
            )
            $result = Get-PrLabels -ChangedFiles @('docs/intro.md') -Rules $rules
            $result | Should -Be @('documentation')
        }
    }

    Context 'multiple labels per file (multiple rules match same file)' {
        It 'returns the union, deduplicated' {
            $rules = @(
                [pscustomobject]@{ pattern = 'src/**';     labels = @('source');    priority = 0 }
                [pscustomobject]@{ pattern = '**/*.test.*'; labels = @('tests');    priority = 0 }
            )
            $result = Get-PrLabels -ChangedFiles @('src/foo.test.ps1') -Rules $rules
            ($result | Sort-Object) | Should -Be @('source', 'tests')
        }
    }

    Context 'multiple files, multiple rules' {
        It 'aggregates labels from all matched files, deduplicating' {
            $rules = @(
                [pscustomobject]@{ pattern = 'docs/**';     labels = @('documentation'); priority = 0 }
                [pscustomobject]@{ pattern = 'src/api/**';  labels = @('api');           priority = 0 }
                [pscustomobject]@{ pattern = '*.test.*';    labels = @('tests');         priority = 0 }
            )
            $files = @(
                'docs/readme.md',
                'src/api/users.ts',
                'src/api/users.test.ts'
            )
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            ($result | Sort-Object) | Should -Be @('api', 'documentation', 'tests')
        }
    }

    Context 'one rule emits multiple labels' {
        It 'attaches every label from the rule to matched files' {
            $rules = @(
                [pscustomobject]@{ pattern = 'src/api/**'; labels = @('api', 'backend'); priority = 0 }
            )
            $result = Get-PrLabels -ChangedFiles @('src/api/users.ts') -Rules $rules
            ($result | Sort-Object) | Should -Be @('api', 'backend')
        }
    }

    Context 'priority ordering' {
        It 'orders output labels by priority descending then name ascending' {
            $rules = @(
                [pscustomobject]@{ pattern = 'docs/**';      labels = @('documentation'); priority = 1 }
                [pscustomobject]@{ pattern = 'src/api/**';   labels = @('api');           priority = 10 }
                [pscustomobject]@{ pattern = '*.test.*';     labels = @('tests');         priority = 5 }
            )
            $files = @('docs/readme.md', 'src/api/users.ts', 'src/api/users.test.ts')
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            # Highest priority first: api(10), tests(5), documentation(1)
            $result | Should -Be @('api', 'tests', 'documentation')
        }

        It 'when same label is emitted by two rules, the higher priority wins for ordering' {
            $rules = @(
                [pscustomobject]@{ pattern = 'docs/**';      labels = @('shared'); priority = 1 }
                [pscustomobject]@{ pattern = 'src/api/**';   labels = @('shared'); priority = 99 }
                [pscustomobject]@{ pattern = '*.test.*';     labels = @('tests');  priority = 5 }
            )
            $files = @('docs/readme.md', 'src/api/users.ts', 'src/api/users.test.ts')
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            # 'shared' should be ranked at priority 99 (max seen), so first.
            $result | Should -Be @('shared', 'tests')
        }
    }

    Context 'config loading from JSON' {
        It 'loads rules from a JSON config file' {
            $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + '.json')
            try {
                $config = @{
                    rules = @(
                        @{ pattern = 'docs/**'; labels = @('documentation'); priority = 1 }
                        @{ pattern = '*.test.*'; labels = @('tests');         priority = 5 }
                    )
                }
                ($config | ConvertTo-Json -Depth 10) | Set-Content -Path $tmp -Encoding utf8
                $rules = Read-LabelConfig -Path $tmp
                $rules | Should -HaveCount 2
                $rules[0].pattern | Should -Be 'docs/**'
                $rules[1].labels | Should -Contain 'tests'
            } finally {
                Remove-Item -Path $tmp -ErrorAction SilentlyContinue
            }
        }

        It 'throws a clear error if the config file is missing' {
            { Read-LabelConfig -Path '/no/such/file.json' } | Should -Throw "*Config file not found*"
        }

        It 'throws a clear error on malformed JSON' {
            $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + '.json')
            try {
                Set-Content -Path $tmp -Value '{ this is not valid json' -Encoding utf8
                { Read-LabelConfig -Path $tmp } | Should -Throw "*Failed to parse*"
            } finally {
                Remove-Item -Path $tmp -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'changed files loading' {
        It 'reads file paths from a text file (one per line, trims blanks)' {
            $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + '.txt')
            try {
                @('docs/a.md', '', 'src/api/b.ts', '   ', 'src/c.test.ps1') |
                    Set-Content -Path $tmp -Encoding utf8
                $files = Read-ChangedFiles -Path $tmp
                $files | Should -Be @('docs/a.md', 'src/api/b.ts', 'src/c.test.ps1')
            } finally {
                Remove-Item -Path $tmp -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'End-to-end CLI invocation' {
    It 'when run as a script, prints one label per line to stdout' {
        $cfg = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + '.json')
        $files = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + '.txt')
        try {
            @{
                rules = @(
                    @{ pattern = 'docs/**';     labels = @('documentation'); priority = 1 }
                    @{ pattern = 'src/api/**';  labels = @('api');           priority = 10 }
                )
            } | ConvertTo-Json -Depth 10 | Set-Content -Path $cfg -Encoding utf8

            @('docs/readme.md', 'src/api/users.ts') | Set-Content -Path $files -Encoding utf8

            $output = & pwsh -NoProfile -File $script:ScriptPath -ChangedFilesPath $files -ConfigPath $cfg
            # Output is one label per line; sort for deterministic comparison.
            ($output | Where-Object { $_ }) | Should -Be @('api', 'documentation')
        } finally {
            Remove-Item -Path $cfg, $files -ErrorAction SilentlyContinue
        }
    }
}
