# Pester tests for PRLabeler module.
# Tests are grouped red/green-style: each Describe block exercises one capability
# that was added via TDD in order (glob -> multi-label -> priority -> errors).

BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $modulePath = Join-Path $here '..' 'src' 'PRLabeler.psm1'
    Import-Module $modulePath -Force
}

Describe 'Convert-GlobToRegex (internal helper)' {
    It 'converts ** to match path segments including slashes' {
        $rx = Convert-GlobToRegex 'docs/**'
        'docs/readme.md'        | Should -Match $rx
        'docs/sub/dir/file.txt' | Should -Match $rx
        'src/docs/readme.md'    | Should -Not -Match $rx
    }

    It 'converts * to match within a single segment only' {
        $rx = Convert-GlobToRegex 'src/*.js'
        'src/index.js' | Should -Match $rx
        'src/sub/index.js' | Should -Not -Match $rx
    }

    It 'escapes regex meta-characters' {
        $rx = Convert-GlobToRegex 'file.txt'
        'file.txt'  | Should -Match $rx
        'filextxt'  | Should -Not -Match $rx
    }

    It 'supports ? for a single non-slash character' {
        $rx = Convert-GlobToRegex 'a?c.txt'
        'abc.txt' | Should -Match $rx
        'a/c.txt' | Should -Not -Match $rx
    }
}

Describe 'Test-GlobMatch' {
    It 'matches docs/** against nested docs file' {
        Test-GlobMatch -Path 'docs/guide/intro.md' -Pattern 'docs/**' | Should -BeTrue
    }

    It 'matches **/*.test.* anywhere in tree' {
        Test-GlobMatch -Path 'src/utils/helper.test.js' -Pattern '**/*.test.*' | Should -BeTrue
        Test-GlobMatch -Path 'foo.test.py'                -Pattern '**/*.test.*' | Should -BeTrue
    }

    It 'does not match non-matching path' {
        Test-GlobMatch -Path 'src/main.js' -Pattern 'docs/**' | Should -BeFalse
    }
}

Describe 'Get-PRLabels basic glob matching' {
    It 'assigns a single label when one rule matches' {
        $rules = @(
            @{ pattern = 'docs/**'; labels = @('documentation') }
        )
        $files = @('docs/readme.md')
        $labels = Get-PRLabels -Files $files -Rules $rules
        $labels | Should -Be @('documentation')
    }

    It 'returns empty array when no rule matches' {
        $rules = @(
            @{ pattern = 'docs/**'; labels = @('documentation') }
        )
        $labels = Get-PRLabels -Files @('src/index.js') -Rules $rules
        $labels.Count | Should -Be 0
    }
}

Describe 'Get-PRLabels with multiple labels per rule' {
    It 'applies all labels from a matching rule' {
        $rules = @(
            @{ pattern = 'src/api/**'; labels = @('api', 'backend') }
        )
        $labels = Get-PRLabels -Files @('src/api/users.js') -Rules $rules
        # Order here follows rule definition order; priority handles conflicts.
        $labels | Should -Contain 'api'
        $labels | Should -Contain 'backend'
        $labels.Count | Should -Be 2
    }

    It 'deduplicates labels when multiple files/rules produce the same label' {
        $rules = @(
            @{ pattern = 'docs/**';  labels = @('documentation') }
            @{ pattern = '*.md';     labels = @('documentation') }
        )
        $files = @('docs/a.md', 'docs/b.md', 'README.md')
        $labels = Get-PRLabels -Files $files -Rules $rules
        $labels.Count | Should -Be 1
        $labels[0] | Should -Be 'documentation'
    }
}

Describe 'Get-PRLabels priority ordering' {
    It 'orders output by descending priority (higher first)' {
        $rules = @(
            @{ pattern = 'docs/**';    labels = @('documentation'); priority = 1 }
            @{ pattern = 'src/api/**'; labels = @('api');           priority = 10 }
            @{ pattern = '*.test.*';   labels = @('tests');         priority = 5 }
        )
        $files = @('docs/a.md', 'src/api/users.js', 'foo.test.js')
        $labels = Get-PRLabels -Files $files -Rules $rules
        # priority: api(10) > tests(5) > documentation(1)
        $labels[0] | Should -Be 'api'
        $labels[1] | Should -Be 'tests'
        $labels[2] | Should -Be 'documentation'
    }

    It 'defaults missing priority to 0' {
        $rules = @(
            @{ pattern = 'docs/**';    labels = @('documentation') }
            @{ pattern = 'src/api/**'; labels = @('api');           priority = 5 }
        )
        $files = @('docs/a.md', 'src/api/users.js')
        $labels = Get-PRLabels -Files $files -Rules $rules
        $labels[0] | Should -Be 'api'
        $labels[1] | Should -Be 'documentation'
    }
}

Describe 'Get-PRLabels combined realistic scenario' {
    It 'applies docs, api, and tests labels from a mixed PR' {
        $rules = @(
            @{ pattern = 'docs/**';    labels = @('documentation'); priority = 1 }
            @{ pattern = 'src/api/**'; labels = @('api', 'backend'); priority = 10 }
            @{ pattern = '**/*.test.*'; labels = @('tests');         priority = 5 }
        )
        $files = @(
            'docs/readme.md',
            'src/api/v1/auth.js',
            'src/api/v1/auth.test.js',
            'src/web/index.html'
        )
        $labels = Get-PRLabels -Files $files -Rules $rules
        $labels | Should -Contain 'documentation'
        $labels | Should -Contain 'api'
        $labels | Should -Contain 'backend'
        $labels | Should -Contain 'tests'
        $labels.Count | Should -Be 4
        # api/backend priority 10 comes first
        $labels[0] | Should -BeIn @('api', 'backend')
        $labels[1] | Should -BeIn @('api', 'backend')
    }
}

Describe 'Get-PRLabels from JSON config file' {
    It 'loads rules from JSON and applies them' {
        $tmpConfig = New-TemporaryFile
        @{
            rules = @(
                @{ pattern = 'docs/**'; labels = @('documentation'); priority = 1 }
                @{ pattern = 'src/**';  labels = @('code');          priority = 2 }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $tmpConfig.FullName
        try {
            $labels = Get-PRLabels -Files @('docs/a.md', 'src/main.js') -ConfigPath $tmpConfig.FullName
            $labels | Should -Contain 'documentation'
            $labels | Should -Contain 'code'
            $labels[0] | Should -Be 'code'
        } finally {
            Remove-Item -Force $tmpConfig.FullName
        }
    }
}

Describe 'Get-PRLabels error handling' {
    It 'throws when neither Rules nor ConfigPath is provided' {
        { Get-PRLabels -Files @('x.md') } | Should -Throw '*Rules*ConfigPath*'
    }

    It 'throws when ConfigPath does not exist' {
        { Get-PRLabels -Files @('x.md') -ConfigPath '/tmp/does/not/exist.json' } |
            Should -Throw '*not found*'
    }

    It 'throws when a rule is missing required fields' {
        $badRules = @(
            @{ labels = @('x') } # missing pattern
        )
        { Get-PRLabels -Files @('x.md') -Rules $badRules } |
            Should -Throw '*pattern*'
    }

    It 'throws when ConfigPath contains malformed JSON' {
        $tmpConfig = New-TemporaryFile
        'not { valid json' | Set-Content -Path $tmpConfig.FullName
        try {
            { Get-PRLabels -Files @('x.md') -ConfigPath $tmpConfig.FullName } |
                Should -Throw '*JSON*'
        } finally {
            Remove-Item -Force $tmpConfig.FullName
        }
    }

    It 'accepts empty file list and returns empty labels' {
        $rules = @(@{ pattern = 'docs/**'; labels = @('documentation') })
        $labels = Get-PRLabels -Files @() -Rules $rules
        $labels.Count | Should -Be 0
    }
}
