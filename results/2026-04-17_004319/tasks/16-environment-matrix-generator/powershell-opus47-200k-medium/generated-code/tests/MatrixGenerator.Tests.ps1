# Pester tests for MatrixGenerator — red/green TDD.
# Each describe block exercises one behavior. Run with: Invoke-Pester tests/

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'src' 'MatrixGenerator.psm1'
    Import-Module $script:ModulePath -Force
}

Describe 'New-BuildMatrix — base cartesian product' {
    It 'produces the full cross-product of os and node versions' {
        $cfg = @{
            axes = @{
                os   = @('ubuntu-latest','windows-latest')
                node = @('18','20')
            }
        }
        $result = New-BuildMatrix -Config $cfg
        $result.matrix.include.Count | Should -Be 4
        ($result.matrix.include | Where-Object { $_.os -eq 'ubuntu-latest' -and $_.node -eq '20' }).Count | Should -Be 1
    }

    It 'returns a single axis matrix when only one axis is provided' {
        $cfg = @{ axes = @{ os = @('ubuntu-latest','macos-latest') } }
        $result = New-BuildMatrix -Config $cfg
        $result.matrix.include.Count | Should -Be 2
    }
}

Describe 'New-BuildMatrix — include rules' {
    It 'appends explicit include combinations that were not in the product' {
        $cfg = @{
            axes    = @{ os = @('ubuntu-latest'); node = @('18') }
            include = @(@{ os = 'windows-latest'; node = '20'; experimental = $true })
        }
        $result = New-BuildMatrix -Config $cfg
        $result.matrix.include.Count | Should -Be 2
        ($result.matrix.include | Where-Object { $_.experimental -eq $true }).os | Should -Be 'windows-latest'
    }

    It 'augments a matching combination with extra properties rather than duplicating it' {
        $cfg = @{
            axes    = @{ os = @('ubuntu-latest'); node = @('18','20') }
            include = @(@{ os = 'ubuntu-latest'; node = '20'; coverage = $true })
        }
        $result = New-BuildMatrix -Config $cfg
        $result.matrix.include.Count | Should -Be 2
        $augmented = $result.matrix.include | Where-Object { $_.node -eq '20' }
        $augmented.coverage | Should -Be $true
    }
}

Describe 'New-BuildMatrix — exclude rules' {
    It 'removes combinations matching an exclude spec' {
        $cfg = @{
            axes    = @{ os = @('ubuntu-latest','windows-latest'); node = @('18','20') }
            exclude = @(@{ os = 'windows-latest'; node = '18' })
        }
        $result = New-BuildMatrix -Config $cfg
        $result.matrix.include.Count | Should -Be 3
        ($result.matrix.include | Where-Object { $_.os -eq 'windows-latest' -and $_.node -eq '18' }).Count | Should -Be 0
    }
}

Describe 'New-BuildMatrix — max-parallel and fail-fast' {
    It 'passes through max-parallel and fail-fast values' {
        $cfg = @{
            axes         = @{ os = @('ubuntu-latest') }
            'max-parallel' = 4
            'fail-fast'   = $false
        }
        $result = New-BuildMatrix -Config $cfg
        $result.'max-parallel' | Should -Be 4
        $result.'fail-fast'   | Should -Be $false
    }

    It 'defaults fail-fast to true when unspecified' {
        $cfg = @{ axes = @{ os = @('ubuntu-latest') } }
        $result = New-BuildMatrix -Config $cfg
        $result.'fail-fast' | Should -Be $true
    }
}

Describe 'New-BuildMatrix — size validation' {
    It 'throws when the resulting matrix exceeds max-size' {
        $cfg = @{
            axes       = @{ os = @('a','b','c'); v = @('1','2','3','4') }
            'max-size' = 5
        }
        { New-BuildMatrix -Config $cfg } | Should -Throw -ExpectedMessage '*exceeds max-size*'
    }

    It 'succeeds when size is exactly at max-size' {
        $cfg = @{
            axes       = @{ os = @('a','b'); v = @('1','2') }
            'max-size' = 4
        }
        { New-BuildMatrix -Config $cfg } | Should -Not -Throw
    }
}

Describe 'New-BuildMatrix — input validation' {
    It 'throws when axes is missing' {
        { New-BuildMatrix -Config @{} } | Should -Throw -ExpectedMessage '*axes*'
    }

    It 'throws when an axis is empty' {
        { New-BuildMatrix -Config @{ axes = @{ os = @() } } } | Should -Throw -ExpectedMessage '*empty*'
    }
}

Describe 'ConvertTo-MatrixJson — json output shape' {
    It 'emits a valid GitHub Actions strategy.matrix JSON' {
        $cfg = @{
            axes         = @{ os = @('ubuntu-latest'); node = @('20') }
            'max-parallel' = 2
            'fail-fast'   = $true
        }
        $json = New-BuildMatrix -Config $cfg | ConvertTo-MatrixJson
        $obj  = $json | ConvertFrom-Json
        $obj.matrix.include.Count   | Should -Be 1
        $obj.'max-parallel'         | Should -Be 2
        $obj.'fail-fast'            | Should -Be $true
    }
}

Describe 'Invoke-MatrixGenerator — end-to-end CLI' {
    It 'reads a JSON config file and writes matrix JSON to stdout' {
        $tmp = New-TemporaryFile
        @'
{
  "axes": { "os": ["ubuntu-latest","macos-latest"], "node": ["18","20"] },
  "exclude": [ { "os": "macos-latest", "node": "18" } ],
  "include": [ { "os": "ubuntu-latest", "node": "20", "coverage": true } ],
  "max-parallel": 3,
  "fail-fast": false,
  "max-size": 10
}
'@ | Set-Content -Path $tmp
        $out = Invoke-MatrixGenerator -ConfigPath $tmp.FullName
        $obj = $out | ConvertFrom-Json
        $obj.matrix.include.Count | Should -Be 3
        $obj.'max-parallel'       | Should -Be 3
        $obj.'fail-fast'          | Should -Be $false
        Remove-Item $tmp -Force
    }
}
