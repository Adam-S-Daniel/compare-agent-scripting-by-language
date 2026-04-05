# PrLabelAssigner.Tests.ps1
# TDD tests for PR Label Assigner
# Each Context block represents a TDD round: test written first (RED), then code to pass (GREEN)

BeforeAll {
    # Dot-source the implementation module
    . "$PSScriptRoot/PrLabelAssigner.ps1"
}

# ========================================================================
# TDD Round 1: Glob-to-Regex conversion (the foundation)
# ========================================================================
Describe 'Convert-GlobToRegex' {

    Context 'Basic pattern conversion' {
        # RED: Test that ** glob becomes a regex matching any path depth
        It 'Should convert ** to match any path depth' {
            $regex = Convert-GlobToRegex -GlobPattern 'docs/**'
            # Should match docs/readme.md and docs/sub/deep/file.txt
            'docs/readme.md' | Should -Match $regex
            'docs/sub/deep/file.txt' | Should -Match $regex
        }

        # RED: Test that * matches within a single segment (no slashes)
        It 'Should convert * to match within a single path segment' {
            $regex = Convert-GlobToRegex -GlobPattern '*.md'
            'README.md' | Should -Match $regex
            'docs/README.md' | Should -Not -Match $regex
        }

        # RED: Test that dots are escaped properly
        It 'Should escape dots in patterns' {
            $regex = Convert-GlobToRegex -GlobPattern '*.test.*'
            'app.test.js' | Should -Match $regex
            'apptestjs' | Should -Not -Match $regex
        }

        # RED: Test literal filename matching (no wildcards)
        It 'Should match exact filenames' {
            $regex = Convert-GlobToRegex -GlobPattern 'Dockerfile'
            'Dockerfile' | Should -Match $regex
            'Dockerfile.bak' | Should -Not -Match $regex
            'my/Dockerfile' | Should -Not -Match $regex
        }
    }
}

# ========================================================================
# TDD Round 2: Test-GlobMatch helper
# ========================================================================
Describe 'Test-GlobMatch' {

    Context 'Matching file paths against glob patterns' {
        # RED: ** pattern should match files in nested directories
        It 'Should match files in nested directories with **' {
            Test-GlobMatch -FilePath 'src/api/users.js' -GlobPattern 'src/api/**' | Should -BeTrue
        }

        It 'Should match files in deeply nested directories with **' {
            Test-GlobMatch -FilePath 'src/api/v2/internal/handler.js' -GlobPattern 'src/api/**' | Should -BeTrue
        }

        # RED: Should not match paths that don't start with the prefix
        It 'Should not match unrelated paths' {
            Test-GlobMatch -FilePath 'lib/api/users.js' -GlobPattern 'src/api/**' | Should -BeFalse
        }

        # RED: Wildcard extension matching
        It 'Should match wildcard extensions like *.test.*' {
            Test-GlobMatch -FilePath 'auth.test.js' -GlobPattern '*.test.*' | Should -BeTrue
            Test-GlobMatch -FilePath 'auth.test.ts' -GlobPattern '*.test.*' | Should -BeTrue
        }

        It 'Should not match *.test.* for files without .test. in name' {
            Test-GlobMatch -FilePath 'auth.spec.js' -GlobPattern '*.test.*' | Should -BeFalse
        }

        # RED: Exact filename match
        It 'Should match exact filenames like package.json' {
            Test-GlobMatch -FilePath 'package.json' -GlobPattern 'package.json' | Should -BeTrue
        }

        It 'Should not match similar but different filenames' {
            Test-GlobMatch -FilePath 'package-lock.json' -GlobPattern 'package.json' | Should -BeFalse
        }

        # RED: Pattern with wildcard at start like docker-compose.*
        # Note: * matches any non-slash chars, so docker-compose.override.yml matches too
        It 'Should match patterns with trailing wildcard like docker-compose.*' {
            Test-GlobMatch -FilePath 'docker-compose.yml' -GlobPattern 'docker-compose.*' | Should -BeTrue
            Test-GlobMatch -FilePath 'docker-compose.override.yml' -GlobPattern 'docker-compose.*' | Should -BeTrue
            # But it should not match if nested in a directory
            Test-GlobMatch -FilePath 'config/docker-compose.yml' -GlobPattern 'docker-compose.*' | Should -BeFalse
        }
    }
}

# ========================================================================
# TDD Round 3: Basic Get-PrLabels - single rule matching
# ========================================================================
Describe 'Get-PrLabels' {

    Context 'Basic single rule matching' {
        # RED: A file matching a rule should produce the expected label
        It 'Should apply a label when a file matches a simple glob pattern' {
            $rules = @(
                @{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 1 }
            )
            $files = @('docs/readme.md')

            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain 'documentation'
        }

        # RED: No match should produce empty result
        It 'Should return empty when no files match any rule' {
            $rules = @(
                @{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 1 }
            )
            $files = @('src/main.ps1')

            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -BeNullOrEmpty
        }
    }

    # ========================================================================
    # TDD Round 4: Multiple labels per file and across files
    # ========================================================================
    Context 'Multiple labels from multiple rules' {
        # RED: A file that matches multiple rules should get all labels
        It 'Should assign multiple labels when a file matches multiple rules' {
            $rules = @(
                @{ Pattern = 'src/api/**';    Label = 'api';   Priority = 1 }
                @{ Pattern = '**/*.test.*';   Label = 'tests'; Priority = 1 }
            )
            $files = @('src/api/users.test.js')

            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain 'api'
            $result | Should -Contain 'tests'
            $result.Count | Should -Be 2
        }

        # RED: Different files matching different rules produce union of labels
        It 'Should produce union of labels from all matching files' {
            $rules = @(
                @{ Pattern = 'docs/**';     Label = 'documentation'; Priority = 1 }
                @{ Pattern = 'src/api/**';  Label = 'api';           Priority = 1 }
                @{ Pattern = 'src/ui/**';   Label = 'frontend';      Priority = 1 }
            )
            $files = @('docs/guide.md', 'src/api/endpoint.js', 'src/ui/button.tsx')

            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain 'documentation'
            $result | Should -Contain 'api'
            $result | Should -Contain 'frontend'
            $result.Count | Should -Be 3
        }

        # RED: Duplicate labels from multiple files should be deduplicated
        It 'Should deduplicate labels when multiple files match the same rule' {
            $rules = @(
                @{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 1 }
            )
            $files = @('docs/readme.md', 'docs/setup.md', 'docs/api.md')

            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain 'documentation'
            # Ensure only one instance of the label
            @($result).Count | Should -Be 1
        }
    }

    # ========================================================================
    # TDD Round 5: Priority ordering when rules conflict
    # ========================================================================
    Context 'Priority ordering' {
        # RED: Labels should be ordered by the best (lowest) priority that triggered them
        It 'Should order labels by their best matching rule priority' {
            $rules = @(
                @{ Pattern = 'src/api/**';  Label = 'api';           Priority = 1 }
                @{ Pattern = 'docs/**';     Label = 'documentation'; Priority = 3 }
                @{ Pattern = '*.test.*';    Label = 'tests';         Priority = 2 }
            )
            $files = @('src/api/users.js', 'docs/readme.md', 'app.test.js')

            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            # api (priority 1) should come first, then tests (2), then documentation (3)
            $result[0] | Should -Be 'api'
            $result[1] | Should -Be 'tests'
            $result[2] | Should -Be 'documentation'
        }

        # RED: When two rules produce the same label, the best priority wins
        It 'Should use the best priority when multiple rules produce the same label' {
            $rules = @(
                @{ Pattern = '*.test.*';  Label = 'tests'; Priority = 5 }
                @{ Pattern = 'tests/**';  Label = 'tests'; Priority = 1 }
                @{ Pattern = 'src/**';    Label = 'code';  Priority = 3 }
            )
            $files = @('tests/unit.test.js', 'src/app.js')

            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            # 'tests' should come first (priority 1 from tests/**), then 'code' (priority 3)
            $result[0] | Should -Be 'tests'
            $result[1] | Should -Be 'code'
        }

        # RED: MaxLabels should limit the output to highest-priority labels
        It 'Should respect MaxLabels limit' {
            $rules = @(
                @{ Pattern = 'src/api/**';  Label = 'api';           Priority = 1 }
                @{ Pattern = 'docs/**';     Label = 'documentation'; Priority = 3 }
                @{ Pattern = '*.test.*';    Label = 'tests';         Priority = 2 }
            )
            $files = @('src/api/users.js', 'docs/readme.md', 'app.test.js')

            $result = Get-PrLabels -ChangedFiles $files -Rules $rules -MaxLabels 2
            $result.Count | Should -Be 2
            $result[0] | Should -Be 'api'
            $result[1] | Should -Be 'tests'
        }
    }

    # ========================================================================
    # TDD Round 6: Edge cases and error handling
    # ========================================================================
    Context 'Edge cases' {
        # RED: Files at root level matching root-level patterns
        It 'Should match root-level files with root-level patterns' {
            $rules = @(
                @{ Pattern = 'Dockerfile'; Label = 'infrastructure'; Priority = 1 }
            )
            $files = @('Dockerfile')

            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain 'infrastructure'
        }

        # RED: Hidden files/directories (starting with .)
        It 'Should match hidden directory patterns like .github/**' {
            $rules = @(
                @{ Pattern = '.github/**'; Label = 'ci/cd'; Priority = 1 }
            )
            $files = @('.github/workflows/ci.yml')

            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain 'ci/cd'
        }

        # RED: Pattern with ? wildcard for single character
        It 'Should support ? wildcard for single character' {
            $regex = Convert-GlobToRegex -GlobPattern 'src/?.js'
            'src/a.js' | Should -Match $regex
            'src/ab.js' | Should -Not -Match $regex
        }

        # RED: No matching files should return empty array, not null
        It 'Should return an empty array (not null) when no rules match' {
            $rules = @(
                @{ Pattern = 'nonexistent/**'; Label = 'ghost'; Priority = 1 }
            )
            $files = @('src/real-file.js')

            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -BeNullOrEmpty
        }
    }

    # ========================================================================
    # TDD Round 7: Error handling
    # ========================================================================
    Context 'Error handling' {
        # RED: Rule missing required keys should produce an error
        It 'Should error when a rule is missing required keys' {
            $rules = @(
                @{ Pattern = 'docs/**'; Label = 'documentation' }  # Missing Priority
            )
            $files = @('docs/readme.md')

            $result = Get-PrLabels -ChangedFiles $files -Rules $rules -ErrorAction SilentlyContinue -ErrorVariable err
            $err | Should -Not -BeNullOrEmpty
        }
    }

    # ========================================================================
    # TDD Round 8: Integration test with default rules and mock PR data
    # ========================================================================
    Context 'Integration with default rules and mock PRs' {
        BeforeAll {
            $defaultRules = Get-DefaultRules
        }

        # RED: Documentation-only PR should get 'documentation' label
        It 'Should label a docs-only PR as documentation' {
            $files = @('docs/api-guide.md', 'docs/setup.md')
            $result = Get-PrLabels -ChangedFiles $files -Rules $defaultRules
            $result | Should -Contain 'documentation'
        }

        # RED: API PR with tests should get both 'api' and 'tests' labels
        It 'Should label an API + tests PR correctly' {
            $files = @('src/api/users.js', 'src/api/auth.js', 'tests/api.test.js')
            $result = Get-PrLabels -ChangedFiles $files -Rules $defaultRules
            $result | Should -Contain 'api'
            $result | Should -Contain 'tests'
        }

        # RED: Full-stack PR should get multiple labels
        It 'Should label a full-stack PR with multiple labels' {
            $files = @('src/api/endpoint.js', 'src/ui/dashboard.tsx', 'Dockerfile', '.github/workflows/ci.yml')
            $result = Get-PrLabels -ChangedFiles $files -Rules $defaultRules
            $result | Should -Contain 'api'
            $result | Should -Contain 'frontend'
            $result | Should -Contain 'infrastructure'
            $result | Should -Contain 'ci/cd'
        }

        # RED: Config/dependency PR
        It 'Should label a config and dependency update PR' {
            $files = @('package.json', 'webpack.config.js')
            $result = Get-PrLabels -ChangedFiles $files -Rules $defaultRules
            $result | Should -Contain 'dependencies'
            $result | Should -Contain 'configuration'
        }

        # RED: README at root should get documentation label (matches *.md)
        It 'Should label a root-level .md file as documentation' {
            $files = @('README.md')
            $result = Get-PrLabels -ChangedFiles $files -Rules $defaultRules
            $result | Should -Contain 'documentation'
        }

        # RED: Test-only PR using .spec. pattern
        It 'Should label .spec. files as tests' {
            $files = @('auth.spec.ts')
            $result = Get-PrLabels -ChangedFiles $files -Rules $defaultRules
            $result | Should -Contain 'tests'
        }
    }
}
