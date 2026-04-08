# PR Label Assigner - Pester Tests
# TDD approach: tests are written first, then implementation follows
# Using PowerShell strict mode throughout

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import the module under test (will fail until module exists)
$ModulePath = Join-Path $PSScriptRoot 'PrLabelAssigner.psm1'
Import-Module $ModulePath -Force

Describe 'ConvertTo-RegexFromGlob' {
    # Tests for glob pattern -> regex conversion
    # This is the core matching engine

    It 'converts a simple wildcard * to match non-separator chars' {
        $regex = ConvertTo-RegexFromGlob -GlobPattern '*.ps1'
        $regex | Should -Not -BeNullOrEmpty
        'script.ps1' | Should -Match $regex
        'path/script.ps1' | Should -Not -Match $regex
    }

    It 'converts ** to match across path separators' {
        $regex = ConvertTo-RegexFromGlob -GlobPattern 'docs/**'
        'docs/readme.md' | Should -Match $regex
        'docs/api/reference.md' | Should -Match $regex
        'src/readme.md' | Should -Not -Match $regex
    }

    It 'converts ? to match a single non-separator char' {
        $regex = ConvertTo-RegexFromGlob -GlobPattern 'src/?.ps1'
        'src/a.ps1' | Should -Match $regex
        'src/ab.ps1' | Should -Not -Match $regex
    }

    It 'escapes literal dots in pattern' {
        $regex = ConvertTo-RegexFromGlob -GlobPattern '*.test.ps1'
        'foo.test.ps1' | Should -Match $regex
        'footestps1' | Should -Not -Match $regex
    }

    It 'matches pattern with directory prefix' {
        $regex = ConvertTo-RegexFromGlob -GlobPattern 'src/api/**'
        'src/api/users.ps1' | Should -Match $regex
        'src/api/v2/users.ps1' | Should -Match $regex
        'src/lib/users.ps1' | Should -Not -Match $regex
    }
}

Describe 'Test-GlobMatch' {
    # Tests for the public matching function

    It 'returns true when path matches glob' {
        Test-GlobMatch -Path 'docs/readme.md' -GlobPattern 'docs/**' | Should -BeTrue
    }

    It 'returns false when path does not match glob' {
        Test-GlobMatch -Path 'src/app.ps1' -GlobPattern 'docs/**' | Should -BeFalse
    }

    It 'matches *.test.* pattern for test files' {
        Test-GlobMatch -Path 'app.test.js' -GlobPattern '*.test.*' | Should -BeTrue
        Test-GlobMatch -Path 'app.spec.js' -GlobPattern '*.test.*' | Should -BeFalse
    }

    It 'matches nested test files with **/*.test.*' {
        Test-GlobMatch -Path 'src/components/Button.test.tsx' -GlobPattern '**/*.test.*' | Should -BeTrue
        Test-GlobMatch -Path 'src/components/Button.tsx' -GlobPattern '**/*.test.*' | Should -BeFalse
    }

    It 'handles forward and backward slashes uniformly' {
        Test-GlobMatch -Path 'docs\readme.md' -GlobPattern 'docs/**' | Should -BeTrue
    }
}

Describe 'Get-LabelsForFile' {
    # Tests for applying labels to a single file path

    BeforeAll {
        # Standard test rules fixture
        $script:TestRules = @(
            [PSCustomObject]@{ Pattern = 'docs/**';    Label = 'documentation'; Priority = 10 }
            [PSCustomObject]@{ Pattern = 'src/api/**'; Label = 'api';           Priority = 20 }
            [PSCustomObject]@{ Pattern = '**/*.test.*'; Label = 'tests';        Priority = 30 }
            [PSCustomObject]@{ Pattern = 'src/**';     Label = 'source';        Priority = 5  }
        )
    }

    It 'returns a single label when one rule matches' {
        $labels = Get-LabelsForFile -FilePath 'docs/readme.md' -Rules $script:TestRules
        $labels | Should -Contain 'documentation'
    }

    It 'returns empty array when no rules match' {
        $labels = Get-LabelsForFile -FilePath 'build/output.exe' -Rules $script:TestRules
        $labels | Should -HaveCount 0
    }

    It 'returns multiple labels when multiple rules match' {
        # src/api/users.test.js matches src/api/**, **/*.test.*, and src/**
        $labels = Get-LabelsForFile -FilePath 'src/api/users.test.js' -Rules $script:TestRules
        $labels | Should -Contain 'api'
        $labels | Should -Contain 'tests'
        $labels | Should -Contain 'source'
    }

    It 'returns labels ordered by priority descending' {
        # src/api/users.test.js matches multiple rules; highest priority first
        $labels = Get-LabelsForFile -FilePath 'src/api/users.test.js' -Rules $script:TestRules
        # tests (30) > api (20) > source (5)
        $labels[0] | Should -Be 'tests'
        $labels[1] | Should -Be 'api'
        $labels[2] | Should -Be 'source'
    }
}

Describe 'Get-PrLabels' {
    # Tests for processing a full PR (multiple changed files)

    BeforeAll {
        $script:TestRules = @(
            [PSCustomObject]@{ Pattern = 'docs/**';     Label = 'documentation'; Priority = 10 }
            [PSCustomObject]@{ Pattern = 'src/api/**';  Label = 'api';           Priority = 20 }
            [PSCustomObject]@{ Pattern = '**/*.test.*'; Label = 'tests';         Priority = 30 }
            [PSCustomObject]@{ Pattern = 'src/**';      Label = 'source';        Priority = 5  }
            [PSCustomObject]@{ Pattern = '*.md';        Label = 'markdown';      Priority = 15 }
        )
    }

    It 'returns empty array when no files match any rules' {
        $labels = Get-PrLabels -ChangedFiles @('build/app.exe', 'dist/bundle.js') -Rules $script:TestRules
        $labels | Should -HaveCount 0
    }

    It 'returns deduplicated labels across all changed files' {
        # Both files match 'documentation'; result should have it only once
        $files = @('docs/readme.md', 'docs/api/guide.md')
        $labels = Get-PrLabels -ChangedFiles $files -Rules $script:TestRules
        ($labels | Where-Object { $_ -eq 'documentation' }) | Should -HaveCount 1
    }

    It 'collects labels from all changed files' {
        $files = @('docs/readme.md', 'src/api/users.js', 'src/app.test.js')
        $labels = Get-PrLabels -ChangedFiles $files -Rules $script:TestRules
        $labels | Should -Contain 'documentation'
        $labels | Should -Contain 'api'
        $labels | Should -Contain 'tests'
        $labels | Should -Contain 'source'
    }

    It 'handles a single changed file' {
        $labels = Get-PrLabels -ChangedFiles @('docs/intro.md') -Rules $script:TestRules
        $labels | Should -Contain 'documentation'
    }

    It 'handles empty changed files list' {
        $labels = Get-PrLabels -ChangedFiles @() -Rules $script:TestRules
        $labels | Should -HaveCount 0
    }
}

Describe 'New-LabelRule' {
    # Tests for the rule constructor / validation

    It 'creates a valid rule object' {
        $rule = New-LabelRule -Pattern 'docs/**' -Label 'documentation' -Priority 10
        $rule.Pattern  | Should -Be 'docs/**'
        $rule.Label    | Should -Be 'documentation'
        $rule.Priority | Should -Be 10
    }

    It 'throws when pattern is empty' {
        { New-LabelRule -Pattern '' -Label 'docs' -Priority 1 } | Should -Throw
    }

    It 'throws when label is empty' {
        { New-LabelRule -Pattern 'docs/**' -Label '' -Priority 1 } | Should -Throw
    }

    It 'throws when priority is negative' {
        { New-LabelRule -Pattern 'docs/**' -Label 'docs' -Priority -1 } | Should -Throw
    }
}

Describe 'Import-LabelConfig' {
    # Tests for loading rules from a JSON config file

    BeforeAll {
        $script:TempDir = [System.IO.Path]::GetTempPath()
        $script:ConfigPath = Join-Path $script:TempDir 'label-config.json'

        $configData = @{
            rules = @(
                @{ pattern = 'docs/**';    label = 'documentation'; priority = 10 }
                @{ pattern = 'src/api/**'; label = 'api';           priority = 20 }
            )
        }
        $configData | ConvertTo-Json -Depth 3 | Set-Content -Path $script:ConfigPath -Encoding UTF8
    }

    AfterAll {
        if (Test-Path $script:ConfigPath) {
            Remove-Item $script:ConfigPath -Force
        }
    }

    It 'loads rules from a JSON config file' {
        $rules = Import-LabelConfig -ConfigPath $script:ConfigPath
        $rules | Should -HaveCount 2
    }

    It 'maps JSON fields to rule properties' {
        $rules = Import-LabelConfig -ConfigPath $script:ConfigPath
        $rules[0].Pattern  | Should -Be 'docs/**'
        $rules[0].Label    | Should -Be 'documentation'
        $rules[0].Priority | Should -Be 10
    }

    It 'throws when config file does not exist' {
        { Import-LabelConfig -ConfigPath 'nonexistent.json' } | Should -Throw
    }
}

Describe 'End-to-end: Mock PR scenarios' {
    # Integration tests using realistic mock PR data

    BeforeAll {
        # Realistic label rules mimicking a real project
        $script:ProjectRules = @(
            [PSCustomObject]@{ Pattern = 'docs/**';           Label = 'documentation'; Priority = 10 }
            [PSCustomObject]@{ Pattern = '**/*.md';           Label = 'documentation'; Priority = 10 }
            [PSCustomObject]@{ Pattern = 'src/api/**';        Label = 'api';           Priority = 25 }
            [PSCustomObject]@{ Pattern = 'src/frontend/**';   Label = 'frontend';      Priority = 25 }
            [PSCustomObject]@{ Pattern = '**/*.test.*';       Label = 'tests';         Priority = 30 }
            [PSCustomObject]@{ Pattern = '**/*.spec.*';       Label = 'tests';         Priority = 30 }
            [PSCustomObject]@{ Pattern = '.github/**';        Label = 'ci/cd';         Priority = 20 }
            [PSCustomObject]@{ Pattern = 'src/**';            Label = 'source';        Priority = 5  }
            [PSCustomObject]@{ Pattern = '**';               Label = 'changed';        Priority = 1  }
        )
    }

    It 'labels a documentation-only PR correctly' {
        $files = @('docs/guide.md', 'docs/api/reference.md', 'README.md')
        $labels = Get-PrLabels -ChangedFiles $files -Rules $script:ProjectRules
        $labels | Should -Contain 'documentation'
        $labels | Should -Not -Contain 'api'
        $labels | Should -Not -Contain 'tests'
    }

    It 'labels a mixed source + test PR correctly' {
        $files = @(
            'src/api/users.js',
            'src/api/users.test.js',
            'src/frontend/App.tsx',
            'src/frontend/App.spec.tsx'
        )
        $labels = Get-PrLabels -ChangedFiles $files -Rules $script:ProjectRules
        $labels | Should -Contain 'api'
        $labels | Should -Contain 'frontend'
        $labels | Should -Contain 'tests'
        $labels | Should -Contain 'source'
    }

    It 'labels a CI/CD change correctly' {
        $files = @('.github/workflows/ci.yml', '.github/dependabot.yml')
        $labels = Get-PrLabels -ChangedFiles $files -Rules $script:ProjectRules
        $labels | Should -Contain 'ci/cd'
    }

    It 'every PR gets the "changed" catch-all label' {
        $files = @('some/random/file.xyz')
        $labels = Get-PrLabels -ChangedFiles $files -Rules $script:ProjectRules
        $labels | Should -Contain 'changed'
    }
}
