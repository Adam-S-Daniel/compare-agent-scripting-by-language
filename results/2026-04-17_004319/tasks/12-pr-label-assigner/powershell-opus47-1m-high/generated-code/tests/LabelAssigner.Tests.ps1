# Pester tests for the PR Label Assigner module.
# Tests are written red/green: each Describe block introduces new behavior,
# and the module code is added incrementally to make each test pass.

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'src' 'LabelAssigner.psm1'
    Import-Module $modulePath -Force
}

Describe 'ConvertTo-GlobRegex' {
    # The module converts glob patterns into anchored regexes. Tests lock in
    # wildcard semantics: `**` crosses path separators, `*` does not, `?` is
    # a single non-separator character, dots are literal.

    It 'converts a literal path into an anchored regex match' {
        $rx = ConvertTo-GlobRegex 'README.md'
        'README.md' -match $rx | Should -BeTrue
        'readme-md' -match $rx | Should -BeFalse
    }

    It 'treats ** as matching across directory separators' {
        $rx = ConvertTo-GlobRegex 'docs/**'
        'docs/guide.md' -match $rx | Should -BeTrue
        'docs/a/b/c.md' -match $rx | Should -BeTrue
        'src/docs/x.md' -match $rx | Should -BeFalse
    }

    It 'treats single * as a single-segment wildcard' {
        $rx = ConvertTo-GlobRegex 'src/*.ps1'
        'src/foo.ps1' -match $rx | Should -BeTrue
        'src/sub/foo.ps1' -match $rx | Should -BeFalse
    }

    It 'treats ? as a single non-separator character' {
        $rx = ConvertTo-GlobRegex 'file?.txt'
        'fileA.txt' -match $rx | Should -BeTrue
        'file.txt'  -match $rx | Should -BeFalse
        'fileAB.txt' -match $rx | Should -BeFalse
    }

    It 'escapes regex metacharacters embedded in the pattern' {
        $rx = ConvertTo-GlobRegex 'a.b+c/file.txt'
        'a.b+c/file.txt' -match $rx | Should -BeTrue
        'axbxc/file.txt' -match $rx | Should -BeFalse
    }
}

Describe 'Test-PathGlobMatch' {

    It 'returns true when the path matches the glob' {
        Test-PathGlobMatch -Path 'docs/intro.md' -Pattern 'docs/**' | Should -BeTrue
    }

    It 'returns false when the path does not match' {
        Test-PathGlobMatch -Path 'src/app.ps1' -Pattern 'docs/**' | Should -BeFalse
    }

    It 'handles leading-wildcard suffix matches like **/*.md' {
        Test-PathGlobMatch -Path 'src/inner/notes.md' -Pattern '**/*.md' | Should -BeTrue
        Test-PathGlobMatch -Path 'src/inner/notes.ps1' -Pattern '**/*.md' | Should -BeFalse
    }

    It 'treats **/ as zero-or-more leading segments (matches root-level files)' {
        # Regression: a pattern like **/*.test.* must match README.test.ps1
        # even though README.test.ps1 has no leading directory segment.
        Test-PathGlobMatch -Path 'README.test.ps1' -Pattern '**/*.test.*' | Should -BeTrue
        Test-PathGlobMatch -Path 'README.md'      -Pattern '**/*.md'      | Should -BeTrue
    }
}

Describe 'Import-LabelRules' {

    It 'loads a JSON rules file into a rule array' {
        $tmp = New-TemporaryFile
        try {
            @(
                @{ pattern = 'docs/**'; labels = @('documentation'); priority = 5 },
                @{ pattern = '**/*.test.*'; labels = @('tests'); priority = 10 }
            ) | ConvertTo-Json -Depth 4 | Set-Content -Path $tmp.FullName
            $rules = Import-LabelRules -Path $tmp.FullName
            $rules.Count | Should -Be 2
            $rules[0].pattern | Should -Be 'docs/**'
            $rules[0].labels | Should -Contain 'documentation'
            $rules[1].priority | Should -Be 10
        } finally {
            Remove-Item $tmp.FullName -ErrorAction SilentlyContinue
        }
    }

    It 'applies default priority 0 when missing' {
        $tmp = New-TemporaryFile
        try {
            '[{"pattern":"*.md","labels":["documentation"]}]' | Set-Content -Path $tmp.FullName
            $rules = Import-LabelRules -Path $tmp.FullName
            $rules[0].priority | Should -Be 0
        } finally {
            Remove-Item $tmp.FullName -ErrorAction SilentlyContinue
        }
    }

    It 'throws a helpful error when the file is missing' {
        { Import-LabelRules -Path '/does/not/exist.json' } |
            Should -Throw '*not found*'
    }

    It 'throws when a rule is missing required fields' {
        $tmp = New-TemporaryFile
        try {
            '[{"labels":["documentation"]}]' | Set-Content -Path $tmp.FullName
            { Import-LabelRules -Path $tmp.FullName } | Should -Throw '*pattern*'
        } finally {
            Remove-Item $tmp.FullName -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Get-PullRequestLabels' {
    # Core orchestration: given a list of changed paths and a rule set, what
    # label set results? Rules are applied highest-priority first; every
    # matching rule contributes its labels. Rules sharing a `group` are
    # mutually exclusive — only the highest-priority match in a group wins.

    BeforeAll {
        $script:rules = @(
            [pscustomobject]@{ pattern = 'docs/**';       labels = @('documentation'); priority = 5;  group = $null }
            [pscustomobject]@{ pattern = 'src/api/**';    labels = @('api','backend');  priority = 8;  group = $null }
            [pscustomobject]@{ pattern = '**/*.test.*';   labels = @('tests');          priority = 10; group = $null }
            [pscustomobject]@{ pattern = '**/*.md';       labels = @('documentation'); priority = 1;  group = $null }
        )
    }

    It 'returns an empty set when no paths are provided' {
        Get-PullRequestLabels -Paths @() -Rules $script:rules | Should -BeNullOrEmpty
    }

    It 'aggregates labels from all matching rules, deduplicated' {
        $labels = Get-PullRequestLabels -Paths @('docs/intro.md') -Rules $script:rules
        ,$labels | Should -BeOfType ([object[]])
        $labels | Should -Contain 'documentation'
        ($labels | Measure-Object).Count | Should -Be 1
    }

    It 'applies multiple labels per file when a single rule has multiple labels' {
        $labels = Get-PullRequestLabels -Paths @('src/api/users.ps1') -Rules $script:rules
        $labels | Should -Contain 'api'
        $labels | Should -Contain 'backend'
    }

    It 'orders output by rule priority (highest first) then by first occurrence' {
        $labels = Get-PullRequestLabels -Paths @('src/api/a.test.ps1') -Rules $script:rules
        # tests (prio 10) should come before api/backend (prio 8)
        $labels[0] | Should -Be 'tests'
    }

    It 'resolves group conflicts by keeping only the highest-priority match' {
        $grouped = @(
            [pscustomobject]@{ pattern = 'src/**';     labels = @('size/small');  priority = 1; group = 'size' }
            [pscustomobject]@{ pattern = 'src/api/**'; labels = @('size/large');  priority = 5; group = 'size' }
        )
        $labels = Get-PullRequestLabels -Paths @('src/api/users.ps1') -Rules $grouped
        $labels | Should -Contain 'size/large'
        $labels | Should -Not -Contain 'size/small'
    }

    It 'handles multiple changed paths and merges their label sets' {
        $paths = @('docs/intro.md', 'src/api/users.ps1', 'README.md')
        $labels = Get-PullRequestLabels -Paths $paths -Rules $script:rules
        $labels | Should -Contain 'documentation'
        $labels | Should -Contain 'api'
        $labels | Should -Contain 'backend'
    }

    It 'emits deterministic, deduplicated output for repeated paths' {
        $labels = Get-PullRequestLabels -Paths @('docs/a.md','docs/a.md') -Rules $script:rules
        ($labels | Measure-Object).Count | Should -Be 1
    }
}

Describe 'CLI entrypoint assign-labels.ps1' {
    # The CLI wraps the module, reads rules from a file, reads a changed-files
    # list (from a parameter or JSON file), and prints labels one-per-line.

    BeforeAll {
        $script:cli    = Join-Path $PSScriptRoot '..' 'scripts' 'assign-labels.ps1'
        $script:rulesP = Join-Path $PSScriptRoot 'fixtures' 'sample-rules.json'
    }

    It 'exists as an executable script' {
        Test-Path $script:cli | Should -BeTrue
    }

    It 'prints one label per line for a given changed-files list file' {
        $filesList = Join-Path ([IO.Path]::GetTempPath()) ("files-$([guid]::NewGuid()).json")
        @('docs/intro.md','src/api/users.ps1','README.test.ps1') |
            ConvertTo-Json | Set-Content -Path $filesList
        try {
            $out = pwsh -NoLogo -NoProfile -File $script:cli `
                -RulesPath $script:rulesP -ChangedFilesPath $filesList 2>&1
            $labels = $out -split "`n" | Where-Object { $_ -ne '' }
            $labels | Should -Contain 'documentation'
            $labels | Should -Contain 'api'
            $labels | Should -Contain 'backend'
            $labels | Should -Contain 'tests'
        } finally {
            Remove-Item $filesList -ErrorAction SilentlyContinue
        }
    }

    It 'exits non-zero when the rules file cannot be found' {
        $bogus = '/tmp/does-not-exist-' + [guid]::NewGuid()
        $null = pwsh -NoLogo -NoProfile -File $script:cli `
            -RulesPath $bogus -ChangedFiles 'a.md' 2>&1
        $LASTEXITCODE | Should -Not -Be 0
    }
}
