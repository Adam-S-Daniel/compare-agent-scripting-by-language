# Pester tests for PrLabelAssigner module.
# Run with: Invoke-Pester ./PrLabelAssigner.Tests.ps1

BeforeAll {
    Import-Module "$PSScriptRoot/PrLabelAssigner.psm1" -Force
}

Describe 'Test-GlobMatch' {
    It 'matches simple patterns' {
        Test-GlobMatch -Path 'docs/readme.md' -Pattern 'docs/**' | Should -BeTrue
    }
    It 'does not match unrelated paths' {
        Test-GlobMatch -Path 'src/main.ps1' -Pattern 'docs/**' | Should -BeFalse
    }
    It 'matches deep paths with **' {
        Test-GlobMatch -Path 'src/api/v1/users.ps1' -Pattern 'src/api/**' | Should -BeTrue
    }
    It 'matches single-level wildcard *' {
        Test-GlobMatch -Path 'foo.md' -Pattern '*.md' | Should -BeTrue
    }
    It 'matches files with double extension via *.test.*' {
        Test-GlobMatch -Path 'utils.test.ps1' -Pattern '*.test.*' | Should -BeTrue
    }
    It '* does not cross directory separators' {
        Test-GlobMatch -Path 'src/foo.md' -Pattern '*.md' | Should -BeFalse
    }
}

Describe 'Get-PrLabels' {
    It 'assigns the documentation label for docs files' {
        $rules = @(
            @{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 10 }
        )
        $files = @('docs/readme.md', 'docs/guide/intro.md')
        $labels = Get-PrLabels -ChangedFiles $files -Rules $rules
        $labels | Should -Contain 'documentation'
        $labels.Count | Should -Be 1
    }

    It 'returns empty array when no rules match' {
        $rules = @(@{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 10 })
        $labels = Get-PrLabels -ChangedFiles @('src/main.ps1') -Rules $rules
        ,$labels | Should -BeOfType [System.Array]
        $labels.Count | Should -Be 0
    }

    It 'supports multiple labels for one file' {
        $rules = @(
            @{ Pattern = 'src/api/**';   Label = 'api'; Priority = 10 }
            @{ Pattern = '**/*.test.*'; Label = 'tests'; Priority = 5 }
        )
        $labels = Get-PrLabels -ChangedFiles @('src/api/users.test.ps1') -Rules $rules
        $labels | Should -Contain 'api'
        $labels | Should -Contain 'tests'
    }

    It 'deduplicates labels across files' {
        $rules = @(@{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 10 })
        $labels = Get-PrLabels -ChangedFiles @('docs/a.md','docs/b.md') -Rules $rules
        $labels.Count | Should -Be 1
    }

    It 'orders labels by descending rule priority' {
        $rules = @(
            @{ Pattern = '**/*.md';      Label = 'documentation'; Priority = 1 }
            @{ Pattern = 'src/api/**';   Label = 'api';          Priority = 50 }
            @{ Pattern = '**/*.test.*'; Label = 'tests';        Priority = 20 }
        )
        $files = @('src/api/users.ps1', 'docs/readme.md', 'src/api/users.test.ps1')
        $labels = Get-PrLabels -ChangedFiles $files -Rules $rules
        $labels[0] | Should -Be 'api'
        $labels[1] | Should -Be 'tests'
        $labels[2] | Should -Be 'documentation'
    }

    It 'throws on null rules' {
        { Get-PrLabels -ChangedFiles @('a.md') -Rules $null } | Should -Throw
    }
}

Describe 'Import-LabelRules' {
    It 'reads rules from JSON config' {
        $tmp = New-TemporaryFile
        @'
[
  { "pattern": "docs/**", "label": "documentation", "priority": 10 },
  { "pattern": "src/api/**", "label": "api", "priority": 50 }
]
'@ | Set-Content -Path $tmp
        try {
            $rules = Import-LabelRules -Path $tmp
            $rules.Count | Should -Be 2
            $rules[0].Label | Should -Be 'documentation'
            $rules[1].Priority | Should -Be 50
        } finally {
            Remove-Item $tmp -Force
        }
    }

    It 'throws when config file is missing' {
        { Import-LabelRules -Path '/nonexistent/labels.json' } | Should -Throw
    }
}

Describe 'Invoke-LabelAssigner end-to-end' {
    It 'returns labels given a JSON file list and rules file' {
        $rulesFile = New-TemporaryFile
        $filesFile = New-TemporaryFile
        @'
[
  { "pattern": "docs/**", "label": "documentation", "priority": 10 },
  { "pattern": "**/*.test.*", "label": "tests", "priority": 50 },
  { "pattern": "src/api/**", "label": "api", "priority": 30 }
]
'@ | Set-Content -Path $rulesFile
        @'
["docs/readme.md", "src/api/users.ps1", "src/api/users.test.ps1"]
'@ | Set-Content -Path $filesFile
        try {
            $labels = Invoke-LabelAssigner -RulesPath $rulesFile -FilesPath $filesFile
            $labels | Should -Contain 'documentation'
            $labels | Should -Contain 'api'
            $labels | Should -Contain 'tests'
            $labels[0] | Should -Be 'tests'  # highest priority first
        } finally {
            Remove-Item $rulesFile,$filesFile -Force
        }
    }
}
