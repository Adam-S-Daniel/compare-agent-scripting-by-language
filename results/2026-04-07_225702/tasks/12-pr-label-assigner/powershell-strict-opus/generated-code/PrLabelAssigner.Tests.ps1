Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    . "$PSScriptRoot/PrLabelAssigner.ps1"
}

Describe 'Get-PrLabels' {
    Context 'Basic single-rule matching' {
        It 'assigns a label when a file matches a glob pattern' {
            [hashtable[]]$rules = @(
                @{ Pattern = 'docs/**'; Label = 'documentation' }
            )
            [string[]]$files = @('docs/readme.md')

            [string[]]$result = Get-PrLabels -ChangedFiles $files -Rules $rules

            $result | Should -Contain 'documentation'
            $result.Count | Should -Be 1
        }
    }

    Context 'Multiple rules and files' {
        It 'assigns multiple labels when a file matches multiple rules' {
            [hashtable[]]$rules = @(
                @{ Pattern = 'src/api/**'; Label = 'api' }
                @{ Pattern = 'src/**'; Label = 'source' }
            )
            [string[]]$files = @('src/api/controller.js')

            [string[]]$result = Get-PrLabels -ChangedFiles $files -Rules $rules

            $result | Should -Contain 'api'
            $result | Should -Contain 'source'
            $result.Count | Should -Be 2
        }

        It 'returns no labels when no files match any rule' {
            [hashtable[]]$rules = @(
                @{ Pattern = 'docs/**'; Label = 'documentation' }
            )
            [string[]]$files = @('src/main.py')

            [string[]]$result = Get-PrLabels -ChangedFiles $files -Rules $rules

            $result.Count | Should -Be 0
        }

        It 'deduplicates labels when multiple files match the same rule' {
            [hashtable[]]$rules = @(
                @{ Pattern = 'docs/**'; Label = 'documentation' }
            )
            [string[]]$files = @('docs/readme.md', 'docs/guide.md')

            [string[]]$result = Get-PrLabels -ChangedFiles $files -Rules $rules

            $result | Should -Contain 'documentation'
            $result.Count | Should -Be 1
        }
    }

    Context 'Glob pattern variants' {
        It 'matches *.test.* pattern for test files' {
            [hashtable[]]$rules = @(
                @{ Pattern = '*.test.*'; Label = 'tests' }
            )
            [string[]]$files = @('utils.test.js')

            [string[]]$result = Get-PrLabels -ChangedFiles $files -Rules $rules

            $result | Should -Contain 'tests'
        }

        It 'matches *.test.* in nested paths with ** prefix' {
            [hashtable[]]$rules = @(
                @{ Pattern = '**/*.test.*'; Label = 'tests' }
            )
            [string[]]$files = @('src/components/button.test.tsx')

            [string[]]$result = Get-PrLabels -ChangedFiles $files -Rules $rules

            $result | Should -Contain 'tests'
        }

        It 'matches deeply nested files with **' {
            [hashtable[]]$rules = @(
                @{ Pattern = 'docs/**'; Label = 'documentation' }
            )
            [string[]]$files = @('docs/api/v2/endpoints.md')

            [string[]]$result = Get-PrLabels -ChangedFiles $files -Rules $rules

            $result | Should -Contain 'documentation'
        }

        It 'matches ? wildcard for single character' {
            [hashtable[]]$rules = @(
                @{ Pattern = 'src/v?/**'; Label = 'versioned' }
            )
            [string[]]$files = @('src/v2/main.js')

            [string[]]$result = Get-PrLabels -ChangedFiles $files -Rules $rules

            $result | Should -Contain 'versioned'
        }

        It 'does not match * across path separators' {
            [hashtable[]]$rules = @(
                @{ Pattern = 'src/*.js'; Label = 'root-js' }
            )
            [string[]]$files = @('src/sub/deep.js')

            [string[]]$result = Get-PrLabels -ChangedFiles $files -Rules $rules

            $result.Count | Should -Be 0
        }
    }

    Context 'Priority ordering' {
        It 'keeps only the highest-priority label when rules conflict on the same file' {
            # When two rules match the same file, the higher priority rule wins
            # and the lower priority rule's label is excluded for that file.
            [hashtable[]]$rules = @(
                @{ Pattern = 'src/**'; Label = 'general'; Priority = 1 }
                @{ Pattern = 'src/api/**'; Label = 'api'; Priority = 10 }
            )
            [string[]]$files = @('src/api/handler.ts')

            [string[]]$result = Get-PrLabels -ChangedFiles $files -Rules $rules

            # Higher priority 'api' should win; 'general' should be excluded
            $result | Should -Contain 'api'
            $result | Should -Not -Contain 'general'
        }

        It 'applies all labels when rules do not conflict (different files)' {
            [hashtable[]]$rules = @(
                @{ Pattern = 'src/**'; Label = 'general'; Priority = 1 }
                @{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 5 }
            )
            [string[]]$files = @('src/main.ts', 'docs/readme.md')

            [string[]]$result = Get-PrLabels -ChangedFiles $files -Rules $rules

            $result | Should -Contain 'general'
            $result | Should -Contain 'documentation'
            $result.Count | Should -Be 2
        }

        It 'uses priority 0 as default when Priority is not specified' {
            [hashtable[]]$rules = @(
                @{ Pattern = 'src/**'; Label = 'source' }
                @{ Pattern = 'src/**'; Label = 'override'; Priority = 1 }
            )
            [string[]]$files = @('src/index.ts')

            [string[]]$result = Get-PrLabels -ChangedFiles $files -Rules $rules

            $result | Should -Contain 'override'
            $result | Should -Not -Contain 'source'
        }

        It 'keeps all labels at the same priority level' {
            [hashtable[]]$rules = @(
                @{ Pattern = 'src/**'; Label = 'code'; Priority = 5 }
                @{ Pattern = 'src/api/**'; Label = 'api'; Priority = 5 }
            )
            [string[]]$files = @('src/api/route.ts')

            [string[]]$result = Get-PrLabels -ChangedFiles $files -Rules $rules

            $result | Should -Contain 'code'
            $result | Should -Contain 'api'
            $result.Count | Should -Be 2
        }
    }

    Context 'Error handling' {
        It 'throws when a rule is missing the Pattern key' {
            [hashtable[]]$rules = @(
                @{ Label = 'oops' }
            )
            [string[]]$files = @('anything.txt')

            { Get-PrLabels -ChangedFiles $files -Rules $rules } | Should -Throw '*Pattern*'
        }

        It 'throws when a rule is missing the Label key' {
            [hashtable[]]$rules = @(
                @{ Pattern = 'src/**' }
            )
            [string[]]$files = @('src/file.ts')

            { Get-PrLabels -ChangedFiles $files -Rules $rules } | Should -Throw '*Label*'
        }
    }
}

Describe 'ConvertTo-GlobRegex' {
    It 'converts a simple pattern' {
        [string]$regex = ConvertTo-GlobRegex -Pattern '*.js'
        $regex | Should -Be '^[^/]*\.js$'
    }

    It 'converts ** to match any depth' {
        [string]$regex = ConvertTo-GlobRegex -Pattern 'docs/**'
        $regex | Should -Be '^docs/.*$'
    }
}

Describe 'Realistic PR scenario' {
    It 'labels a mixed PR with documentation, API, and test changes' {
        # Simulating a real PR with multiple file types
        [hashtable[]]$rules = @(
            @{ Pattern = 'docs/**';       Label = 'documentation'; Priority = 1 }
            @{ Pattern = 'src/api/**';    Label = 'api';           Priority = 5 }
            @{ Pattern = '**/*.test.*';   Label = 'tests';         Priority = 2 }
            @{ Pattern = 'src/**';        Label = 'source';        Priority = 1 }
            @{ Pattern = '*.md';          Label = 'documentation'; Priority = 1 }
            @{ Pattern = '.github/**';    Label = 'ci';            Priority = 3 }
        )

        # Mock changed file list from a PR
        [string[]]$changedFiles = @(
            'docs/api-guide.md'
            'src/api/users.ts'
            'src/api/users.test.ts'
            'src/utils/helpers.ts'
            'README.md'
            '.github/workflows/ci.yml'
        )

        [string[]]$result = Get-PrLabels -ChangedFiles $changedFiles -Rules $rules

        # docs/api-guide.md -> documentation (pri 1)
        # src/api/users.ts -> api (pri 5) wins over source (pri 1)
        # src/api/users.test.ts -> api (pri 5) wins over tests (pri 2) and source (pri 1)
        # src/utils/helpers.ts -> source (pri 1)
        # README.md -> documentation (pri 1)
        # .github/workflows/ci.yml -> ci (pri 3)
        $result | Should -Contain 'documentation'
        $result | Should -Contain 'api'
        $result | Should -Contain 'source'
        $result | Should -Contain 'ci'
        # 'tests' label should NOT appear since api (pri 5) > tests (pri 2)
        $result | Should -Not -Contain 'tests'
    }
}
