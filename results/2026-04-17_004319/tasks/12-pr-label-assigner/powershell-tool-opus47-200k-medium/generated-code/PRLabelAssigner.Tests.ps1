# Pester tests for PR Label Assigner.
# Red/green TDD: each Describe block targets one piece of behavior.

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot 'PRLabelAssigner.ps1'
    . $script:ScriptPath
}

Describe 'Test-GlobMatch' {
    It 'matches simple double-star prefix' {
        Test-GlobMatch -Path 'docs/intro.md' -Pattern 'docs/**' | Should -BeTrue
    }
    It 'matches deep double-star' {
        Test-GlobMatch -Path 'src/api/v1/users.ts' -Pattern 'src/api/**' | Should -BeTrue
    }
    It 'matches single-star within a segment' {
        Test-GlobMatch -Path 'foo/bar.test.js' -Pattern '*.test.*' | Should -BeTrue
    }
    It 'does not match unrelated paths' {
        Test-GlobMatch -Path 'src/lib/x.ts' -Pattern 'docs/**' | Should -BeFalse
    }
    It 'matches single character with ?' {
        Test-GlobMatch -Path 'a/b.ts' -Pattern 'a/?.ts' | Should -BeTrue
    }
}

Describe 'Get-PRLabels' {
    BeforeAll {
        $script:Rules = @(
            [pscustomobject]@{ Pattern = 'docs/**';      Label = 'documentation'; Priority = 10 }
            [pscustomobject]@{ Pattern = 'src/api/**';   Label = 'api';           Priority = 20 }
            [pscustomobject]@{ Pattern = '*.test.*';     Label = 'tests';         Priority = 30 }
            [pscustomobject]@{ Pattern = 'src/api/**';   Label = 'backend';       Priority = 20 }
        )
    }

    It 'returns empty when no files match' {
        $r = Get-PRLabels -Files @('README.adoc') -Rules $script:Rules
        $r | Should -BeNullOrEmpty
    }

    It 'assigns documentation label for docs files' {
        $r = Get-PRLabels -Files @('docs/intro.md') -Rules $script:Rules
        $r | Should -Be @('documentation')
    }

    It 'assigns multiple labels for files matching multiple rules' {
        $r = Get-PRLabels -Files @('src/api/v1.ts') -Rules $script:Rules
        $r | Sort-Object | Should -Be @('api','backend')
    }

    It 'deduplicates labels across multiple files' {
        $r = Get-PRLabels -Files @('docs/a.md','docs/b.md') -Rules $script:Rules
        $r | Should -Be @('documentation')
    }

    It 'matches *.test.* across nested files' {
        $r = Get-PRLabels -Files @('src/api/foo.test.ts') -Rules $script:Rules
        $r | Sort-Object | Should -Be @('api','backend','tests')
    }

    It 'orders labels by descending priority then alphabetically' {
        $r = Get-PRLabels -Files @('src/api/foo.test.ts') -Rules $script:Rules
        # tests=30, api=20, backend=20 -> tests, api, backend
        $r | Should -Be @('tests','api','backend')
    }
}

Describe 'Import-LabelRules' {
    It 'reads JSON rules file' {
        $tmp = New-TemporaryFile
        @'
[
  { "pattern": "docs/**", "label": "documentation", "priority": 10 },
  { "pattern": "src/**", "label": "source", "priority": 5 }
]
'@ | Set-Content -Path $tmp.FullName
        try {
            $rules = Import-LabelRules -Path $tmp.FullName
            $rules.Count | Should -Be 2
            $rules[0].Label | Should -Be 'documentation'
            $rules[0].Priority | Should -Be 10
        } finally { Remove-Item $tmp.FullName -Force }
    }

    It 'throws on missing file' {
        { Import-LabelRules -Path '/nonexistent/path/rules.json' } | Should -Throw
    }
}

Describe 'Invoke-LabelAssigner end-to-end' {
    It 'reads files list and rules and outputs labels' {
        $rulesFile = New-TemporaryFile
        @'
[
  { "pattern": "docs/**", "label": "documentation", "priority": 10 },
  { "pattern": "*.test.*", "label": "tests", "priority": 30 }
]
'@ | Set-Content -Path $rulesFile.FullName

        $filesFile = New-TemporaryFile
        "docs/a.md`nsrc/x.test.ts" | Set-Content -Path $filesFile.FullName

        try {
            $out = Invoke-LabelAssigner -RulesPath $rulesFile.FullName -FilesPath $filesFile.FullName
            $out | Should -Be @('tests','documentation')
        } finally {
            Remove-Item $rulesFile.FullName, $filesFile.FullName -Force
        }
    }
}
