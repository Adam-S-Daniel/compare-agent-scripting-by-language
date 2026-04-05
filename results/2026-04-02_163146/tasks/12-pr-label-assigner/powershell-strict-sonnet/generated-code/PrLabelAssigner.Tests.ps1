#Requires -Version 7.0
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Import the module under test
$ModulePath = Join-Path $PSScriptRoot 'PrLabelAssigner.psm1'
Import-Module $ModulePath -Force

Describe 'Convert-GlobToWildcard' {
    # Tests for internal glob-to-wildcard conversion
    Context 'Pattern conversion' {
        It 'leaves simple wildcard patterns unchanged' {
            Convert-GlobToWildcard -GlobPattern '*.test.*' | Should -Be '*.test.*'
        }

        It 'converts ** to * for recursive matching' {
            Convert-GlobToWildcard -GlobPattern 'docs/**' | Should -Be 'docs/*'
        }

        It 'converts multiple ** segments' {
            Convert-GlobToWildcard -GlobPattern 'src/**/test/**' | Should -Be 'src/*/test/*'
        }

        It 'leaves patterns without ** unchanged' {
            Convert-GlobToWildcard -GlobPattern 'src/api/*' | Should -Be 'src/api/*'
        }
    }
}

Describe 'Test-FileMatchesPattern' {
    # Tests for per-file glob pattern matching
    Context 'Exact and wildcard matching' {
        It 'matches a file with a simple wildcard' {
            Test-FileMatchesPattern -FilePath 'README.md' -GlobPattern '*.md' | Should -BeTrue
        }

        It 'does not match a file that differs from pattern' {
            Test-FileMatchesPattern -FilePath 'src/main.go' -GlobPattern '*.md' | Should -BeFalse
        }

        It 'matches a nested path with ** glob (docs/**)' {
            Test-FileMatchesPattern -FilePath 'docs/api/reference.md' -GlobPattern 'docs/**' | Should -BeTrue
        }

        It 'matches a top-level file with docs/** glob' {
            Test-FileMatchesPattern -FilePath 'docs/README.md' -GlobPattern 'docs/**' | Should -BeTrue
        }

        It 'matches *.test.* pattern for test files' {
            Test-FileMatchesPattern -FilePath 'src/utils.test.ts' -GlobPattern '*.test.*' | Should -BeTrue
        }

        It 'does not match *.test.* for non-test files' {
            Test-FileMatchesPattern -FilePath 'src/utils.ts' -GlobPattern '*.test.*' | Should -BeFalse
        }

        It 'matches src/api/** for API files' {
            Test-FileMatchesPattern -FilePath 'src/api/routes/users.ts' -GlobPattern 'src/api/**' | Should -BeTrue
        }

        It 'does not match src/api/** for non-API files' {
            Test-FileMatchesPattern -FilePath 'src/utils/helpers.ts' -GlobPattern 'src/api/**' | Should -BeFalse
        }
    }
}

Describe 'Get-PRLabels' {
    # Test fixtures: mock file lists and label rules
    BeforeAll {
        # Standard rule set used across multiple tests (priority descending = higher value = higher priority)
        [hashtable[]]$script:StandardRules = @(
            @{ Pattern = 'docs/**';    Label = 'documentation'; Priority = 10 }
            @{ Pattern = 'src/api/**'; Label = 'api';           Priority = 9  }
            @{ Pattern = '*.test.*';   Label = 'tests';         Priority = 8  }
            @{ Pattern = 'src/**';     Label = 'source';        Priority = 5  }
            @{ Pattern = '*.md';       Label = 'documentation'; Priority = 3  }
        )
    }

    Context 'Empty and edge cases' {
        It 'returns empty array when no files are provided' {
            [string[]]$result = Get-PRLabels -FilePaths @() -Rules $script:StandardRules
            $result | Should -HaveCount 0
        }

        It 'returns empty array when no rules are provided' {
            [string[]]$result = Get-PRLabels -FilePaths @('src/main.ts') -Rules @()
            $result | Should -HaveCount 0
        }

        It 'returns empty array when no files match any rule' {
            [string[]]$result = Get-PRLabels -FilePaths @('build/output.bin') -Rules $script:StandardRules
            $result | Should -HaveCount 0
        }
    }

    Context 'Single rule matching' {
        It 'returns single label when one file matches one rule' {
            [string[]]$result = Get-PRLabels -FilePaths @('docs/README.md') -Rules $script:StandardRules
            $result | Should -Contain 'documentation'
        }

        It 'returns api label for API source files' {
            [string[]]$result = Get-PRLabels -FilePaths @('src/api/routes.ts') -Rules $script:StandardRules
            $result | Should -Contain 'api'
        }

        It 'returns tests label for test files' {
            [string[]]$result = Get-PRLabels -FilePaths @('src/utils.test.ts') -Rules $script:StandardRules
            $result | Should -Contain 'tests'
        }
    }

    Context 'Multiple labels per file' {
        It 'assigns multiple labels when file matches multiple rules' {
            # src/api/routes.test.ts matches src/api/** (api), *.test.* (tests), and src/** (source)
            [string[]]$result = Get-PRLabels -FilePaths @('src/api/routes.test.ts') -Rules $script:StandardRules
            $result | Should -Contain 'api'
            $result | Should -Contain 'tests'
            $result | Should -Contain 'source'
        }
    }

    Context 'Multiple files contributing different labels' {
        It 'collects labels from all changed files' {
            [string[]]$files = @(
                'docs/api-guide.md'
                'src/api/handlers.ts'
                'src/utils.test.ts'
            )
            [string[]]$result = Get-PRLabels -FilePaths $files -Rules $script:StandardRules
            $result | Should -Contain 'documentation'
            $result | Should -Contain 'api'
            $result | Should -Contain 'tests'
        }
    }

    Context 'Label deduplication' {
        It 'returns each label only once even when matched by multiple rules or files' {
            # docs/guide.md matches docs/** (documentation, priority 10) and *.md (documentation, priority 3)
            # Both assign 'documentation' — should appear only once
            [string[]]$files = @('docs/guide.md', 'docs/setup.md')
            [string[]]$result = Get-PRLabels -FilePaths $files -Rules $script:StandardRules
            ($result | Where-Object { $_ -eq 'documentation' }).Count | Should -Be 1
        }
    }

    Context 'Priority ordering' {
        It 'returns labels ordered by rule priority (highest first)' {
            # Files that match rules at different priorities
            [string[]]$files = @(
                'docs/guide.md'      # documentation (priority 10)
                'src/api/routes.ts'  # api (priority 9)
                'src/helpers.ts'     # source (priority 5)
            )
            [string[]]$result = Get-PRLabels -FilePaths $files -Rules $script:StandardRules
            # documentation should come before api, api before source
            $docIndex    = [array]::IndexOf($result, 'documentation')
            $apiIndex    = [array]::IndexOf($result, 'api')
            $sourceIndex = [array]::IndexOf($result, 'source')
            $docIndex    | Should -BeLessThan $apiIndex
            $apiIndex    | Should -BeLessThan $sourceIndex
        }
    }

    Context 'Custom rule configurations' {
        It 'supports custom single-rule configurations' {
            [hashtable[]]$rules = @(
                @{ Pattern = '*.yml'; Label = 'ci-config'; Priority = 1 }
            )
            [string[]]$result = Get-PRLabels -FilePaths @('.github/workflows/ci.yml') -Rules $rules
            $result | Should -Contain 'ci-config'
        }

        It 'handles rules with the same priority gracefully' {
            [hashtable[]]$rules = @(
                @{ Pattern = 'src/**'; Label = 'backend'; Priority = 5 }
                @{ Pattern = 'ui/**';  Label = 'frontend'; Priority = 5 }
            )
            [string[]]$files = @('src/server.ts', 'ui/app.tsx')
            [string[]]$result = Get-PRLabels -FilePaths $files -Rules $rules
            $result | Should -Contain 'backend'
            $result | Should -Contain 'frontend'
        }
    }

    Context 'Mock PR scenarios' {
        It 'labels a documentation-only PR correctly' {
            # Mock: only docs files changed
            [string[]]$prFiles = @(
                'docs/getting-started.md'
                'docs/api/endpoints.md'
                'docs/contributing.md'
            )
            [string[]]$result = Get-PRLabels -FilePaths $prFiles -Rules $script:StandardRules
            $result | Should -Contain 'documentation'
            $result | Should -Not -Contain 'api'
            $result | Should -Not -Contain 'tests'
        }

        It 'labels a full-stack feature PR with multiple labels' {
            # Mock: API changes, tests, and docs
            [string[]]$prFiles = @(
                'src/api/users.ts'
                'src/api/users.test.ts'
                'src/models/user.ts'
                'docs/api/users.md'
            )
            [string[]]$result = Get-PRLabels -FilePaths $prFiles -Rules $script:StandardRules
            $result | Should -Contain 'api'
            $result | Should -Contain 'tests'
            $result | Should -Contain 'documentation'
            $result | Should -Contain 'source'
        }

        It 'labels a refactor PR that only touches source files' {
            [string[]]$prFiles = @(
                'src/utils/formatters.ts'
                'src/utils/validators.ts'
                'src/services/auth.ts'
            )
            [string[]]$result = Get-PRLabels -FilePaths $prFiles -Rules $script:StandardRules
            $result | Should -Contain 'source'
            $result | Should -Not -Contain 'api'
            $result | Should -Not -Contain 'tests'
            $result | Should -Not -Contain 'documentation'
        }
    }

    Context 'Error handling' {
        It 'throws a meaningful error when Rules parameter contains invalid entries' {
            # A rule missing the required Pattern key should cause an error
            [hashtable[]]$badRules = @(
                @{ Label = 'orphan'; Priority = 1 }  # Missing Pattern
            )
            { Get-PRLabels -FilePaths @('src/main.ts') -Rules $badRules } | Should -Throw
        }
    }
}
