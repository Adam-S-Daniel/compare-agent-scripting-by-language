# Pester tests for the PR Label Assigner script.
#
# These tests were written red/green/refactor:
#   1. Each Describe-block below corresponds to a TDD cycle; the simplest
#      failing test was written first, then the minimum code in
#      src/Get-PRLabels.ps1 was added to make it green, then the next
#      requirement was layered on top.
#   2. The implementation file is dot-sourced so every exported function is
#      reachable as a top-level command in the test scope.

BeforeAll {
    $script:RepoRoot   = Split-Path -Parent $PSScriptRoot
    $script:ScriptPath = Join-Path $script:RepoRoot 'src/Get-PRLabels.ps1'
    . $script:ScriptPath
}

Describe 'ConvertTo-GlobRegex (internal helper)' {
    # Cycle 1: a glob -> regex translator is the foundation. Without it the
    # higher-level tests cannot pass, so it is exercised directly.

    It 'translates "*" so it does not cross path separators' {
        $rx = ConvertTo-GlobRegex -Pattern '*.md'
        'README.md'        | Should -Match $rx
        'docs/README.md'   | Should -Not -Match $rx
    }

    It 'translates "**" so it crosses path separators' {
        $rx = ConvertTo-GlobRegex -Pattern 'docs/**'
        'docs/intro.md'              | Should -Match $rx
        'docs/guide/advanced/x.md'   | Should -Match $rx
        'src/intro.md'               | Should -Not -Match $rx
    }

    It 'escapes regex metacharacters that are not glob wildcards' {
        $rx = ConvertTo-GlobRegex -Pattern 'a.b+c'
        'a.b+c' | Should -Match $rx
        'aXbYc' | Should -Not -Match $rx
    }

    It 'translates "?" to a single non-separator character' {
        $rx = ConvertTo-GlobRegex -Pattern 'v?.txt'
        'v1.txt' | Should -Match $rx
        'v12.txt' | Should -Not -Match $rx
        'v/.txt' | Should -Not -Match $rx
    }
}

Describe 'Get-PRLabels - basic matching' {
    It 'returns no labels when no files are supplied' {
        $rules = @(
            [pscustomobject]@{ Pattern = 'docs/**'; Label = 'documentation' }
        )
        $result = Get-PRLabels -ChangedFiles @() -Rules $rules
        $result | Should -BeNullOrEmpty
    }

    It 'returns a single label when one rule matches one file' {
        $rules = @(
            [pscustomobject]@{ Pattern = 'docs/**'; Label = 'documentation' }
        )
        $result = Get-PRLabels -ChangedFiles @('docs/intro.md') -Rules $rules
        $result | Should -Be @('documentation')
    }

    It 'returns no labels when no rule matches any file' {
        $rules = @(
            [pscustomobject]@{ Pattern = 'docs/**'; Label = 'documentation' }
        )
        $result = Get-PRLabels -ChangedFiles @('src/main.ps1') -Rules $rules
        $result | Should -BeNullOrEmpty
    }

    It 'deduplicates a label that is produced by many files' {
        $rules = @(
            [pscustomobject]@{ Pattern = 'docs/**'; Label = 'documentation' }
        )
        $result = Get-PRLabels `
            -ChangedFiles @('docs/a.md', 'docs/b.md', 'docs/c.md') `
            -Rules $rules
        $result | Should -Be @('documentation')
    }
}

Describe 'Get-PRLabels - multi-rule, multi-label' {
    It 'applies multiple labels when multiple rules match a single file' {
        $rules = @(
            [pscustomobject]@{ Pattern = 'src/api/**'; Label = 'api' }
            [pscustomobject]@{ Pattern = '**/*.ps1';   Label = 'powershell' }
        )
        $result = Get-PRLabels `
            -ChangedFiles @('src/api/Endpoints.ps1') `
            -Rules $rules
        # Order is the canonical (priority-then-label) ordering produced by
        # Get-PRLabels, not the order of input rules.
        ($result | Sort-Object) | Should -Be @('api', 'powershell')
    }

    It 'matches "*.test.*" anywhere in the path' {
        $rules = @(
            [pscustomobject]@{ Pattern = '**/*.test.*'; Label = 'tests' }
        )
        $result = Get-PRLabels `
            -ChangedFiles @('app.test.js', 'src/foo.test.ts', 'src/index.ts') `
            -Rules $rules
        $result | Should -Be @('tests')
    }

    It 'aggregates labels across many files' {
        $rules = @(
            [pscustomobject]@{ Pattern = 'docs/**';    Label = 'documentation' }
            [pscustomobject]@{ Pattern = 'src/api/**'; Label = 'api' }
            [pscustomobject]@{ Pattern = '**/*.test.*'; Label = 'tests' }
        )
        $result = Get-PRLabels `
            -ChangedFiles @(
                'docs/intro.md',
                'src/api/login.ps1',
                'src/login.test.ps1'
            ) `
            -Rules $rules
        ($result | Sort-Object) | Should -Be @('api', 'documentation', 'tests')
    }
}

Describe 'Get-PRLabels - priority ordering' {
    It 'orders labels by descending priority, then alphabetically' {
        $rules = @(
            [pscustomobject]@{ Pattern = '**/*.ps1';   Label = 'powershell'; Priority = 1 }
            [pscustomobject]@{ Pattern = 'src/api/**'; Label = 'api';        Priority = 10 }
            [pscustomobject]@{ Pattern = 'docs/**';    Label = 'documentation'; Priority = 5 }
        )
        $result = Get-PRLabels `
            -ChangedFiles @('src/api/Login.ps1', 'docs/readme.md') `
            -Rules $rules
        $result | Should -Be @('api', 'documentation', 'powershell')
    }

    It 'within a Group, keeps only the highest-priority matching rule' {
        # Conflict resolution: two rules in the same Group fire on the same
        # file; the one with the larger Priority wins.
        $rules = @(
            [pscustomobject]@{ Pattern = 'src/**';      Label = 'area:src';      Priority = 1; Group = 'area' }
            [pscustomobject]@{ Pattern = 'src/api/**';  Label = 'area:api';      Priority = 10; Group = 'area' }
        )
        $result = Get-PRLabels `
            -ChangedFiles @('src/api/login.ps1') `
            -Rules $rules
        $result | Should -Be @('area:api')
    }

    It 'keeps both labels when conflicting rules are in different groups' {
        $rules = @(
            [pscustomobject]@{ Pattern = 'src/**';     Label = 'area:src'; Priority = 1; Group = 'area' }
            [pscustomobject]@{ Pattern = 'src/api/**'; Label = 'kind:api'; Priority = 10; Group = 'kind' }
        )
        $result = Get-PRLabels `
            -ChangedFiles @('src/api/login.ps1') `
            -Rules $rules
        ($result | Sort-Object) | Should -Be @('area:src', 'kind:api')
    }
}

Describe 'Get-PRLabels - error handling' {
    It 'throws a meaningful error when a rule is missing Pattern' {
        $rules = @( [pscustomobject]@{ Label = 'oops' } )
        { Get-PRLabels -ChangedFiles @('a') -Rules $rules } |
            Should -Throw -ExpectedMessage '*Pattern*'
    }

    It 'throws a meaningful error when a rule is missing Label' {
        $rules = @( [pscustomobject]@{ Pattern = '**/*' } )
        { Get-PRLabels -ChangedFiles @('a') -Rules $rules } |
            Should -Throw -ExpectedMessage '*Label*'
    }
}

Describe 'Invoke-PRLabelAssignerFromJson (file-driven entry point)' {
    # Cycle 8: the script must be invocable from CI with two JSON files
    # (changed-files.json and rules.json). This wraps the core function and
    # is what the workflow ultimately calls.

    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("prlbl_" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:TempDir | Out-Null
    }

    AfterAll {
        if (Test-Path $script:TempDir) {
            Remove-Item -Recurse -Force $script:TempDir
        }
    }

    It 'reads JSON inputs, applies rules, and emits one label per line' {
        $filesPath = Join-Path $script:TempDir 'files.json'
        $rulesPath = Join-Path $script:TempDir 'rules.json'

        @('docs/intro.md', 'src/api/login.ps1') |
            ConvertTo-Json -Compress -AsArray |
            Set-Content -LiteralPath $filesPath -Encoding utf8

        @(
            @{ Pattern = 'docs/**';    Label = 'documentation'; Priority = 5 }
            @{ Pattern = 'src/api/**'; Label = 'api';           Priority = 10 }
        ) | ConvertTo-Json -Depth 4 -AsArray |
            Set-Content -LiteralPath $rulesPath -Encoding utf8

        $out = Invoke-PRLabelAssignerFromJson `
            -ChangedFilesJsonPath $filesPath `
            -RulesJsonPath $rulesPath
        $out | Should -Be @('api', 'documentation')
    }

    It 'gives a meaningful error when the changed-files JSON is missing' {
        $rulesPath = Join-Path $script:TempDir 'rules2.json'
        '[]' | Set-Content -LiteralPath $rulesPath -Encoding utf8

        { Invoke-PRLabelAssignerFromJson `
            -ChangedFilesJsonPath (Join-Path $script:TempDir 'does-not-exist.json') `
            -RulesJsonPath $rulesPath } |
            Should -Throw -ExpectedMessage '*does-not-exist.json*'
    }
}
