# TDD Tests for PR Label Assigner
# Uses Pester testing framework with strict mode enforcement
# Each Describe block covers a specific piece of functionality,
# written as a failing test first, then made to pass.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    # Import the module under test
    . "$PSScriptRoot/PrLabelAssigner.ps1"
}

# ============================================================
# RED/GREEN cycle 1: Basic glob pattern matching
# A single rule like "docs/**" -> "documentation" should label
# any file under the docs/ directory.
# ============================================================
Describe 'Test-GlobMatch' {
    It 'matches a simple directory wildcard pattern docs/**' {
        [bool]$result = Test-GlobMatch -Path 'docs/readme.md' -Pattern 'docs/**'
        $result | Should -BeTrue
    }

    It 'does not match a path outside the pattern' {
        [bool]$result = Test-GlobMatch -Path 'src/main.ps1' -Pattern 'docs/**'
        $result | Should -BeFalse
    }

    It 'matches a file extension wildcard pattern *.test.*' {
        [bool]$result = Test-GlobMatch -Path 'src/app.test.js' -Pattern '*.test.*'
        $result | Should -BeTrue
    }

    It 'matches nested paths with ** glob' {
        [bool]$result = Test-GlobMatch -Path 'src/api/v2/handler.go' -Pattern 'src/api/**'
        $result | Should -BeTrue
    }

    It 'matches a single-level wildcard *' {
        [bool]$result = Test-GlobMatch -Path 'src/main.ps1' -Pattern 'src/*'
        $result | Should -BeTrue
    }

    It 'does not match deeper paths with single-level wildcard' {
        [bool]$result = Test-GlobMatch -Path 'src/api/main.ps1' -Pattern 'src/*'
        $result | Should -BeFalse
    }

    It 'matches exact filename pattern' {
        [bool]$result = Test-GlobMatch -Path 'Dockerfile' -Pattern 'Dockerfile'
        $result | Should -BeTrue
    }

    It 'matches pattern with ? single-character wildcard' {
        [bool]$result = Test-GlobMatch -Path 'src/v2/handler.go' -Pattern 'src/v?/handler.go'
        $result | Should -BeTrue
    }
}

# ============================================================
# RED/GREEN cycle 2: Creating label rules with priority
# Rules have a pattern, label, and priority. Higher priority
# rules take precedence when conflicts arise.
# ============================================================
Describe 'New-LabelRule' {
    It 'creates a rule with pattern, label, and default priority' {
        [hashtable]$rule = New-LabelRule -Pattern 'docs/**' -Label 'documentation'
        $rule.Pattern | Should -Be 'docs/**'
        $rule.Label | Should -Be 'documentation'
        $rule.Priority | Should -Be 0
    }

    It 'creates a rule with explicit priority' {
        [hashtable]$rule = New-LabelRule -Pattern 'src/**' -Label 'source' -Priority 10
        $rule.Priority | Should -Be 10
    }

    It 'throws on empty pattern' {
        { New-LabelRule -Pattern '' -Label 'test' } | Should -Throw '*Pattern cannot be empty*'
    }

    It 'throws on empty label' {
        { New-LabelRule -Pattern 'docs/**' -Label '' } | Should -Throw '*Label cannot be empty*'
    }
}

# ============================================================
# RED/GREEN cycle 3: Applying a single rule to a file list
# Given a set of changed files and a single rule, return the
# label if any file matches.
# ============================================================
Describe 'Get-MatchingLabels' {
    It 'returns a label when a file matches a rule' {
        [hashtable]$rule = New-LabelRule -Pattern 'docs/**' -Label 'documentation'
        [string[]]$files = @('docs/readme.md', 'src/main.ps1')
        [string[]]$labels = Get-MatchingLabels -ChangedFiles $files -Rules @($rule)
        $labels | Should -Contain 'documentation'
    }

    It 'returns no labels when no files match' {
        [hashtable]$rule = New-LabelRule -Pattern 'docs/**' -Label 'documentation'
        [string[]]$files = @('src/main.ps1', 'lib/utils.ps1')
        [string[]]$labels = Get-MatchingLabels -ChangedFiles $files -Rules @($rule)
        $labels | Should -BeNullOrEmpty
    }

    It 'returns multiple labels from multiple matching rules' {
        [hashtable]$rule1 = New-LabelRule -Pattern 'docs/**' -Label 'documentation'
        [hashtable]$rule2 = New-LabelRule -Pattern '*.md' -Label 'markdown'
        [string[]]$files = @('docs/readme.md')
        [string[]]$labels = Get-MatchingLabels -ChangedFiles $files -Rules @($rule1, $rule2)
        $labels | Should -Contain 'documentation'
        $labels | Should -Contain 'markdown'
    }

    It 'returns unique labels even when multiple files match the same rule' {
        [hashtable]$rule = New-LabelRule -Pattern 'docs/**' -Label 'documentation'
        [string[]]$files = @('docs/readme.md', 'docs/guide.md', 'docs/api.md')
        [string[]]$labels = Get-MatchingLabels -ChangedFiles $files -Rules @($rule)
        $labels.Count | Should -Be 1
        $labels | Should -Contain 'documentation'
    }
}

# ============================================================
# RED/GREEN cycle 4: Multiple labels per file
# A single file can trigger multiple labels if it matches
# multiple rules.
# ============================================================
Describe 'Multiple labels per file' {
    It 'applies multiple labels to a single file matching multiple rules' {
        [hashtable]$rule1 = New-LabelRule -Pattern 'src/api/**' -Label 'api'
        [hashtable]$rule2 = New-LabelRule -Pattern '*.test.*' -Label 'tests'
        [string[]]$files = @('src/api/handler.test.js')
        [string[]]$labels = Get-MatchingLabels -ChangedFiles $files -Rules @($rule1, $rule2)
        $labels | Should -Contain 'api'
        $labels | Should -Contain 'tests'
    }

    It 'applies labels from different files matching different rules' {
        [hashtable]$rule1 = New-LabelRule -Pattern 'docs/**' -Label 'documentation'
        [hashtable]$rule2 = New-LabelRule -Pattern 'src/**' -Label 'source'
        [hashtable]$rule3 = New-LabelRule -Pattern '*.test.*' -Label 'tests'
        [string[]]$files = @('docs/readme.md', 'src/app.test.js', 'src/main.ps1')
        [string[]]$labels = Get-MatchingLabels -ChangedFiles $files -Rules @($rule1, $rule2, $rule3)
        $labels | Should -Contain 'documentation'
        $labels | Should -Contain 'source'
        $labels | Should -Contain 'tests'
    }
}

# ============================================================
# RED/GREEN cycle 5: Priority ordering when rules conflict
# When two rules would assign different labels and a conflict
# resolver is used, the higher-priority rule wins.
# ============================================================
Describe 'Priority-based conflict resolution' {
    It 'resolves conflicts by keeping only the highest-priority label in a conflict group' {
        # Both rules match the same file; they are in the same conflict group "size"
        [hashtable]$rule1 = New-LabelRule -Pattern 'src/**' -Label 'size:large' -Priority 1
        [hashtable]$rule2 = New-LabelRule -Pattern 'src/*.ps1' -Label 'size:small' -Priority 10
        [hashtable[]]$conflictGroups = @(
            @{ Prefix = 'size:'; Labels = @('size:large', 'size:small') }
        )
        [string[]]$files = @('src/main.ps1')
        [string[]]$labels = Get-MatchingLabels -ChangedFiles $files -Rules @($rule1, $rule2) -ConflictGroups $conflictGroups
        $labels | Should -Contain 'size:small'
        $labels | Should -Not -Contain 'size:large'
    }

    It 'keeps non-conflicting labels untouched even when resolving conflicts' {
        [hashtable]$rule1 = New-LabelRule -Pattern 'src/**' -Label 'size:large' -Priority 1
        [hashtable]$rule2 = New-LabelRule -Pattern 'src/*.ps1' -Label 'size:small' -Priority 10
        [hashtable]$rule3 = New-LabelRule -Pattern '*.ps1' -Label 'powershell'
        [hashtable[]]$conflictGroups = @(
            @{ Prefix = 'size:'; Labels = @('size:large', 'size:small') }
        )
        [string[]]$files = @('src/main.ps1')
        [string[]]$labels = Get-MatchingLabels -ChangedFiles $files -Rules @($rule1, $rule2, $rule3) -ConflictGroups $conflictGroups
        $labels | Should -Contain 'size:small'
        $labels | Should -Contain 'powershell'
        $labels | Should -Not -Contain 'size:large'
    }

    It 'when priorities are equal, keeps all conflicting labels' {
        [hashtable]$rule1 = New-LabelRule -Pattern 'src/**' -Label 'size:large' -Priority 5
        [hashtable]$rule2 = New-LabelRule -Pattern 'src/*.ps1' -Label 'size:small' -Priority 5
        [hashtable[]]$conflictGroups = @(
            @{ Prefix = 'size:'; Labels = @('size:large', 'size:small') }
        )
        [string[]]$files = @('src/main.ps1')
        [string[]]$labels = Get-MatchingLabels -ChangedFiles $files -Rules @($rule1, $rule2) -ConflictGroups $conflictGroups
        $labels | Should -Contain 'size:large'
        $labels | Should -Contain 'size:small'
    }
}

# ============================================================
# RED/GREEN cycle 6: Loading rules from configuration
# Rules can be loaded from a hashtable config (simulating
# reading from a JSON/YAML config file).
# ============================================================
Describe 'Import-LabelConfig' {
    It 'creates rules from a configuration hashtable' {
        [hashtable]$config = @{
            Rules = @(
                @{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 0 }
                @{ Pattern = 'src/api/**'; Label = 'api'; Priority = 5 }
                @{ Pattern = '*.test.*'; Label = 'tests'; Priority = 0 }
            )
        }
        [hashtable[]]$rules = Import-LabelConfig -Config $config
        $rules.Count | Should -Be 3
        $rules[0].Pattern | Should -Be 'docs/**'
        $rules[1].Label | Should -Be 'api'
        $rules[2].Priority | Should -Be 0
    }

    It 'throws on missing Rules key' {
        [hashtable]$config = @{ NotRules = @() }
        { Import-LabelConfig -Config $config } | Should -Throw '*must contain a Rules key*'
    }

    It 'throws on invalid rule entry missing Pattern' {
        [hashtable]$config = @{
            Rules = @(
                @{ Label = 'documentation'; Priority = 0 }
            )
        }
        { Import-LabelConfig -Config $config } | Should -Throw '*Pattern*'
    }
}

# ============================================================
# RED/GREEN cycle 7: End-to-end integration test
# Simulate a full PR label assignment workflow with mock data.
# ============================================================
Describe 'End-to-end PR label assignment' {
    It 'assigns correct labels to a realistic set of changed files' {
        # Configure rules as a project would
        [hashtable]$config = @{
            Rules = @(
                @{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 0 }
                @{ Pattern = 'src/api/**'; Label = 'api'; Priority = 5 }
                @{ Pattern = '*.test.*'; Label = 'tests'; Priority = 0 }
                @{ Pattern = 'src/**'; Label = 'source'; Priority = 0 }
                @{ Pattern = '*.md'; Label = 'markdown'; Priority = 0 }
                @{ Pattern = 'Dockerfile'; Label = 'docker'; Priority = 0 }
                @{ Pattern = '.github/**'; Label = 'ci'; Priority = 0 }
            )
        }

        # Mock PR changed files
        [string[]]$changedFiles = @(
            'docs/getting-started.md'
            'src/api/users.go'
            'src/api/users.test.go'
            'src/models/user.go'
            'Dockerfile'
            '.github/workflows/ci.yml'
            'README.md'
        )

        [hashtable[]]$rules = Import-LabelConfig -Config $config
        [string[]]$labels = Get-MatchingLabels -ChangedFiles $changedFiles -Rules $rules

        $labels | Should -Contain 'documentation'
        $labels | Should -Contain 'api'
        $labels | Should -Contain 'tests'
        $labels | Should -Contain 'source'
        $labels | Should -Contain 'markdown'
        $labels | Should -Contain 'docker'
        $labels | Should -Contain 'ci'
    }

    It 'assigns correct labels with conflict resolution' {
        [hashtable]$config = @{
            Rules = @(
                @{ Pattern = 'src/**'; Label = 'scope:backend'; Priority = 1 }
                @{ Pattern = 'src/api/**'; Label = 'scope:api'; Priority = 10 }
                @{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 0 }
            )
        }
        [hashtable[]]$conflictGroups = @(
            @{ Prefix = 'scope:'; Labels = @('scope:backend', 'scope:api') }
        )

        [string[]]$changedFiles = @(
            'src/api/handler.go'
            'docs/readme.md'
        )

        [hashtable[]]$rules = Import-LabelConfig -Config $config
        [string[]]$labels = Get-MatchingLabels -ChangedFiles $changedFiles -Rules $rules -ConflictGroups $conflictGroups

        $labels | Should -Contain 'scope:api'
        $labels | Should -Contain 'documentation'
        $labels | Should -Not -Contain 'scope:backend'
    }
}

# ============================================================
# RED/GREEN cycle 8: Edge cases and error handling
# ============================================================
Describe 'Edge cases' {
    It 'handles empty file list gracefully' {
        [hashtable]$rule = New-LabelRule -Pattern 'docs/**' -Label 'documentation'
        [string[]]$files = @()
        [string[]]$labels = Get-MatchingLabels -ChangedFiles $files -Rules @($rule)
        $labels | Should -BeNullOrEmpty
    }

    It 'handles empty rules list gracefully' {
        [string[]]$files = @('docs/readme.md')
        [hashtable[]]$emptyRules = @()
        [string[]]$labels = Get-MatchingLabels -ChangedFiles $files -Rules $emptyRules
        $labels | Should -BeNullOrEmpty
    }

    It 'normalizes forward slashes in paths' {
        [bool]$result = Test-GlobMatch -Path 'docs\readme.md' -Pattern 'docs/**'
        $result | Should -BeTrue
    }

    It 'handles deeply nested paths' {
        [bool]$result = Test-GlobMatch -Path 'src/api/v2/internal/handler.go' -Pattern 'src/**'
        $result | Should -BeTrue
    }

    It 'matches root-level files with extension pattern' {
        [bool]$result = Test-GlobMatch -Path 'README.md' -Pattern '*.md'
        $result | Should -BeTrue
    }

    It 'matches test file pattern in nested path' {
        [bool]$result = Test-GlobMatch -Path 'src/deep/nested/thing.test.ts' -Pattern '*.test.*'
        $result | Should -BeTrue
    }
}

# ============================================================
# RED/GREEN cycle 9: Invoke-PrLabelAssigner (main entry point)
# High-level function that ties everything together.
# ============================================================
Describe 'Invoke-PrLabelAssigner' {
    It 'returns labels for a given config and file list' {
        [hashtable]$config = @{
            Rules = @(
                @{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 0 }
                @{ Pattern = '*.test.*'; Label = 'tests'; Priority = 0 }
            )
        }
        [string[]]$changedFiles = @('docs/guide.md', 'src/app.test.js')

        [string[]]$labels = Invoke-PrLabelAssigner -Config $config -ChangedFiles $changedFiles
        $labels | Should -Contain 'documentation'
        $labels | Should -Contain 'tests'
    }

    It 'returns sorted labels for deterministic output' {
        [hashtable]$config = @{
            Rules = @(
                @{ Pattern = '*.md'; Label = 'markdown'; Priority = 0 }
                @{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 0 }
                @{ Pattern = 'src/**'; Label = 'api'; Priority = 0 }
            )
        }
        [string[]]$changedFiles = @('docs/readme.md', 'src/main.go')

        [string[]]$labels = Invoke-PrLabelAssigner -Config $config -ChangedFiles $changedFiles
        # Labels should come back sorted alphabetically
        [string[]]$sorted = $labels | Sort-Object
        for ([int]$i = 0; $i -lt $labels.Count; $i++) {
            $labels[$i] | Should -Be $sorted[$i]
        }
    }

    It 'supports conflict groups parameter' {
        [hashtable]$config = @{
            Rules = @(
                @{ Pattern = 'src/**'; Label = 'scope:backend'; Priority = 1 }
                @{ Pattern = 'src/api/**'; Label = 'scope:api'; Priority = 10 }
            )
        }
        [hashtable[]]$conflictGroups = @(
            @{ Prefix = 'scope:'; Labels = @('scope:backend', 'scope:api') }
        )
        [string[]]$changedFiles = @('src/api/handler.go')

        [string[]]$labels = Invoke-PrLabelAssigner -Config $config -ChangedFiles $changedFiles -ConflictGroups $conflictGroups
        $labels | Should -Contain 'scope:api'
        $labels | Should -Not -Contain 'scope:backend'
    }
}
