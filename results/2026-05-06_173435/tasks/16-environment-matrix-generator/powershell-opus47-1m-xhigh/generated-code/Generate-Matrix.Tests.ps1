#Requires -Modules Pester

# Pester tests for Generate-Matrix.ps1.
# Built incrementally with red/green TDD: each Describe block was added by
# first writing a failing test, then implementing the minimum logic to pass.

BeforeAll {
    # Dot-source the script under test so its functions are in scope.
    . "$PSScriptRoot/Generate-Matrix.ps1"
}

Describe "New-BuildMatrix - basic axis expansion" {
    It "produces a single combination for a single OS axis" {
        $config = @{ os = @('ubuntu-latest') }
        $result = New-BuildMatrix -Config $config
        $result.size | Should -Be 1
    }

    It "produces the Cartesian product of OS and a language version axis" {
        $config = @{
            os       = @('ubuntu-latest', 'macos-latest')
            versions = @{ node = @('18', '20') }
        }
        $result = New-BuildMatrix -Config $config
        $result.size | Should -Be 4
    }

    It "treats feature flags as additional axes (multiplicative)" {
        $config = @{
            os       = @('ubuntu-latest')
            versions = @{ node = @('20') }
            features = @{ experimental = @($true, $false) }
        }
        $result = New-BuildMatrix -Config $config
        $result.size | Should -Be 2
    }

    It "exposes the original axes on the matrix object" {
        $config = @{
            os       = @('ubuntu-latest')
            versions = @{ node = @('20') }
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.os    | Should -Be @('ubuntu-latest')
        $result.matrix.node  | Should -Be @('20')
    }
}

Describe "New-BuildMatrix - exclude rules" {
    It "removes combinations that match an exclude filter on every key" {
        $config = @{
            os       = @('ubuntu-latest', 'macos-latest')
            versions = @{ node = @('18', '20') }
            exclude  = @( @{ os = 'macos-latest'; node = '18' } )
        }
        $result = New-BuildMatrix -Config $config
        $result.size | Should -Be 3
    }

    It "leaves the matrix untouched when no exclude filter matches" {
        $config = @{
            os       = @('ubuntu-latest')
            versions = @{ node = @('20') }
            exclude  = @( @{ os = 'windows-latest' } )
        }
        $result = New-BuildMatrix -Config $config
        $result.size | Should -Be 1
    }

    It "treats partial-key excludes as 'remove all combinations matching that subset'" {
        $config = @{
            os       = @('ubuntu-latest', 'macos-latest')
            versions = @{ node = @('18', '20') }
            exclude  = @( @{ os = 'macos-latest' } )
        }
        $result = New-BuildMatrix -Config $config
        $result.size | Should -Be 2  # only ubuntu rows remain
    }
}

Describe "New-BuildMatrix - include rules" {
    It "adds non-overlapping include entries as additional combinations" {
        $config = @{
            os       = @('ubuntu-latest')
            versions = @{ node = @('18') }
            include  = @( @{ os = 'windows-latest'; node = '20'; extra = 'yes' } )
        }
        $result = New-BuildMatrix -Config $config
        $result.size | Should -Be 2
    }

    It "merges an include into an existing matching combination instead of duplicating it" {
        $config = @{
            os       = @('ubuntu-latest')
            versions = @{ node = @('20') }
            include  = @( @{ os = 'ubuntu-latest'; node = '20'; coverage = $true } )
        }
        $result = New-BuildMatrix -Config $config
        $result.size | Should -Be 1
    }
}

Describe "New-BuildMatrix - strategy options" {
    It "passes through max_parallel as 'max-parallel'" {
        $result = New-BuildMatrix -Config @{ os = @('ubuntu-latest'); max_parallel = 4 }
        $result['max-parallel'] | Should -Be 4
    }

    It "passes through fail_fast as 'fail-fast'" {
        $result = New-BuildMatrix -Config @{ os = @('ubuntu-latest'); fail_fast = $false }
        $result['fail-fast'] | Should -Be $false
    }

    It "omits strategy options that were not configured" {
        $result = New-BuildMatrix -Config @{ os = @('ubuntu-latest') }
        $result.Contains('max-parallel') | Should -Be $false
        $result.Contains('fail-fast')    | Should -Be $false
    }
}

Describe "New-BuildMatrix - size validation" {
    It "throws when the generated matrix exceeds max_size" {
        $config = @{
            os       = @('a', 'b', 'c', 'd')
            versions = @{ v = @('1', '2', '3') }
            max_size = 5
        }
        { New-BuildMatrix -Config $config } | Should -Throw -ExpectedMessage '*exceeds*'
    }

    It "succeeds when the generated matrix is within max_size" {
        $config = @{ os = @('a', 'b'); max_size = 5 }
        { New-BuildMatrix -Config $config } | Should -Not -Throw
    }
}

Describe "New-BuildMatrix - input validation" {
    It "throws when no axes are configured" {
        { New-BuildMatrix -Config @{} } | Should -Throw -ExpectedMessage '*at least one axis*'
    }

    It "throws when an axis is empty" {
        { New-BuildMatrix -Config @{ os = @() } } | Should -Throw -ExpectedMessage "*'os'*"
    }

    It "throws on a meaningful message when an exclude entry is not an object" {
        $config = @{ os = @('ubuntu-latest'); exclude = @('badstring') }
        { New-BuildMatrix -Config $config } | Should -Throw -ExpectedMessage '*exclude*'
    }
}

Describe "Get-MatrixConfig - JSON loader" {
    It "loads a JSON config file into a hashtable" {
        $tmp = New-TemporaryFile
        try {
            '{"os":["ubuntu-latest"],"versions":{"node":["20"]}}' |
                Set-Content -LiteralPath $tmp.FullName
            $config = Get-MatrixConfig -Path $tmp.FullName
            $config.os    | Should -Contain 'ubuntu-latest'
            $config.versions.node | Should -Contain '20'
        } finally {
            Remove-Item $tmp -Force
        }
    }

    It "throws a clear error when the config file is missing" {
        { Get-MatrixConfig -Path '/no/such/file.json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It "throws a clear error when the JSON is malformed" {
        $tmp = New-TemporaryFile
        try {
            '{not-json' | Set-Content -LiteralPath $tmp.FullName
            { Get-MatrixConfig -Path $tmp.FullName } |
                Should -Throw -ExpectedMessage '*Failed to parse*'
        } finally {
            Remove-Item $tmp -Force
        }
    }
}

Describe "Convert-MatrixToJson - serialization shape" {
    It "preserves single-element axis arrays as JSON arrays" {
        $config = @{ os = @('ubuntu-latest') }
        $matrix = New-BuildMatrix -Config $config
        $json   = $matrix | ConvertTo-Json -Depth 20
        $parsed = $json | ConvertFrom-Json
        # Even a single-value axis must serialize as an array so GitHub Actions
        # picks it up as a matrix axis (not a scalar).
        ,$parsed.matrix.os | Should -BeOfType [System.Array]
    }
}

Describe "Workflow file structure" {
    BeforeAll {
        $script:WorkflowPath = "$PSScriptRoot/.github/workflows/environment-matrix-generator.yml"
    }

    It "has a workflow file at the expected path" {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It "references the generator script" {
        $content = Get-Content -Raw -LiteralPath $script:WorkflowPath
        $content | Should -Match 'Generate-Matrix\.ps1'
    }

    It "uses the pinned actions/checkout action" {
        $content = Get-Content -Raw -LiteralPath $script:WorkflowPath
        $content | Should -Match 'actions/checkout@v4'
    }

    It "declares triggers for push, pull_request, and workflow_dispatch" {
        $content = Get-Content -Raw -LiteralPath $script:WorkflowPath
        $content | Should -Match '(?ms)^on:.*push:.*pull_request:.*workflow_dispatch:'
    }

    It "passes actionlint validation" {
        $actionlint = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $actionlint) {
            Set-ItResult -Skipped -Because "actionlint is not installed in this environment"
            return
        }
        $output   = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $output"
    }
}
