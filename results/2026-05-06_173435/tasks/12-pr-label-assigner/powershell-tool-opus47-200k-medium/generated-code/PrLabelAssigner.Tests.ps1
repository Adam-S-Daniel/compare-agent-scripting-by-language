# Pester tests for PR Label Assigner.
# Drives the design via red/green TDD: each Describe block adds one capability.

BeforeAll {
    . "$PSScriptRoot/PrLabelAssigner.ps1"
}

Describe 'Test-GlobMatch' {
    It 'matches a literal path' {
        Test-GlobMatch -Path 'README.md' -Pattern 'README.md' | Should -BeTrue
    }

    It 'matches single-segment * wildcard' {
        Test-GlobMatch -Path 'foo.test.js' -Pattern '*.test.*' | Should -BeTrue
    }

    It '* does not cross directory boundaries' {
        Test-GlobMatch -Path 'src/api/x.js' -Pattern '*.js' | Should -BeFalse
    }

    It '** matches across directories' {
        Test-GlobMatch -Path 'docs/guides/intro.md' -Pattern 'docs/**' | Should -BeTrue
    }

    It '** matches zero directories' {
        Test-GlobMatch -Path 'docs/intro.md' -Pattern 'docs/**' | Should -BeTrue
    }

    It 'matches nested glob with extension' {
        Test-GlobMatch -Path 'src/api/users.ts' -Pattern 'src/api/**/*.ts' | Should -BeTrue
    }

    It 'returns false on mismatched extension' {
        Test-GlobMatch -Path 'docs/intro.md' -Pattern 'docs/**/*.txt' | Should -BeFalse
    }
}

Describe 'Get-AssignedLabels' {
    BeforeAll {
        $script:rules = @(
            [pscustomobject]@{ pattern = 'docs/**';        labels = @('documentation'); priority = 10 }
            [pscustomobject]@{ pattern = 'src/api/**';     labels = @('api','backend');  priority = 20 }
            [pscustomobject]@{ pattern = '*.test.*';       labels = @('tests');          priority = 30 }
            [pscustomobject]@{ pattern = '**/*.test.*';    labels = @('tests');          priority = 30 }
            [pscustomobject]@{ pattern = 'package.json';   labels = @('dependencies');   priority = 5  }
        )
    }

    It 'returns empty set when no files match' {
        Get-AssignedLabels -Files @('unmatched/file.xyz') -Rules $rules | Should -BeNullOrEmpty
    }

    It 'assigns a single label for a single matching file' {
        Get-AssignedLabels -Files @('docs/intro.md') -Rules $rules | Should -Be @('documentation')
    }

    It 'assigns multiple labels from one rule' {
        $result = Get-AssignedLabels -Files @('src/api/users.ts') -Rules $rules
        $result | Should -Contain 'api'
        $result | Should -Contain 'backend'
    }

    It 'unions labels across multiple files' {
        $result = Get-AssignedLabels -Files @('docs/a.md','src/api/b.ts') -Rules $rules
        $result | Should -Contain 'documentation'
        $result | Should -Contain 'api'
        $result | Should -Contain 'backend'
        ($result | Measure-Object).Count | Should -Be 3
    }

    It 'deduplicates when rules overlap' {
        $result = Get-AssignedLabels -Files @('src/api/foo.test.ts') -Rules $rules
        ($result | Where-Object { $_ -eq 'tests' } | Measure-Object).Count | Should -Be 1
    }

    It 'orders labels by descending rule priority then alphabetically' {
        $result = Get-AssignedLabels -Files @('docs/a.md','package.json','src/api/users.ts','x.test.js') -Rules $rules
        # Priorities: tests=30, api/backend=20, documentation=10, dependencies=5
        $result | Should -Be @('tests','api','backend','documentation','dependencies')
    }
}

Describe 'Invoke-PrLabelAssigner (CLI entrypoint)' {
    BeforeAll {
        $script:tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("plr-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:tmp | Out-Null

        $script:rulesPath = Join-Path $script:tmp 'rules.json'
        $script:filesPath = Join-Path $script:tmp 'files.txt'

        @(
            @{ pattern='docs/**';    labels=@('documentation'); priority=10 }
            @{ pattern='src/api/**'; labels=@('api');           priority=20 }
            @{ pattern='**/*.test.*'; labels=@('tests');        priority=30 }
        ) | ConvertTo-Json -Depth 5 | Set-Content -Path $script:rulesPath

        "docs/intro.md`nsrc/api/users.ts`nsrc/api/users.test.ts" | Set-Content -Path $script:filesPath
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:tmp -ErrorAction SilentlyContinue
    }

    It 'reads rules file and files list and prints labels one per line' {
        $out = Invoke-PrLabelAssigner -RulesPath $script:rulesPath -FilesPath $script:filesPath
        $out | Should -Be @('tests','api','documentation')
    }

    It 'throws a clear error when rules file is missing' {
        { Invoke-PrLabelAssigner -RulesPath '/nonexistent/rules.json' -FilesPath $script:filesPath } |
            Should -Throw -ExpectedMessage '*Rules file not found*'
    }

    It 'throws a clear error when files file is missing' {
        { Invoke-PrLabelAssigner -RulesPath $script:rulesPath -FilesPath '/nonexistent/files.txt' } |
            Should -Throw -ExpectedMessage '*Files list not found*'
    }

    It 'throws when rules JSON is malformed' {
        $bad = Join-Path $script:tmp 'bad.json'
        '{ not json' | Set-Content -Path $bad
        { Invoke-PrLabelAssigner -RulesPath $bad -FilesPath $script:filesPath } |
            Should -Throw -ExpectedMessage '*Failed to parse rules*'
    }
}
