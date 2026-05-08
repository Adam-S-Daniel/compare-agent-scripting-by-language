# Pester tests for the Environment Matrix Generator.
#
# TDD methodology: each `Describe` block corresponds to one piece of
# functionality. We write these tests first (red), implement the minimum
# code in MatrixGenerator.psm1 to make them pass (green), then refactor.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'MatrixGenerator.psm1' | Resolve-Path
    Import-Module $script:ModulePath -Force
}

Describe 'New-BuildMatrix - cartesian product over base axes' {
    It 'expands a 2x2 matrix into 4 combinations' {
        $config = @{
            axes = @{
                os   = @('ubuntu-latest', 'macos-latest')
                node = @('18', '20')
            }
        }

        $result = New-BuildMatrix -Config $config

        $result.include.Count | Should -Be 4
        $oses = $result.include | ForEach-Object { $_.os } | Sort-Object -Unique
        $nodes = $result.include | ForEach-Object { $_.node } | Sort-Object -Unique
        $oses  | Should -Be @('macos-latest', 'ubuntu-latest')
        $nodes | Should -Be @('18', '20')
    }

    It 'expands a 3-axis matrix into the full cartesian product' {
        $config = @{
            axes = @{
                os      = @('ubuntu-latest', 'windows-latest')
                python  = @('3.11', '3.12')
                feature = @('on', 'off')
            }
        }

        $result = New-BuildMatrix -Config $config
        $result.include.Count | Should -Be 8  # 2 * 2 * 2
    }

    It 'produces an empty include array when an axis is empty' {
        $config = @{
            axes = @{
                os   = @('ubuntu-latest')
                node = @()
            }
        }

        $result = New-BuildMatrix -Config $config
        $result.include.Count | Should -Be 0
    }
}

Describe 'New-BuildMatrix - exclude rules' {
    It 'removes combinations matching an exclude rule (all keys must match)' {
        $config = @{
            axes = @{
                os   = @('ubuntu-latest', 'macos-latest')
                node = @('18', '20')
            }
            exclude = @(
                @{ os = 'macos-latest'; node = '18' }
            )
        }

        $result = New-BuildMatrix -Config $config
        $result.include.Count | Should -Be 3
        $excluded = $result.include | Where-Object { $_.os -eq 'macos-latest' -and $_.node -eq '18' }
        $excluded | Should -BeNullOrEmpty
    }

    It 'supports exclude rules that match a partial subset of axes' {
        # An exclude with only `os = windows-latest` must remove every
        # combination on that OS, regardless of other axis values.
        $config = @{
            axes = @{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @('18', '20', '22')
            }
            exclude = @(
                @{ os = 'windows-latest' }
            )
        }

        $result = New-BuildMatrix -Config $config
        $result.include.Count | Should -Be 3
        ($result.include | Where-Object { $_.os -eq 'windows-latest' }) | Should -BeNullOrEmpty
    }
}

Describe 'New-BuildMatrix - include rules' {
    It 'appends an include entry as a new combination' {
        $config = @{
            axes = @{
                os   = @('ubuntu-latest')
                node = @('20')
            }
            include = @(
                @{ os = 'macos-latest'; node = '22'; experimental = $true }
            )
        }

        $result = New-BuildMatrix -Config $config
        $result.include.Count | Should -Be 2
        $extra = $result.include | Where-Object { $_.os -eq 'macos-latest' }
        $extra.experimental | Should -Be $true
    }
}

Describe 'New-BuildMatrix - max-parallel and fail-fast' {
    It 'propagates max-parallel from the config to the output' {
        $config = @{
            axes        = @{ os = @('ubuntu-latest') }
            'max-parallel' = 4
        }

        $result = New-BuildMatrix -Config $config
        $result['max-parallel'] | Should -Be 4
    }

    It 'propagates fail-fast (default true if unspecified)' {
        $config = @{
            axes        = @{ os = @('ubuntu-latest') }
            'fail-fast' = $false
        }

        $result = New-BuildMatrix -Config $config
        $result['fail-fast'] | Should -Be $false
    }

    It 'defaults fail-fast to $true when not provided' {
        $config = @{ axes = @{ os = @('ubuntu-latest') } }
        $result = New-BuildMatrix -Config $config
        $result['fail-fast'] | Should -Be $true
    }
}

Describe 'New-BuildMatrix - max-size validation' {
    It 'throws a meaningful error when the resolved matrix exceeds max-size' {
        $config = @{
            axes = @{
                os = @('a','b','c','d','e','f','g','h','i','j','k')  # 11 entries
            }
            'max-size' = 10
        }

        { New-BuildMatrix -Config $config } | Should -Throw -ExpectedMessage '*exceeds max-size*'
    }

    It 'does not throw when size equals max-size' {
        $config = @{
            axes       = @{ os = @('a','b','c','d','e') }
            'max-size' = 5
        }
        { New-BuildMatrix -Config $config } | Should -Not -Throw
    }

    It 'enforces the GitHub-Actions hard limit of 256 jobs by default' {
        # 17 * 16 = 272, exceeds the default 256 cap.
        $axis1 = 1..17 | ForEach-Object { "v$_" }
        $axis2 = 1..16 | ForEach-Object { "w$_" }
        $config = @{ axes = @{ a = $axis1; b = $axis2 } }
        { New-BuildMatrix -Config $config } | Should -Throw -ExpectedMessage '*exceeds max-size*'
    }
}

Describe 'New-BuildMatrix - JSON output / CLI invocation' {
    It 'ConvertTo-MatrixJson produces compact, valid JSON suitable for GITHUB_OUTPUT' {
        $config = @{ axes = @{ os = @('ubuntu-latest'); node = @('20') } }
        $result = New-BuildMatrix -Config $config

        $json = ConvertTo-MatrixJson -Matrix $result
        $json | Should -Not -Match "`n"   # single-line / compressed for set-output
        # Round-trip back to ensure JSON validity.
        $parsed = $json | ConvertFrom-Json
        $parsed.include[0].os | Should -Be 'ubuntu-latest'
        $parsed.include[0].node | Should -Be '20'
    }

    It 'Invoke-MatrixGenerator reads a JSON config file and writes the matrix' {
        $tempIn  = New-TemporaryFile
        $tempOut = New-TemporaryFile
        try {
            @{
                axes        = @{ os = @('ubuntu-latest'); node = @('18','20') }
                'max-parallel' = 2
                'fail-fast' = $false
            } | ConvertTo-Json -Depth 10 | Set-Content -Path $tempIn -Encoding utf8

            Invoke-MatrixGenerator -ConfigPath $tempIn -OutputPath $tempOut

            $written = Get-Content $tempOut -Raw | ConvertFrom-Json
            $written.include.Count | Should -Be 2
            $written.'max-parallel' | Should -Be 2
            $written.'fail-fast' | Should -Be $false
        } finally {
            Remove-Item $tempIn, $tempOut -ErrorAction SilentlyContinue
        }
    }

    It 'Invoke-MatrixGenerator emits a clear error when the config file is missing' {
        { Invoke-MatrixGenerator -ConfigPath '/nonexistent/path/to/config.json' -OutputPath '/tmp/out.json' } |
            Should -Throw -ExpectedMessage '*config file not found*'
    }

    It 'Invoke-MatrixGenerator surfaces malformed JSON with a helpful message' {
        $tempIn = New-TemporaryFile
        try {
            'this is not json {' | Set-Content -Path $tempIn -Encoding utf8
            { Invoke-MatrixGenerator -ConfigPath $tempIn -OutputPath '/tmp/x.json' } |
                Should -Throw -ExpectedMessage '*invalid JSON*'
        } finally {
            Remove-Item $tempIn -ErrorAction SilentlyContinue
        }
    }
}
