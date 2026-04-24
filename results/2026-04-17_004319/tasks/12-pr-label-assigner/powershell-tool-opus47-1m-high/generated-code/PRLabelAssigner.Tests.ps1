# Pester tests for PRLabelAssigner.
# Developed red/green: each Describe block below was added as a failing test
# first, then the module was extended to make it pass.

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot 'PRLabelAssigner.psm1'
    Import-Module $ModulePath -Force
}

Describe 'Get-PRLabels - empty input' {
    It 'returns an empty array when no changed files are provided' {
        $rules = @(@{ Pattern = 'docs/**'; Labels = @('documentation') })
        $result = Get-PRLabels -ChangedFiles @() -Rules $rules
        ,$result | Should -BeOfType [System.Array]
        $result.Count | Should -Be 0
    }

    It 'returns an empty array when no rules match' {
        $rules = @(@{ Pattern = 'docs/**'; Labels = @('documentation') })
        $result = Get-PRLabels -ChangedFiles @('src/main.ps1') -Rules $rules
        $result.Count | Should -Be 0
    }
}

Describe 'Get-PRLabels - basic matching' {
    It 'matches a simple ** glob against a nested path' {
        $rules = @(@{ Pattern = 'docs/**'; Labels = @('documentation') })
        $result = Get-PRLabels -ChangedFiles @('docs/intro.md') -Rules $rules
        $result | Should -Contain 'documentation'
    }

    It 'matches ** across multiple directory segments' {
        $rules = @(@{ Pattern = 'src/api/**'; Labels = @('api') })
        $result = Get-PRLabels -ChangedFiles @('src/api/v1/users/handler.ps1') -Rules $rules
        $result | Should -Contain 'api'
    }

    It 'matches a single-star glob within a single path segment' {
        $rules = @(@{ Pattern = '*.md'; Labels = @('docs') })
        $result = Get-PRLabels -ChangedFiles @('README.md') -Rules $rules
        $result | Should -Contain 'docs'
    }

    It 'matches wildcard across arbitrary depth when pattern uses **' {
        $rules = @(@{ Pattern = '**/*.test.*'; Labels = @('tests') })
        $result = Get-PRLabels -ChangedFiles @('src/app/util.test.ps1') -Rules $rules
        $result | Should -Contain 'tests'
    }

    It 'matches *.test.* against a root-level test file' {
        $rules = @(@{ Pattern = '**/*.test.*'; Labels = @('tests') })
        $result = Get-PRLabels -ChangedFiles @('main.test.js') -Rules $rules
        $result | Should -Contain 'tests'
    }

    It 'does not match when pattern is strictly different' {
        $rules = @(@{ Pattern = 'docs/**'; Labels = @('documentation') })
        $result = Get-PRLabels -ChangedFiles @('documents/intro.md') -Rules $rules
        $result.Count | Should -Be 0
    }

    It 'does not match ? across multiple characters' {
        $rules = @(@{ Pattern = 'a?.txt'; Labels = @('single') })
        $result = Get-PRLabels -ChangedFiles @('abcd.txt') -Rules $rules
        $result.Count | Should -Be 0
    }

    It 'matches ? for exactly one character' {
        $rules = @(@{ Pattern = 'a?.txt'; Labels = @('single') })
        $result = Get-PRLabels -ChangedFiles @('ab.txt') -Rules $rules
        $result | Should -Contain 'single'
    }
}

Describe 'Get-PRLabels - multiple labels per file' {
    It 'applies all labels from a single rule' {
        $rules = @(@{ Pattern = 'src/api/**'; Labels = @('api', 'backend') })
        $result = Get-PRLabels -ChangedFiles @('src/api/users.ps1') -Rules $rules
        $result | Should -Contain 'api'
        $result | Should -Contain 'backend'
    }

    It 'combines labels from multiple matching rules' {
        $rules = @(
            @{ Pattern = 'src/**'; Labels = @('code') },
            @{ Pattern = '**/*.ps1'; Labels = @('powershell') }
        )
        $result = Get-PRLabels -ChangedFiles @('src/util.ps1') -Rules $rules
        $result | Should -Contain 'code'
        $result | Should -Contain 'powershell'
    }

    It 'deduplicates labels produced by different files/rules' {
        $rules = @(
            @{ Pattern = 'src/**'; Labels = @('code') },
            @{ Pattern = 'lib/**'; Labels = @('code') }
        )
        $result = Get-PRLabels -ChangedFiles @('src/a.ps1', 'lib/b.ps1') -Rules $rules
        ($result | Where-Object { $_ -eq 'code' }).Count | Should -Be 1
    }
}

Describe 'Get-PRLabels - priority ordering' {
    It 'orders output by priority ascending (lower number = higher priority first)' {
        $rules = @(
            @{ Pattern = '**/*.ps1'; Labels = @('powershell'); Priority = 10 },
            @{ Pattern = 'src/api/**'; Labels = @('api'); Priority = 1 }
        )
        $result = Get-PRLabels -ChangedFiles @('src/api/handler.ps1') -Rules $rules
        $result[0] | Should -Be 'api'
        $result[1] | Should -Be 'powershell'
    }

    It 'treats missing Priority as a high numeric value (lowest importance)' {
        $rules = @(
            @{ Pattern = '**/*'; Labels = @('generic') },
            @{ Pattern = 'security/**'; Labels = @('security'); Priority = 1 }
        )
        $result = Get-PRLabels -ChangedFiles @('security/key.ps1') -Rules $rules
        $result[0] | Should -Be 'security'
    }

    It 'sorts equal priorities alphabetically for determinism' {
        $rules = @(
            @{ Pattern = '**/*'; Labels = @('zulu'); Priority = 1 },
            @{ Pattern = '**/*'; Labels = @('alpha'); Priority = 1 }
        )
        $result = Get-PRLabels -ChangedFiles @('x.txt') -Rules $rules
        $result[0] | Should -Be 'alpha'
        $result[1] | Should -Be 'zulu'
    }

    It 'uses the highest priority (lowest number) when the same label comes from multiple rules' {
        # The label keeps the best priority among the rules that produced it
        # so equal-label dedup does not mask priority ordering.
        $rules = @(
            @{ Pattern = '**/*'; Labels = @('shared'); Priority = 50 },
            @{ Pattern = 'src/**'; Labels = @('shared'); Priority = 1 },
            @{ Pattern = '**/*'; Labels = @('other'); Priority = 25 }
        )
        $result = Get-PRLabels -ChangedFiles @('src/a.ps1') -Rules $rules
        $result[0] | Should -Be 'shared'
        $result[1] | Should -Be 'other'
    }
}

Describe 'Get-PRLabels - config file loading' {
    BeforeEach {
        $script:ConfigPath = Join-Path $TestDrive 'rules.json'
    }

    It 'loads rules from a JSON config file' {
        $json = @'
{
  "rules": [
    { "pattern": "docs/**", "labels": ["documentation"], "priority": 5 },
    { "pattern": "src/api/**", "labels": ["api", "backend"], "priority": 1 }
  ]
}
'@
        Set-Content -Path $script:ConfigPath -Value $json
        $rules = Get-LabelRules -Path $script:ConfigPath
        $rules.Count | Should -Be 2
        $rules[0].Pattern | Should -Be 'docs/**'
        $rules[0].Labels | Should -Contain 'documentation'
        $rules[1].Priority | Should -Be 1
    }

    It 'throws a meaningful error when the config file does not exist' {
        { Get-LabelRules -Path (Join-Path $TestDrive 'missing.json') } |
            Should -Throw '*not found*'
    }

    It 'throws a meaningful error for malformed JSON' {
        Set-Content -Path $script:ConfigPath -Value '{ this is not json'
        { Get-LabelRules -Path $script:ConfigPath } | Should -Throw '*JSON*'
    }

    It 'throws when a rule is missing a pattern' {
        $bad = '{ "rules": [ { "labels": ["x"] } ] }'
        Set-Content -Path $script:ConfigPath -Value $bad
        { Get-LabelRules -Path $script:ConfigPath } | Should -Throw '*pattern*'
    }

    It 'throws when a rule has no labels' {
        $bad = '{ "rules": [ { "pattern": "**/*", "labels": [] } ] }'
        Set-Content -Path $script:ConfigPath -Value $bad
        { Get-LabelRules -Path $script:ConfigPath } | Should -Throw '*labels*'
    }
}

Describe 'Invoke-PRLabelAssigner - end-to-end CLI entry point' {
    It 'prints one label per line on stdout sorted by priority' {
        $rulesPath = Join-Path $TestDrive 'rules.json'
        $filesPath = Join-Path $TestDrive 'files.txt'
        Set-Content -Path $rulesPath -Value (@'
{
  "rules": [
    { "pattern": "docs/**", "labels": ["documentation"], "priority": 5 },
    { "pattern": "src/api/**", "labels": ["api"], "priority": 1 },
    { "pattern": "**/*.test.*", "labels": ["tests"], "priority": 2 }
  ]
}
'@)
        Set-Content -Path $filesPath -Value @(
            'docs/readme.md',
            'src/api/users.ps1',
            'src/api/users.test.ps1'
        )

        $out = Invoke-PRLabelAssigner -RulesPath $rulesPath -FilesPath $filesPath
        $out[0] | Should -Be 'api'
        $out[1] | Should -Be 'tests'
        $out[2] | Should -Be 'documentation'
    }

    It 'exits with meaningful error when file list path is missing' {
        $rulesPath = Join-Path $TestDrive 'rules.json'
        Set-Content -Path $rulesPath -Value '{ "rules": [ { "pattern": "**/*", "labels": ["x"] } ] }'
        { Invoke-PRLabelAssigner -RulesPath $rulesPath -FilesPath (Join-Path $TestDrive 'no.txt') } |
            Should -Throw '*not found*'
    }
}
