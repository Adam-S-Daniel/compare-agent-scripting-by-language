BeforeAll {
    . "$PSScriptRoot/Assign-PrLabels.ps1"
}

Describe 'ConvertTo-GlobRegex' {
    It 'converts ** to .*' {
        ConvertTo-GlobRegex -Glob 'docs/**' | Should -Be '^docs/.*$'
    }
    It 'converts single * to non-slash segment' {
        ConvertTo-GlobRegex -Glob '*.md' | Should -Be '^[^/]*\.md$'
    }
    It 'converts ? to single-char wildcard' {
        ConvertTo-GlobRegex -Glob 'a?.txt' | Should -Be '^a.\.txt$'
    }
}

Describe 'Test-GlobMatch' {
    It 'matches docs/** against nested docs file' {
        Test-GlobMatch -Path 'docs/intro/guide.md' -Pattern 'docs/**' | Should -BeTrue
    }
    It 'does not match docs/** against src file' {
        Test-GlobMatch -Path 'src/foo.ts' -Pattern 'docs/**' | Should -BeFalse
    }
    It 'matches *.test.* against test files' {
        Test-GlobMatch -Path 'foo.test.ts' -Pattern '*.test.*' | Should -BeTrue
    }
    It 'single * does not cross slashes' {
        Test-GlobMatch -Path 'src/a.ts' -Pattern '*.ts' | Should -BeFalse
    }
    It 'matches **/*.test.* across directories' {
        Test-GlobMatch -Path 'src/api/foo.test.ts' -Pattern '**/*.test.*' | Should -BeTrue
    }
}

Describe 'Get-PrLabels' {
    It 'returns empty array when no files match' {
        $rules = @(@{Pattern='docs/**'; Labels=@('documentation')})
        $result = Get-PrLabels -ChangedFiles @('src/foo.ts') -Rules $rules
        $result | Should -BeNullOrEmpty
    }

    It 'applies a label when a file matches a pattern' {
        $rules = @(@{Pattern='docs/**'; Labels=@('documentation')})
        $result = Get-PrLabels -ChangedFiles @('docs/readme.md') -Rules $rules
        $result | Should -Be @('documentation')
    }

    It 'deduplicates labels across multiple files' {
        $rules = @(@{Pattern='docs/**'; Labels=@('documentation')})
        $result = Get-PrLabels -ChangedFiles @('docs/a.md','docs/b.md') -Rules $rules
        $result | Should -Be @('documentation')
    }

    It 'supports multiple labels per rule' {
        $rules = @(@{Pattern='src/api/**'; Labels=@('api','backend')})
        $result = Get-PrLabels -ChangedFiles @('src/api/foo.ts') -Rules $rules
        ($result | Sort-Object) | Should -Be @('api','backend')
    }

    It 'collects labels from multiple matching rules' {
        $rules = @(
            @{Pattern='docs/**'; Labels=@('documentation')},
            @{Pattern='src/api/**'; Labels=@('api')}
        )
        $result = Get-PrLabels -ChangedFiles @('docs/a.md','src/api/b.ts') -Rules $rules
        ($result | Sort-Object) | Should -Be @('api','documentation')
    }

    It 'orders output by priority (lower number first)' {
        $rules = @(
            @{Pattern='docs/**';    Labels=@('documentation'); Priority=20},
            @{Pattern='src/api/**'; Labels=@('api');           Priority=5}
        )
        $result = Get-PrLabels -ChangedFiles @('docs/a.md','src/api/b.ts') -Rules $rules
        $result | Should -Be @('api','documentation')
    }

    It 'supports *.test.* rule producing tests label' {
        $rules = @(@{Pattern='**/*.test.*'; Labels=@('tests')})
        $result = Get-PrLabels -ChangedFiles @('src/api/foo.test.ts') -Rules $rules
        $result | Should -Be @('tests')
    }

    It 'assigns multiple rule-labels to one file' {
        $rules = @(
            @{Pattern='src/api/**';  Labels=@('api')},
            @{Pattern='**/*.test.*'; Labels=@('tests')}
        )
        $result = Get-PrLabels -ChangedFiles @('src/api/foo.test.ts') -Rules $rules
        ($result | Sort-Object) | Should -Be @('api','tests')
    }

    It 'throws when a rule is missing Pattern' {
        { Get-PrLabels -ChangedFiles @('a') -Rules @(@{Labels=@('x')}) } |
            Should -Throw "*missing required 'Pattern'*"
    }

    It 'throws when a rule is missing Labels' {
        { Get-PrLabels -ChangedFiles @('a') -Rules @(@{Pattern='**'}) } |
            Should -Throw "*missing required 'Labels'*"
    }

    It 'returns empty when there are no changed files' {
        $rules = @(@{Pattern='docs/**'; Labels=@('documentation')})
        $result = Get-PrLabels -ChangedFiles @() -Rules $rules
        $result | Should -BeNullOrEmpty
    }
}

Describe 'Read-Rules' {
    It 'reads rules from JSON' {
        $tmp = New-TemporaryFile
        try {
            '[{"Pattern":"docs/**","Labels":["documentation"]}]' | Set-Content -LiteralPath $tmp
            $rules = Read-Rules -ConfigPath $tmp
            $rules[0].Pattern | Should -Be 'docs/**'
            $rules[0].Labels  | Should -Be @('documentation')
        } finally {
            Remove-Item -LiteralPath $tmp -Force
        }
    }
    It 'throws on missing file' {
        { Read-Rules -ConfigPath '/nonexistent-config-xyz.json' } | Should -Throw '*not found*'
    }
}

Describe 'CLI end-to-end' {
    It 'produces expected label lines from sample inputs' {
        $tmpDir = Join-Path ([IO.Path]::GetTempPath()) ("prlabel-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpDir | Out-Null
        try {
            $cfg = Join-Path $tmpDir 'rules.json'
            $files = Join-Path $tmpDir 'files.txt'
            @'
[
  {"Pattern":"docs/**","Labels":["documentation"],"Priority":30},
  {"Pattern":"src/api/**","Labels":["api","backend"],"Priority":10},
  {"Pattern":"**/*.test.*","Labels":["tests"],"Priority":5}
]
'@ | Set-Content -LiteralPath $cfg
            @'
docs/readme.md
src/api/user.ts
src/api/user.test.ts
'@ | Set-Content -LiteralPath $files

            $out = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Assign-PrLabels.ps1') -ConfigPath $cfg -FilesPath $files
            $out | Should -Be @('tests','api','backend','documentation')
        } finally {
            Remove-Item -LiteralPath $tmpDir -Recurse -Force
        }
    }
}
