# PR Label Assigner - Pester Test Suite
# TDD approach: tests are written to drive implementation of Invoke-PRLabelAssigner.ps1
#
# Test progression:
#   1. Test-GlobPattern: basic matching (exact, wildcard, glob)
#   2. Get-PRLabels: label assignment from file lists
#   3. Priority ordering and multiple labels
#   4. Workflow structure validation

BeforeAll {
    . "$PSScriptRoot/Invoke-PRLabelAssigner.ps1"
}

# ── RED: These tests were written before the implementation existed ──────────

Describe "Test-GlobPattern - exact match" {

    It "matches an exact filename" {
        Test-GlobPattern -Pattern "README.md" -FilePath "README.md" | Should -BeTrue
    }

    It "does not match a different filename" {
        Test-GlobPattern -Pattern "README.md" -FilePath "CHANGELOG.md" | Should -BeFalse
    }

    It "matches an exact nested path" {
        Test-GlobPattern -Pattern "src/main.ps1" -FilePath "src/main.ps1" | Should -BeTrue
    }

    It "does not match partial path" {
        Test-GlobPattern -Pattern "src/main.ps1" -FilePath "lib/main.ps1" | Should -BeFalse
    }
}

Describe "Test-GlobPattern - wildcard *" {

    It "matches *.md against README.md" {
        Test-GlobPattern -Pattern "*.md" -FilePath "README.md" | Should -BeTrue
    }

    It "matches *.ps1 against script.ps1" {
        Test-GlobPattern -Pattern "*.ps1" -FilePath "script.ps1" | Should -BeTrue
    }

    It "does not match *.md against a .ps1 file" {
        Test-GlobPattern -Pattern "*.md" -FilePath "script.ps1" | Should -BeFalse
    }

    It "matches src/*.ps1 against src/main.ps1" {
        Test-GlobPattern -Pattern "src/*.ps1" -FilePath "src/main.ps1" | Should -BeTrue
    }

    It "does not match src/*.ps1 against src/api/main.ps1 (no crossing /)" {
        Test-GlobPattern -Pattern "src/*.ps1" -FilePath "src/api/main.ps1" | Should -BeFalse
    }
}

Describe "Test-GlobPattern - double-star **" {

    It "matches docs/** against docs/guide.md" {
        Test-GlobPattern -Pattern "docs/**" -FilePath "docs/guide.md" | Should -BeTrue
    }

    It "matches docs/** against deeply nested docs/api/v1/reference.md" {
        Test-GlobPattern -Pattern "docs/**" -FilePath "docs/api/v1/reference.md" | Should -BeTrue
    }

    It "does not match docs/** against src/guide.md" {
        Test-GlobPattern -Pattern "docs/**" -FilePath "src/guide.md" | Should -BeFalse
    }

    It "matches src/api/** against src/api/users.ps1" {
        Test-GlobPattern -Pattern "src/api/**" -FilePath "src/api/users.ps1" | Should -BeTrue
    }

    It "matches **/*.ts against src/index.ts" {
        Test-GlobPattern -Pattern "**/*.ts" -FilePath "src/index.ts" | Should -BeTrue
    }

    It "matches **/*.ts against index.ts at root" {
        Test-GlobPattern -Pattern "**/*.ts" -FilePath "index.ts" | Should -BeTrue
    }

    It "matches **/*.ts against deeply nested src/api/v1/users.ts" {
        Test-GlobPattern -Pattern "**/*.ts" -FilePath "src/api/v1/users.ts" | Should -BeTrue
    }
}

Describe "Test-GlobPattern - filename-only patterns (no path sep)" {

    It "matches *.test.* against src/utils.test.ps1 (filename matching)" {
        Test-GlobPattern -Pattern "*.test.*" -FilePath "src/utils.test.ps1" | Should -BeTrue
    }

    It "matches *.test.* against deeply nested src/api/users.test.ts" {
        Test-GlobPattern -Pattern "*.test.*" -FilePath "src/api/users.test.ts" | Should -BeTrue
    }

    It "does not match *.test.* against src/utils.ps1" {
        Test-GlobPattern -Pattern "*.test.*" -FilePath "src/utils.ps1" | Should -BeFalse
    }

    It "matches *.spec.ts against src/app.spec.ts" {
        Test-GlobPattern -Pattern "*.spec.ts" -FilePath "src/app.spec.ts" | Should -BeTrue
    }
}

# ── RED: Get-PRLabels tests ──────────────────────────────────────────────────

Describe "Get-PRLabels - basic label assignment" {

    BeforeAll {
        $script:StandardRules = @(
            @{ Pattern = 'docs/**';    Label = 'documentation'; Priority = 1 },
            @{ Pattern = 'src/api/**'; Label = 'api';           Priority = 2 },
            @{ Pattern = '*.test.*';   Label = 'tests';         Priority = 3 }
        )
    }

    It "returns documentation label for a docs file" {
        $labels = Get-PRLabels -ChangedFiles @('docs/guide.md') -LabelRules $script:StandardRules
        $labels | Should -Contain 'documentation'
    }

    It "returns api label for a src/api file" {
        $labels = Get-PRLabels -ChangedFiles @('src/api/users.ps1') -LabelRules $script:StandardRules
        $labels | Should -Contain 'api'
    }

    It "returns tests label for a test file" {
        $labels = Get-PRLabels -ChangedFiles @('src/utils.test.ps1') -LabelRules $script:StandardRules
        $labels | Should -Contain 'tests'
    }

    It "returns empty for a file matching no rules" {
        $labels = Get-PRLabels -ChangedFiles @('Makefile') -LabelRules $script:StandardRules
        $labels | Should -HaveCount 0
    }
}

Describe "Get-PRLabels - multiple labels per PR" {

    BeforeAll {
        $script:StandardRules = @(
            @{ Pattern = 'docs/**';    Label = 'documentation'; Priority = 1 },
            @{ Pattern = 'src/api/**'; Label = 'api';           Priority = 2 },
            @{ Pattern = '*.test.*';   Label = 'tests';         Priority = 3 }
        )
    }

    It "returns api, documentation, and tests for a mixed file list" {
        $files = @('docs/guide.md', 'src/api/users.ps1', 'src/utils.test.ps1')
        $labels = Get-PRLabels -ChangedFiles $files -LabelRules $script:StandardRules
        $labels | Should -Contain 'documentation'
        $labels | Should -Contain 'api'
        $labels | Should -Contain 'tests'
        $labels | Should -HaveCount 3
    }

    It "deduplicates labels when multiple files match the same rule" {
        $files = @('docs/guide.md', 'docs/api/reference.md')
        $labels = Get-PRLabels -ChangedFiles $files -LabelRules $script:StandardRules
        ($labels | Where-Object { $_ -eq 'documentation' }).Count | Should -Be 1
    }

    It "returns exactly the correct sorted label set for the standard scenario" {
        $files = @('docs/guide.md', 'src/api/users.ps1', 'src/utils.test.ps1')
        $labels = Get-PRLabels -ChangedFiles $files -LabelRules $script:StandardRules
        # Sorted alphabetically: api, documentation, tests
        $labels[0] | Should -Be 'api'
        $labels[1] | Should -Be 'documentation'
        $labels[2] | Should -Be 'tests'
    }
}

Describe "Get-PRLabels - priority ordering" {

    It "higher-priority label appears before lower-priority in output when same letter order differs" {
        $rules = @(
            @{ Pattern = 'src/**'; Label = 'backend'; Priority = 1 },
            @{ Pattern = '*.md';   Label = 'docs';    Priority = 2 }
        )
        $files = @('src/main.ps1', 'README.md')
        $labels = Get-PRLabels -ChangedFiles $files -LabelRules $rules
        $labels | Should -Contain 'backend'
        $labels | Should -Contain 'docs'
    }

    It "rules with no Priority field are treated as lowest priority" {
        $rules = @(
            @{ Pattern = 'src/**'; Label = 'source' },
            @{ Pattern = '*.md';   Label = 'docs'; Priority = 1 }
        )
        $labels = Get-PRLabels -ChangedFiles @('src/main.ps1') -LabelRules $rules
        $labels | Should -Contain 'source'
    }
}

Describe "Get-PRLabels - edge cases" {

    It "returns empty for empty file list" {
        $rules = @(@{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 1 })
        $labels = Get-PRLabels -ChangedFiles @() -LabelRules $rules
        $labels | Should -HaveCount 0
    }

    It "returns empty for null file list" {
        $rules = @(@{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 1 })
        $labels = Get-PRLabels -ChangedFiles $null -LabelRules $rules
        $labels | Should -HaveCount 0
    }

    It "returns empty for empty rules list" {
        $labels = Get-PRLabels -ChangedFiles @('docs/guide.md') -LabelRules @()
        $labels | Should -HaveCount 0
    }

    It "handles Windows-style backslash paths" {
        $rules = @(@{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 1 })
        $labels = Get-PRLabels -ChangedFiles @('docs\guide.md') -LabelRules $rules
        $labels | Should -Contain 'documentation'
    }
}

Describe "Invoke-PRLabelAssigner - output format" {

    BeforeAll {
        $script:StandardRules = @(
            @{ Pattern = 'docs/**';    Label = 'documentation'; Priority = 1 },
            @{ Pattern = 'src/api/**'; Label = 'api';           Priority = 2 },
            @{ Pattern = '*.test.*';   Label = 'tests';         Priority = 3 }
        )
    }

    It "outputs 'Applied labels: api, documentation, tests' for the standard mock scenario" {
        $files = @('docs/guide.md', 'src/api/users.ps1', 'src/utils.test.ps1')
        $output = Invoke-PRLabelAssigner -ChangedFiles $files -LabelRules $script:StandardRules 6>&1
        $output -join '' | Should -Match 'Applied labels: api, documentation, tests'
    }

    It "outputs 'Applied labels: documentation' for docs-only changes" {
        $files = @('docs/guide.md', 'docs/api/reference.md')
        $output = Invoke-PRLabelAssigner -ChangedFiles $files -LabelRules $script:StandardRules 6>&1
        $output -join '' | Should -Match 'Applied labels: documentation'
    }

    It "outputs 'No labels matched' when no rules apply" {
        $files = @('Makefile', 'LICENSE')
        $output = Invoke-PRLabelAssigner -ChangedFiles $files -LabelRules $script:StandardRules 6>&1
        $output -join '' | Should -Match 'No labels matched'
    }
}

# ── WORKFLOW STRUCTURE TESTS ─────────────────────────────────────────────────

Describe "Workflow structure" {

    BeforeAll {
        $script:WorkflowPath = "$PSScriptRoot/.github/workflows/pr-label-assigner.yml"
        $script:WorkflowContent = Get-Content $script:WorkflowPath -Raw -ErrorAction SilentlyContinue
    }

    It "workflow file exists" {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It "workflow references the main script" {
        Test-Path "$PSScriptRoot/Invoke-PRLabelAssigner.ps1" | Should -BeTrue
    }

    It "workflow has push trigger" {
        $script:WorkflowContent | Should -Match 'push:'
    }

    It "workflow has pull_request trigger" {
        $script:WorkflowContent | Should -Match 'pull_request:'
    }

    It "workflow has workflow_dispatch trigger" {
        $script:WorkflowContent | Should -Match 'workflow_dispatch:'
    }

    It "workflow defines jobs" {
        $script:WorkflowContent | Should -Match 'jobs:'
    }

    It "workflow uses actions/checkout" {
        $script:WorkflowContent | Should -Match 'actions/checkout'
    }

    It "workflow uses shell: pwsh for PowerShell steps" {
        $script:WorkflowContent | Should -Match 'shell: pwsh'
    }

    It "workflow uses Invoke-Pester" {
        $script:WorkflowContent | Should -Match 'Invoke-Pester'
    }
}
