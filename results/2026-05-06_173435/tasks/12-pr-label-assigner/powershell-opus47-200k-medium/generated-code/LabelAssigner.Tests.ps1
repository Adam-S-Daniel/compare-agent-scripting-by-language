#Requires -Module Pester

# Pester tests for LabelAssigner. Written TDD-first; each Describe/Context block
# corresponds to a red/green cycle that grew the module.

BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    Import-Module (Join-Path $here 'LabelAssigner.psm1') -Force
}

Describe 'Convert-GlobToRegex' {
    It 'turns a literal segment into an anchored regex' {
        Convert-GlobToRegex 'README.md' | Should -Be '^README\.md$'
    }

    It 'expands * to any chars except slash' {
        Convert-GlobToRegex '*.md' | Should -Be '^[^/]*\.md$'
    }

    It 'expands ** to any chars including slashes' {
        Convert-GlobToRegex 'docs/**' | Should -Be '^docs/.*$'
    }

    It 'expands ? to a single non-slash char' {
        Convert-GlobToRegex 'a?b' | Should -Be '^a[^/]b$'
    }
}

Describe 'Test-GlobMatch' {
    It 'matches docs/** for nested doc files' {
        Test-GlobMatch -Path 'docs/guide/intro.md' -Pattern 'docs/**' | Should -BeTrue
    }

    It 'does not match docs/** for top-level non-doc files' {
        Test-GlobMatch -Path 'README.md' -Pattern 'docs/**' | Should -BeFalse
    }

    It 'matches *.test.* in any directory using **/' {
        Test-GlobMatch -Path 'src/api/users.test.js' -Pattern '**/*.test.*' | Should -BeTrue
    }

    It 'matches src/api/** specifically' {
        Test-GlobMatch -Path 'src/api/users.ps1' -Pattern 'src/api/**' | Should -BeTrue
        Test-GlobMatch -Path 'src/web/users.ps1' -Pattern 'src/api/**' | Should -BeFalse
    }
}

Describe 'Get-LabelsForFiles' {
    It 'returns the label for a single matching file' {
        $rules = @(@{ pattern = 'docs/**'; labels = @('documentation'); priority = 10 })
        Get-LabelsForFiles -Files @('docs/intro.md') -Rules $rules | Should -Be @('documentation')
    }

    It 'returns no labels when no rule matches' {
        $rules = @(@{ pattern = 'docs/**'; labels = @('documentation'); priority = 10 })
        $result = Get-LabelsForFiles -Files @('src/main.ps1') -Rules $rules
        @($result).Count | Should -Be 0
    }

    It 'deduplicates labels across files' {
        $rules = @(@{ pattern = 'docs/**'; labels = @('documentation'); priority = 10 })
        $result = Get-LabelsForFiles -Files @('docs/a.md','docs/b.md') -Rules $rules
        @($result).Count | Should -Be 1
        $result | Should -Contain 'documentation'
    }

    It 'supports multiple labels per rule' {
        $rules = @(@{ pattern = 'src/api/**'; labels = @('api','backend'); priority = 5 })
        $result = Get-LabelsForFiles -Files @('src/api/users.ps1') -Rules $rules
        $result | Should -Contain 'api'
        $result | Should -Contain 'backend'
    }

    It 'applies multiple rules to the same file' {
        $rules = @(
            @{ pattern = 'src/api/**'; labels = @('api'); priority = 5 }
            @{ pattern = '**/*.test.*'; labels = @('tests'); priority = 1 }
        )
        $result = Get-LabelsForFiles -Files @('src/api/users.test.ps1') -Rules $rules
        $result | Should -Contain 'api'
        $result | Should -Contain 'tests'
    }

    It 'orders labels by priority descending' {
        $rules = @(
            @{ pattern = '**/*.test.*'; labels = @('tests'); priority = 1 }
            @{ pattern = 'src/api/**'; labels = @('api'); priority = 5 }
            @{ pattern = 'docs/**'; labels = @('documentation'); priority = 10 }
        )
        $result = Get-LabelsForFiles `
            -Files @('docs/x.md','src/api/y.ps1','src/api/z.test.ps1') `
            -Rules $rules
        # documentation (10) > api (5) > tests (1)
        $result[0] | Should -Be 'documentation'
        $result[1] | Should -Be 'api'
        $result[2] | Should -Be 'tests'
    }
}

Describe 'Invoke-LabelAssigner end-to-end' {
    BeforeAll {
        $script:here = Split-Path -Parent $PSCommandPath
        $script:cli  = Join-Path $script:here 'Invoke-LabelAssigner.ps1'
        $script:tmp  = Join-Path ([System.IO.Path]::GetTempPath()) "lblasg-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:tmp | Out-Null
    }

    AfterAll {
        if (Test-Path $script:tmp) { Remove-Item -Recurse -Force $script:tmp }
    }

    It 'reads files + rules from disk and prints labels in priority order' {
        $rules = @{
            rules = @(
                @{ pattern = 'docs/**';     labels = @('documentation'); priority = 10 }
                @{ pattern = 'src/api/**';  labels = @('api');           priority = 5 }
                @{ pattern = '**/*.test.*'; labels = @('tests');         priority = 1 }
            )
        }
        $rulesPath = Join-Path $script:tmp 'rules.json'
        $rules | ConvertTo-Json -Depth 5 | Set-Content -Path $rulesPath -Encoding utf8

        $filesPath = Join-Path $script:tmp 'files.txt'
        @('docs/x.md','src/api/y.ps1','src/api/z.test.ps1') | Set-Content -Path $filesPath

        $output = & pwsh -NoProfile -File $script:cli -RulesFile $rulesPath -FilesFile $filesPath
        $LASTEXITCODE | Should -Be 0
        $labelsLine = ($output | Where-Object { $_ -like 'LABELS=*' })
        $labelsLine | Should -Be 'LABELS=documentation,api,tests'
    }

    It 'fails gracefully when rules file is missing' {
        $missing = Join-Path $script:tmp 'nope.json'
        $filesPath = Join-Path $script:tmp 'files.txt'
        'README.md' | Set-Content -Path $filesPath
        $null = & pwsh -NoProfile -File $script:cli -RulesFile $missing -FilesFile $filesPath 2>&1
        $LASTEXITCODE | Should -Not -Be 0
    }
}
