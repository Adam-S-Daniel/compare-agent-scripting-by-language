# Pester tests for the environment matrix generator.
# Red/green TDD: each Describe block was added test-first, then code was added to satisfy it.

BeforeAll {
    . "$PSScriptRoot/New-EnvironmentMatrix.ps1"
}

Describe "New-EnvironmentMatrix - cartesian product" {
    It "produces the cartesian product of axes" {
        $config = @{
            axes = @{
                os         = @('ubuntu-latest','windows-latest')
                node       = @('18','20')
            }
        }
        $result = New-EnvironmentMatrix -Config $config
        $result.matrix.include.Count | Should -Be 4
        ($result.matrix.include | Where-Object { $_.os -eq 'ubuntu-latest' -and $_.node -eq '20' }).Count | Should -Be 1
    }

    It "uses the literal include/exclude/fail-fast/max-parallel keys expected by Actions" {
        $config = @{ axes = @{ os = @('ubuntu-latest') }; 'fail-fast' = $false; 'max-parallel' = 3 }
        $result = New-EnvironmentMatrix -Config $config
        $result.PSObject.Properties.Name | Should -Contain 'fail-fast'
        $result.PSObject.Properties.Name | Should -Contain 'max-parallel'
        $result.'fail-fast' | Should -Be $false
        $result.'max-parallel' | Should -Be 3
    }
}

Describe "New-EnvironmentMatrix - exclude rules" {
    It "removes combinations matching exclude rules" {
        $config = @{
            axes    = @{ os = @('ubuntu-latest','windows-latest'); node = @('18','20') }
            exclude = @( @{ os = 'windows-latest'; node = '18' } )
        }
        $result = New-EnvironmentMatrix -Config $config
        $result.matrix.include.Count | Should -Be 3
        ($result.matrix.include | Where-Object { $_.os -eq 'windows-latest' -and $_.node -eq '18' }).Count | Should -Be 0
    }
}

Describe "New-EnvironmentMatrix - include rules" {
    It "appends include entries to the matrix" {
        $config = @{
            axes    = @{ os = @('ubuntu-latest'); node = @('20') }
            include = @( @{ os = 'macos-latest'; node = '20'; experimental = $true } )
        }
        $result = New-EnvironmentMatrix -Config $config
        $result.matrix.include.Count | Should -Be 2
        $extra = $result.matrix.include | Where-Object { $_.os -eq 'macos-latest' }
        $extra.experimental | Should -Be $true
    }
}

Describe "New-EnvironmentMatrix - max size validation" {
    It "throws when the generated matrix exceeds max-size" {
        $config = @{
            axes       = @{ a = 1..10; b = 1..10; c = 1..10 }   # 1000 combinations
            'max-size' = 256
        }
        { New-EnvironmentMatrix -Config $config } | Should -Throw -ErrorId 'MatrixTooLarge,New-EnvironmentMatrix'
    }

    It "respects GitHub's hard ceiling of 256 even when not configured" {
        $config = @{ axes = @{ a = 1..20; b = 1..20 } }   # 400 combinations
        { New-EnvironmentMatrix -Config $config } | Should -Throw -ErrorId 'MatrixTooLarge,New-EnvironmentMatrix'
    }
}

Describe "New-EnvironmentMatrix - errors" {
    It "throws when no axes are provided" {
        { New-EnvironmentMatrix -Config @{ axes = @{} } } | Should -Throw -ErrorId 'NoAxes,New-EnvironmentMatrix'
    }
}

Describe "ConvertTo-MatrixJson" {
    It "emits compact GitHub-Actions-compatible JSON" {
        $config = @{ axes = @{ os = @('ubuntu-latest'); node = @('20') }; 'fail-fast' = $true }
        $json = New-EnvironmentMatrix -Config $config | ConvertTo-MatrixJson
        $obj  = $json | ConvertFrom-Json
        $obj.matrix.include[0].os    | Should -Be 'ubuntu-latest'
        $obj.matrix.include[0].node  | Should -Be '20'
        $obj.'fail-fast'             | Should -Be $true
    }
}
