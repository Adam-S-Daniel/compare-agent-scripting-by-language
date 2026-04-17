# Pester tests for PRLabelAssigner module.
# Run with: Invoke-Pester -Path PRLabelAssigner.Tests.ps1

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot 'PRLabelAssigner.psm1'
    Import-Module $ModulePath -Force
}

Describe 'Convert-GlobToRegex' {
    It 'converts ** to match any path including slashes' {
        Convert-GlobToRegex 'docs/**' | Should -Be '^docs/.*$'
    }
    It 'converts * to match a single path segment' {
        Convert-GlobToRegex 'src/*.ps1' | Should -Be '^src/[^/]*\.ps1$'
    }
    It 'escapes regex metacharacters' {
        Convert-GlobToRegex 'a.b+c' | Should -Be '^a\.b\+c$'
    }
    It 'handles *.test.* pattern' {
        Convert-GlobToRegex '*.test.*' | Should -Be '^[^/]*\.test\.[^/]*$'
    }
}

Describe 'Test-GlobMatch' {
    It 'matches docs/** against nested docs file' {
        Test-GlobMatch -Path 'docs/guide/intro.md' -Pattern 'docs/**' | Should -BeTrue
    }
    It 'does not match docs/** against outside path' {
        Test-GlobMatch -Path 'src/app.ps1' -Pattern 'docs/**' | Should -BeFalse
    }
    It 'matches *.test.* at any depth when rooted with **/' {
        Test-GlobMatch -Path 'src/foo.test.js' -Pattern '**/*.test.*' | Should -BeTrue
    }
    It 'matches simple star pattern on a single segment' {
        Test-GlobMatch -Path 'README.md' -Pattern '*.md' | Should -BeTrue
    }
}

Describe 'Invoke-PRLabelAssigner' {
    It 'assigns documentation label for docs/** files' {
        $rules = @(
            @{ pattern = 'docs/**'; labels = @('documentation'); priority = 10 }
        )
        $files = @('docs/intro.md', 'docs/guide/setup.md')
        $result = Invoke-PRLabelAssigner -ChangedFiles $files -Rules $rules
        $result | Should -Contain 'documentation'
        ($result | Measure-Object).Count | Should -Be 1
    }

    It 'applies multiple labels when multiple rules match a file' {
        $rules = @(
            @{ pattern = 'src/api/**'; labels = @('api'); priority = 20 }
            @{ pattern = '**/*.ps1'; labels = @('powershell'); priority = 5 }
        )
        $files = @('src/api/handler.ps1')
        $result = Invoke-PRLabelAssigner -ChangedFiles $files -Rules $rules
        $result | Should -Contain 'api'
        $result | Should -Contain 'powershell'
    }

    It 'returns labels ordered by priority descending' {
        $rules = @(
            @{ pattern = '**/*.md'; labels = @('docs'); priority = 1 }
            @{ pattern = 'src/**'; labels = @('source'); priority = 50 }
            @{ pattern = '**/*.test.*'; labels = @('tests'); priority = 100 }
        )
        $files = @('README.md', 'src/app.js', 'src/foo.test.js')
        $result = Invoke-PRLabelAssigner -ChangedFiles $files -Rules $rules
        $result[0] | Should -Be 'tests'
        $result[1] | Should -Be 'source'
        $result[2] | Should -Be 'docs'
    }

    It 'deduplicates labels across multiple files' {
        $rules = @(
            @{ pattern = 'docs/**'; labels = @('documentation'); priority = 10 }
        )
        $files = @('docs/a.md', 'docs/b.md', 'docs/c.md')
        $result = Invoke-PRLabelAssigner -ChangedFiles $files -Rules $rules
        ($result | Measure-Object).Count | Should -Be 1
    }

    It 'supports a rule emitting multiple labels' {
        $rules = @(
            @{ pattern = 'src/api/**'; labels = @('api', 'backend'); priority = 10 }
        )
        $files = @('src/api/user.ps1')
        $result = Invoke-PRLabelAssigner -ChangedFiles $files -Rules $rules
        $result | Should -Contain 'api'
        $result | Should -Contain 'backend'
    }

    It 'returns an empty array when no rule matches' {
        $rules = @(
            @{ pattern = 'src/**'; labels = @('source'); priority = 1 }
        )
        $files = @('README.md')
        $result = @(Invoke-PRLabelAssigner -ChangedFiles $files -Rules $rules)
        $result.Count | Should -Be 0
    }

    It 'throws a meaningful error when a rule is missing the pattern field' {
        $rules = @(
            @{ labels = @('api'); priority = 10 }
        )
        { Invoke-PRLabelAssigner -ChangedFiles @('src/api/x.ps1') -Rules $rules } |
            Should -Throw '*pattern*'
    }

    It 'throws a meaningful error when a rule is missing the labels field' {
        $rules = @(
            @{ pattern = 'src/**'; priority = 1 }
        )
        { Invoke-PRLabelAssigner -ChangedFiles @('src/x.ps1') -Rules $rules } |
            Should -Throw '*labels*'
    }

    It 'treats missing priority as 0' {
        $rules = @(
            @{ pattern = 'a/**'; labels = @('a') }
            @{ pattern = 'b/**'; labels = @('b'); priority = 5 }
        )
        $result = Invoke-PRLabelAssigner -ChangedFiles @('a/x', 'b/y') -Rules $rules
        $result[0] | Should -Be 'b'
        $result[1] | Should -Be 'a'
    }
}

Describe 'Get-RulesFromFile' {
    It 'loads rules from a JSON file' {
        $tmp = New-TemporaryFile
        try {
            $json = @'
[
  { "pattern": "docs/**", "labels": ["documentation"], "priority": 10 },
  { "pattern": "src/api/**", "labels": ["api"], "priority": 20 }
]
'@
            Set-Content -Path $tmp.FullName -Value $json
            $rules = Get-RulesFromFile -Path $tmp.FullName
            ($rules | Measure-Object).Count | Should -Be 2
            $rules[0].pattern | Should -Be 'docs/**'
        } finally {
            Remove-Item $tmp.FullName -ErrorAction SilentlyContinue
        }
    }

    It 'throws a meaningful error when the file does not exist' {
        { Get-RulesFromFile -Path '/nonexistent/does/not/exist.json' } |
            Should -Throw '*not*found*'
    }
}
