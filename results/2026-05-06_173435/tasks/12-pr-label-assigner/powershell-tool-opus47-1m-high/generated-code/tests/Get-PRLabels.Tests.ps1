# Pester tests for Get-PRLabels.ps1
# TDD-style: each Describe block grows the implementation incrementally.

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:ScriptPath = Join-Path $RepoRoot 'Get-PRLabels.ps1'
    . $ScriptPath
}

Describe 'Get-PRLabels: basic invocation' {
    It 'returns an empty array when there are no changed files' {
        $rules = @(
            [pscustomobject]@{ Pattern = 'docs/**'; Label = 'documentation' }
        )
        $result = Get-PRLabels -ChangedFiles @() -Rules $rules
        # Wrap with `,` to keep the array intact through the pipe — otherwise
        # an empty array unrolls to nothing and Should sees $null.
        ,$result | Should -BeOfType [System.Array]
        @($result).Count | Should -Be 0
    }

    It 'matches a simple recursive glob (docs/**)' {
        $rules = @(
            [pscustomobject]@{ Pattern = 'docs/**'; Label = 'documentation' }
        )
        $result = Get-PRLabels -ChangedFiles @('docs/readme.md', 'docs/guide/intro.md') -Rules $rules
        $result | Should -Be @('documentation')
    }
}

Describe 'Get-PRLabels: multiple labels and de-duplication' {
    It 'returns each matched label exactly once even when many files match' {
        $rules = @(
            [pscustomobject]@{ Pattern = 'src/api/**'; Label = 'api' }
            [pscustomobject]@{ Pattern = 'docs/**';   Label = 'documentation' }
        )
        $files = @('src/api/users.ps1', 'src/api/orders.ps1', 'docs/api.md')
        $result = Get-PRLabels -ChangedFiles $files -Rules $rules
        ($result | Sort-Object) | Should -Be @('api', 'documentation')
    }

    It 'a single file can match multiple rules and pick up multiple labels' {
        $rules = @(
            [pscustomobject]@{ Pattern = 'src/**';     Label = 'source' }
            [pscustomobject]@{ Pattern = '*.test.*';   Label = 'tests' }
        )
        $result = Get-PRLabels -ChangedFiles @('src/lib/foo.test.ps1') -Rules $rules
        ($result | Sort-Object) | Should -Be @('source', 'tests')
    }

    It 'matches a star-only filename pattern such as *.test.*' {
        $rules = @(
            [pscustomobject]@{ Pattern = '*.test.*'; Label = 'tests' }
        )
        $result = Get-PRLabels -ChangedFiles @('foo.test.ps1', 'bar.test.js', 'baz.ps1') -Rules $rules
        $result | Should -Be @('tests')
    }
}

Describe 'Get-PRLabels: priority and conflict resolution' {
    It 'when two rules conflict on the same path, higher Priority wins' {
        # Lower Priority numbers = higher importance (1 wins over 2).
        $rules = @(
            [pscustomobject]@{ Pattern = 'src/**';        Label = 'source';   Priority = 2 }
            [pscustomobject]@{ Pattern = 'src/api/**';    Label = 'api';      Priority = 1 }
        )
        $result = Get-PRLabels -ChangedFiles @('src/api/users.ps1') -Rules $rules -ConflictResolution 'Priority'
        # In Priority mode, only the highest-priority match for each file is kept.
        $result | Should -Be @('api')
    }

    It 'in Union mode (default) all matched labels survive priority differences' {
        $rules = @(
            [pscustomobject]@{ Pattern = 'src/**';        Label = 'source';   Priority = 2 }
            [pscustomobject]@{ Pattern = 'src/api/**';    Label = 'api';      Priority = 1 }
        )
        $result = Get-PRLabels -ChangedFiles @('src/api/users.ps1') -Rules $rules
        ($result | Sort-Object) | Should -Be @('api', 'source')
    }

    It 'sorts the output deterministically' {
        $rules = @(
            [pscustomobject]@{ Pattern = '*.md';      Label = 'zeta' }
            [pscustomobject]@{ Pattern = 'tests/**';  Label = 'alpha' }
            [pscustomobject]@{ Pattern = 'src/**';    Label = 'mu' }
        )
        $files = @('README.md', 'tests/a.ps1', 'src/lib.ps1')
        $result = Get-PRLabels -ChangedFiles $files -Rules $rules
        # Expect alphabetical ordering for stable diffs.
        $result | Should -Be @('alpha', 'mu', 'zeta')
    }
}

Describe 'Get-PRLabels: glob semantics' {
    It '** matches across multiple path segments' {
        $rules = @(
            [pscustomobject]@{ Pattern = 'src/**/handlers/*.ps1'; Label = 'handler' }
        )
        $result = Get-PRLabels -ChangedFiles @('src/api/v1/handlers/get.ps1') -Rules $rules
        $result | Should -Be @('handler')
    }

    It '* does NOT match a path separator' {
        $rules = @(
            [pscustomobject]@{ Pattern = 'src/*.ps1'; Label = 'top-level-source' }
        )
        $files = @('src/foo.ps1', 'src/sub/bar.ps1')
        $result = Get-PRLabels -ChangedFiles $files -Rules $rules
        $result | Should -Be @('top-level-source')  # only src/foo.ps1 matches
    }

    It 'normalises Windows-style backslashes in changed-file paths' {
        $rules = @(
            [pscustomobject]@{ Pattern = 'docs/**'; Label = 'documentation' }
        )
        $result = Get-PRLabels -ChangedFiles @('docs\guide\intro.md') -Rules $rules
        $result | Should -Be @('documentation')
    }
}

Describe 'Get-PRLabels: config loading' {
    BeforeAll {
        $script:fixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) "prlabels-$([Guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:fixtureDir -Force | Out-Null
        $script:configPath = Join-Path $script:fixtureDir 'labels.json'
        @'
{
  "rules": [
    { "pattern": "docs/**",      "label": "documentation", "priority": 5 },
    { "pattern": "src/api/**",   "label": "api",           "priority": 1 },
    { "pattern": "*.test.*",     "label": "tests",         "priority": 3 }
  ]
}
'@ | Set-Content -Path $script:configPath
    }

    AfterAll {
        if (Test-Path $script:fixtureDir) {
            Remove-Item -Path $script:fixtureDir -Recurse -Force
        }
    }

    It 'loads rules from a JSON config file' {
        $rules = Import-LabelRules -Path $script:configPath
        @($rules).Count | Should -Be 3
        $rules[0].Pattern | Should -Be 'docs/**'
        $rules[0].Label | Should -Be 'documentation'
        $rules[0].Priority | Should -Be 5
    }

    It 'throws a meaningful error when the config file does not exist' {
        { Import-LabelRules -Path '/nonexistent/labels.json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws a meaningful error when the config file is malformed JSON' {
        $bad = Join-Path $script:fixtureDir 'bad.json'
        '{ this is not json' | Set-Content -Path $bad
        { Import-LabelRules -Path $bad } |
            Should -Throw -ExpectedMessage '*invalid*'
    }

    It 'throws when a rule is missing its pattern field' {
        $bad = Join-Path $script:fixtureDir 'missing-pattern.json'
        '{ "rules": [ { "label": "documentation" } ] }' | Set-Content -Path $bad
        { Import-LabelRules -Path $bad } |
            Should -Throw -ExpectedMessage '*pattern*'
    }
}

Describe 'Get-PRLabels: end-to-end CLI invocation' {
    BeforeAll {
        $script:fxDir = Join-Path ([System.IO.Path]::GetTempPath()) "prlabels-cli-$([Guid]::NewGuid())"
        New-Item -ItemType Directory -Path $fxDir -Force | Out-Null

        $script:configFile = Join-Path $fxDir 'labels.json'
        @'
{
  "rules": [
    { "pattern": "docs/**",       "label": "documentation", "priority": 5 },
    { "pattern": "src/api/**",    "label": "api",           "priority": 1 },
    { "pattern": "src/**",        "label": "source",        "priority": 4 },
    { "pattern": "*.test.*",      "label": "tests",         "priority": 3 }
  ]
}
'@ | Set-Content -Path $configFile

        $script:filesFile = Join-Path $fxDir 'changed-files.txt'
        @'
docs/readme.md
src/api/users.ps1
src/lib/utils.ps1
foo.test.ps1
'@ | Set-Content -Path $filesFile
    }

    AfterAll {
        if (Test-Path $script:fxDir) {
            Remove-Item -Path $script:fxDir -Recurse -Force
        }
    }

    It 'runs end-to-end with -ConfigPath and -ChangedFilesPath, prints labels one per line' {
        $output = & pwsh -NoProfile -File $script:ScriptPath `
            -ConfigPath $script:configFile `
            -ChangedFilesPath $script:filesFile

        $LASTEXITCODE | Should -Be 0
        $lines = ($output -split "`r?`n" | Where-Object { $_ -ne '' } | Sort-Object)
        $lines | Should -Be @('api', 'documentation', 'source', 'tests')
    }

    It 'supports -OutputFormat json for machine consumption' {
        $output = & pwsh -NoProfile -File $script:ScriptPath `
            -ConfigPath $script:configFile `
            -ChangedFilesPath $script:filesFile `
            -OutputFormat 'json'

        $LASTEXITCODE | Should -Be 0
        $parsed = $output | ConvertFrom-Json
        ($parsed | Sort-Object) | Should -Be @('api', 'documentation', 'source', 'tests')
    }

    It 'exits non-zero when the config file does not exist' {
        $null = & pwsh -NoProfile -File $script:ScriptPath `
            -ConfigPath '/does/not/exist.json' `
            -ChangedFilesPath $script:filesFile 2>&1
        $LASTEXITCODE | Should -Not -Be 0
    }
}
