BeforeAll {
    . $PSScriptRoot/Invoke-PRLabelAssigner.ps1
}

Describe 'Convert-GlobToRegex' {
    It 'converts docs/** to match files under docs/' {
        $regex = Convert-GlobToRegex -Pattern 'docs/**'
        'docs/readme.md' | Should -Match $regex
        'docs/api/guide.md' | Should -Match $regex
        'src/docs/file.md' | Should -Not -Match $regex
    }

    It 'converts *.md to match only root-level markdown files' {
        $regex = Convert-GlobToRegex -Pattern '*.md'
        'README.md' | Should -Match $regex
        'CHANGELOG.md' | Should -Match $regex
        'docs/readme.md' | Should -Not -Match $regex
    }

    It 'converts **/*.test.* to match test files at any depth' {
        $regex = Convert-GlobToRegex -Pattern '**/*.test.*'
        'app.test.js' | Should -Match $regex
        'src/utils.test.ts' | Should -Match $regex
        'src/deep/nested/file.test.py' | Should -Match $regex
        'nottest.js' | Should -Not -Match $regex
    }

    It 'converts src/api/** to match files under src/api/' {
        $regex = Convert-GlobToRegex -Pattern 'src/api/**'
        'src/api/controller.js' | Should -Match $regex
        'src/api/v2/route.ts' | Should -Match $regex
        'src/core/service.js' | Should -Not -Match $regex
    }

    It 'handles ? wildcard for single character' {
        $regex = Convert-GlobToRegex -Pattern 'file?.txt'
        'file1.txt' | Should -Match $regex
        'fileA.txt' | Should -Match $regex
        'file12.txt' | Should -Not -Match $regex
    }

    It 'handles mid-path **/ for recursive directory match' {
        $regex = Convert-GlobToRegex -Pattern 'src/**/file.js'
        'src/file.js' | Should -Match $regex
        'src/deep/file.js' | Should -Match $regex
        'src/a/b/c/file.js' | Should -Match $regex
        'other/file.js' | Should -Not -Match $regex
    }
}

Describe 'Get-PRLabels' {
    It 'assigns documentation label for matching files' {
        $rules = @([PSCustomObject]@{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 1 })
        $result = Get-PRLabels -ChangedFiles @('docs/readme.md', 'docs/api/guide.md') -Rules $rules
        ($result -join ', ') | Should -Be 'documentation'
    }

    It 'assigns multiple labels from different rules matching different files' {
        $rules = @(
            [PSCustomObject]@{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 1 },
            [PSCustomObject]@{ Pattern = 'src/api/**'; Label = 'api'; Priority = 2 }
        )
        $result = Get-PRLabels -ChangedFiles @('src/api/controller.js', 'docs/readme.md') -Rules $rules
        ($result -join ', ') | Should -Be 'api, documentation'
    }

    It 'assigns multiple labels to a single file matching multiple rules' {
        $rules = @(
            [PSCustomObject]@{ Pattern = 'src/api/**'; Label = 'api'; Priority = 1 },
            [PSCustomObject]@{ Pattern = '**/*.test.*'; Label = 'tests'; Priority = 2 }
        )
        $result = Get-PRLabels -ChangedFiles @('src/api/handler.test.js') -Rules $rules
        ($result -join ', ') | Should -Be 'api, tests'
    }

    It 'returns empty when no files match any rule' {
        $rules = @([PSCustomObject]@{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 1 })
        $result = Get-PRLabels -ChangedFiles @('random/file.txt') -Rules $rules
        $result | Should -BeNullOrEmpty
    }

    It 'returns empty when file list is empty' {
        $rules = @([PSCustomObject]@{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 1 })
        $result = Get-PRLabels -ChangedFiles @() -Rules $rules
        $result | Should -BeNullOrEmpty
    }

    It 'resolves exclusive group conflicts using priority' {
        $rules = @(
            [PSCustomObject]@{ Pattern = 'src/**'; Label = 'backend'; Priority = 1; ExclusiveGroup = 'scope' },
            [PSCustomObject]@{ Pattern = 'src/api/**'; Label = 'api'; Priority = 2; ExclusiveGroup = 'scope' }
        )
        $result = Get-PRLabels -ChangedFiles @('src/api/controller.js') -Rules $rules
        ($result -join ', ') | Should -Be 'backend'
    }

    It 'allows non-grouped rules alongside exclusive group rules' {
        $rules = @(
            [PSCustomObject]@{ Pattern = 'src/**'; Label = 'backend'; Priority = 1; ExclusiveGroup = 'scope' },
            [PSCustomObject]@{ Pattern = '**/*.test.*'; Label = 'tests'; Priority = 2 }
        )
        $result = Get-PRLabels -ChangedFiles @('src/utils.test.js') -Rules $rules
        ($result -join ', ') | Should -Be 'backend, tests'
    }

    It 'throws on empty rules' {
        { Get-PRLabels -ChangedFiles @('file.txt') -Rules @() } | Should -Throw
    }

    It 'throws when a rule is missing Pattern' {
        $rules = @([PSCustomObject]@{ Label = 'test'; Priority = 1 })
        { Get-PRLabels -ChangedFiles @('file.txt') -Rules $rules } | Should -Throw "*Pattern*"
    }

    It 'throws when a rule is missing Label' {
        $rules = @([PSCustomObject]@{ Pattern = '*.md'; Priority = 1 })
        { Get-PRLabels -ChangedFiles @('file.txt') -Rules $rules } | Should -Throw "*Label*"
    }

    It 'deduplicates labels across multiple files' {
        $rules = @([PSCustomObject]@{ Pattern = 'docs/**'; Label = 'documentation'; Priority = 1 })
        $result = Get-PRLabels -ChangedFiles @('docs/a.md', 'docs/b.md', 'docs/c.md') -Rules $rules
        ($result -join ', ') | Should -Be 'documentation'
    }
}

Describe 'Import-LabelRules' {
    It 'loads rules from a valid JSON config file' {
        $tempFile = [System.IO.Path]::GetTempFileName()
        @{
            rules = @(
                @{ pattern = 'docs/**'; label = 'documentation'; priority = 1 },
                @{ pattern = 'src/**'; label = 'backend'; priority = 2 }
            )
        } | ConvertTo-Json -Depth 3 | Set-Content $tempFile

        $rules = Import-LabelRules -Path $tempFile
        $rules.Count | Should -Be 2
        $rules[0].pattern | Should -Be 'docs/**'
        $rules[1].label | Should -Be 'backend'

        Remove-Item $tempFile
    }

    It 'throws when file does not exist' {
        { Import-LabelRules -Path '/nonexistent/rules.json' } | Should -Throw "*not found*"
    }

    It 'throws when JSON is missing rules array' {
        $tempFile = [System.IO.Path]::GetTempFileName()
        @{ notRules = @() } | ConvertTo-Json | Set-Content $tempFile

        { Import-LabelRules -Path $tempFile } | Should -Throw "*rules*"

        Remove-Item $tempFile
    }
}
