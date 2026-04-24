# Pester tests for the PR label assigner.
# Uses TDD: each Describe block exercises one piece of behaviour.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'src' 'LabelAssigner.psm1'
    Import-Module $script:ModulePath -Force
}

Describe 'ConvertTo-LabelRegex (glob to regex)' {
    It 'converts a simple * to match filename segments' {
        ConvertTo-LabelRegex -Pattern '*.md' | Should -Be '^[^/]*\.md$'
    }

    It 'converts ** to match across directory separators' {
        ConvertTo-LabelRegex -Pattern 'docs/**' | Should -Be '^docs/.*$'
    }

    It 'escapes regex metacharacters in the literal parts' {
        ConvertTo-LabelRegex -Pattern 'a+b.txt' | Should -Be '^a\+b\.txt$'
    }

    It 'handles ? as a single non-slash character' {
        ConvertTo-LabelRegex -Pattern 'file?.js' | Should -Be '^file[^/]\.js$'
    }
}

Describe 'Test-LabelGlob' {
    It 'matches files under docs/**' {
        Test-LabelGlob -Path 'docs/readme.md' -Pattern 'docs/**' | Should -BeTrue
    }

    It 'does not match files outside the prefix' {
        Test-LabelGlob -Path 'src/app.js' -Pattern 'docs/**' | Should -BeFalse
    }

    It 'matches test files with *.test.*' {
        Test-LabelGlob -Path 'foo.test.js' -Pattern '*.test.*' | Should -BeTrue
    }

    It 'matches nested test files with **/*.test.*' {
        Test-LabelGlob -Path 'src/a/b.test.ts' -Pattern '**/*.test.*' | Should -BeTrue
    }
}

Describe 'Get-FileLabels' {
    BeforeAll {
        $script:Rules = @(
            [pscustomobject]@{ pattern = 'docs/**';    labels = @('documentation'); priority = 10 }
            [pscustomobject]@{ pattern = 'src/api/**'; labels = @('api','backend');   priority = 20 }
            [pscustomobject]@{ pattern = '**/*.test.*'; labels = @('tests');          priority = 30 }
        )
    }

    It 'returns documentation for a docs file' {
        $result = Get-FileLabels -Files @('docs/intro.md') -Rules $script:Rules
        $result | Should -Be @('documentation')
    }

    It 'returns multiple labels from a single rule' {
        $result = Get-FileLabels -Files @('src/api/users.ps1') -Rules $script:Rules
        $result | Sort-Object | Should -Be @('api','backend')
    }

    It 'unions labels across multiple files' {
        $files = @('docs/intro.md','src/api/a.ps1','x.test.js')
        $result = Get-FileLabels -Files $files -Rules $script:Rules
        $result | Sort-Object | Should -Be @('api','backend','documentation','tests')
    }

    It 'produces deduplicated labels' {
        $files = @('docs/a.md','docs/b.md')
        $result = Get-FileLabels -Files $files -Rules $script:Rules
        $result | Should -Be @('documentation')
    }

    It 'returns an empty array when no rules match' {
        $result = Get-FileLabels -Files @('LICENSE') -Rules $script:Rules
        ,$result | Should -BeOfType [System.Array]
        $result.Count | Should -Be 0
    }
}

Describe 'Get-FileLabels priority behaviour' {
    It 'when HighestPriorityOnly is set, only the winning rule contributes labels per file' {
        # Lower priority number = higher priority. Rule "api" (priority 1) should
        # win over "backend" (priority 5) for a src/api/ file.
        $rules = @(
            [pscustomobject]@{ pattern = 'src/api/**'; labels = @('api');     priority = 1 }
            [pscustomobject]@{ pattern = 'src/**';     labels = @('backend'); priority = 5 }
        )
        $result = Get-FileLabels -Files @('src/api/users.ps1') -Rules $rules -HighestPriorityOnly
        $result | Should -Be @('api')
    }

    It 'without HighestPriorityOnly, both matching rules contribute' {
        $rules = @(
            [pscustomobject]@{ pattern = 'src/api/**'; labels = @('api');     priority = 1 }
            [pscustomobject]@{ pattern = 'src/**';     labels = @('backend'); priority = 5 }
        )
        $result = Get-FileLabels -Files @('src/api/users.ps1') -Rules $rules
        $result | Sort-Object | Should -Be @('api','backend')
    }
}

Describe 'Invoke-LabelAssigner (CLI-style wrapper)' {
    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("labelassigner-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:TempDir | Out-Null

        $script:FilesJson = Join-Path $script:TempDir 'files.json'
        $script:RulesJson = Join-Path $script:TempDir 'rules.json'

        @('docs/readme.md','src/api/user.ps1','app.test.ps1') | ConvertTo-Json | Set-Content $script:FilesJson

        @(
            @{ pattern = 'docs/**';    labels = @('documentation'); priority = 10 }
            @{ pattern = 'src/api/**'; labels = @('api');            priority = 20 }
            @{ pattern = '**/*.test.*'; labels = @('tests');         priority = 30 }
        ) | ConvertTo-Json -Depth 5 | Set-Content $script:RulesJson
    }

    AfterAll {
        if (Test-Path $script:TempDir) {
            Remove-Item -Recurse -Force $script:TempDir
        }
    }

    It 'reads files and rules from JSON and emits labels, one per line, sorted' {
        $output = Invoke-LabelAssigner -FilesPath $script:FilesJson -RulesPath $script:RulesJson
        $output | Should -Be @('api','documentation','tests')
    }

    It 'throws a clear error when the files file is missing' {
        { Invoke-LabelAssigner -FilesPath 'does-not-exist.json' -RulesPath $script:RulesJson } |
            Should -Throw -ExpectedMessage '*does-not-exist.json*'
    }

    It 'throws a clear error when the rules file is missing' {
        { Invoke-LabelAssigner -FilesPath $script:FilesJson -RulesPath 'missing.json' } |
            Should -Throw -ExpectedMessage '*missing.json*'
    }
}
