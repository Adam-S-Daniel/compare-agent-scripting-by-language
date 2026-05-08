# Pester tests for the PR label assigner.
# Drives the script via Get-PrLabels (dot-sourced from PrLabelAssigner.ps1).

BeforeAll {
    . $PSScriptRoot/PrLabelAssigner.ps1
}

Describe 'Convert-GlobToRegex' {
    It 'matches docs/** against any nested path under docs' {
        $rx = Convert-GlobToRegex 'docs/**'
        'docs/readme.md'        | Should -Match $rx
        'docs/api/v1/intro.md'  | Should -Match $rx
        'src/docs/readme.md'    | Should -Not -Match $rx
    }

    It 'matches *.test.* against test files only' {
        $rx = Convert-GlobToRegex '*.test.*'
        'foo.test.js'   | Should -Match $rx
        'a/b/c.test.ts' | Should -Match $rx
        'foo.js'        | Should -Not -Match $rx
    }

    It 'treats single * as a non-slash wildcard' {
        $rx = Convert-GlobToRegex 'src/*.cs'
        'src/Foo.cs'        | Should -Match $rx
        'src/sub/Foo.cs'    | Should -Not -Match $rx
    }
}

Describe 'Get-PrLabels' {
    It 'returns labels matching a single rule' {
        $rules = @(
            @{ pattern = 'docs/**'; label = 'documentation'; priority = 10 }
        )
        $files = @('docs/readme.md', 'src/main.ps1')
        (Get-PrLabels -Files $files -Rules $rules) | Should -Be @('documentation')
    }

    It 'merges multiple labels across multiple files' {
        $rules = @(
            @{ pattern = 'docs/**';      label = 'documentation'; priority = 5 }
            @{ pattern = 'src/api/**';   label = 'api';           priority = 10 }
            @{ pattern = '*.test.*';     label = 'tests';         priority = 1 }
        )
        $files = @('docs/x.md', 'src/api/users.ps1', 'src/api/users.test.ps1')
        $got = Get-PrLabels -Files $files -Rules $rules
        # Sorted by priority descending (higher = more important first)
        $got | Should -Be @('api', 'documentation', 'tests')
    }

    It 'deduplicates labels when multiple files match the same rule' {
        $rules = @(
            @{ pattern = 'docs/**'; label = 'documentation'; priority = 1 }
        )
        $files = @('docs/a.md', 'docs/b.md', 'docs/c/d.md')
        (Get-PrLabels -Files $files -Rules $rules) | Should -Be @('documentation')
    }

    It 'allows multiple labels for a single file' {
        $rules = @(
            @{ pattern = 'src/api/**'; label = 'api';   priority = 10 }
            @{ pattern = '**/*.ps1';   label = 'powershell'; priority = 5 }
        )
        $files = @('src/api/users.ps1')
        (Get-PrLabels -Files $files -Rules $rules) | Should -Be @('api','powershell')
    }

    It 'returns an empty array when no rule matches' {
        $rules = @( @{ pattern = 'docs/**'; label = 'documentation'; priority = 1 } )
        ,(Get-PrLabels -Files @('src/main.ps1') -Rules $rules) | Should -BeOfType [System.Array]
        (Get-PrLabels -Files @('src/main.ps1') -Rules $rules).Count | Should -Be 0
    }

    It 'breaks priority ties alphabetically' {
        $rules = @(
            @{ pattern = 'a/**'; label = 'zebra'; priority = 1 }
            @{ pattern = 'b/**'; label = 'apple'; priority = 1 }
        )
        $files = @('a/x', 'b/y')
        (Get-PrLabels -Files $files -Rules $rules) | Should -Be @('apple','zebra')
    }
}

Describe 'Invoke-PrLabelAssigner (file-driven entry point)' {
    BeforeAll {
        $script:tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("prlabel-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Force -Path $script:tmp | Out-Null
    }
    AfterAll {
        Remove-Item -Recurse -Force $script:tmp -ErrorAction SilentlyContinue
    }

    It 'reads files+rules from JSON and emits a JSON label array' {
        $rulesPath = Join-Path $script:tmp 'rules.json'
        $filesPath = Join-Path $script:tmp 'files.json'
        @{
            rules = @(
                @{ pattern='docs/**';    label='documentation'; priority=5  }
                @{ pattern='src/api/**'; label='api';           priority=10 }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content $rulesPath
        @('docs/readme.md','src/api/x.ps1') | ConvertTo-Json | Set-Content $filesPath

        $out = Invoke-PrLabelAssigner -FilesPath $filesPath -RulesPath $rulesPath
        $parsed = $out | ConvertFrom-Json
        @($parsed) | Should -Be @('api','documentation')
    }

    It 'errors clearly when the rules file is missing' {
        { Invoke-PrLabelAssigner -FilesPath 'nope' -RulesPath 'also-nope' } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}
