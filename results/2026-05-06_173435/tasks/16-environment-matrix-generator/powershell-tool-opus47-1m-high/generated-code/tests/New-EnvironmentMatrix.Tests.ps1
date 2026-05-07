# Pester tests for New-EnvironmentMatrix.
#
# These tests drive the design via red/green TDD. The script under test is dot-sourced
# in a BeforeAll block so each Describe re-imports the function definitions cleanly.
# Tests assert against parsed JSON to be representation-agnostic (we only care about
# semantic structure, not specific whitespace).

BeforeAll {
    $script:ProjectRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $script:ProjectRoot 'src/New-EnvironmentMatrix.ps1')
}

Describe 'New-EnvironmentMatrix - basic cartesian product' {

    It 'generates the cartesian product of two axes' {
        $config = @{
            axes = [ordered]@{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @(18, 20)
            }
        }
        $result = New-EnvironmentMatrix -Configuration $config | ConvertFrom-Json
        $result.size | Should -Be 4
        $result.matrix.include.Count | Should -Be 4
        # Every combination must have both axis keys
        foreach ($c in $result.matrix.include) {
            $c.os   | Should -Not -BeNullOrEmpty
            $c.node | Should -Not -BeNullOrEmpty
        }
    }

    It 'preserves single-axis matrices' {
        $config = @{ axes = [ordered]@{ os = @('ubuntu-latest', 'macos-latest', 'windows-latest') } }
        $result = New-EnvironmentMatrix -Configuration $config | ConvertFrom-Json
        $result.size | Should -Be 3
        ($result.matrix.include.os | Sort-Object) -join ',' | Should -Be 'macos-latest,ubuntu-latest,windows-latest'
    }

    It 'computes the cartesian product of three axes' {
        $config = @{
            axes = [ordered]@{
                os       = @('ubuntu-latest', 'windows-latest')
                node     = @(18, 20)
                features = @('full', 'lite')
            }
        }
        $result = New-EnvironmentMatrix -Configuration $config | ConvertFrom-Json
        $result.size | Should -Be 8
    }
}

Describe 'New-EnvironmentMatrix - exclude rules' {

    It 'removes combinations that match an exclude rule on all listed keys' {
        $config = @{
            axes = [ordered]@{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @(18, 20)
            }
            exclude = @(
                @{ os = 'windows-latest'; node = 18 }
            )
        }
        $result = New-EnvironmentMatrix -Configuration $config | ConvertFrom-Json
        $result.size | Should -Be 3
        # Asserting the excluded pair is gone
        $matched = $result.matrix.include | Where-Object { $_.os -eq 'windows-latest' -and $_.node -eq 18 }
        $matched | Should -BeNullOrEmpty
    }

    It 'supports partial exclude rules (subset of axes)' {
        # An exclude with only one axis key removes ALL combinations matching that key.
        $config = @{
            axes = [ordered]@{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @(18, 20)
            }
            exclude = @(
                @{ os = 'windows-latest' }
            )
        }
        $result = New-EnvironmentMatrix -Configuration $config | ConvertFrom-Json
        $result.size | Should -Be 2
        ($result.matrix.include | Where-Object { $_.os -eq 'windows-latest' }) | Should -BeNullOrEmpty
    }

    It 'throws when all combinations are excluded' {
        $config = @{
            axes = [ordered]@{ os = @('ubuntu-latest') }
            exclude = @(@{ os = 'ubuntu-latest' })
        }
        { New-EnvironmentMatrix -Configuration $config } | Should -Throw -ExpectedMessage '*empty*'
    }
}

Describe 'New-EnvironmentMatrix - include rules' {

    It 'extends an existing combination with extra properties (no new combination created)' {
        $config = @{
            axes = [ordered]@{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @(18, 20)
            }
            include = @(
                @{ os = 'ubuntu-latest'; node = 18; experimental = $true }
            )
        }
        $result = New-EnvironmentMatrix -Configuration $config | ConvertFrom-Json
        $result.size | Should -Be 4   # no new combination, just extension
        $extended = $result.matrix.include | Where-Object { $_.os -eq 'ubuntu-latest' -and $_.node -eq 18 }
        $extended.experimental | Should -BeTrue
    }

    It 'adds a new combination when no existing combination matches' {
        $config = @{
            axes = [ordered]@{ os = @('ubuntu-latest') }
            include = @(
                @{ os = 'macos-latest'; experimental = $true }
            )
        }
        $result = New-EnvironmentMatrix -Configuration $config | ConvertFrom-Json
        $result.size | Should -Be 2
        ($result.matrix.include | Where-Object { $_.os -eq 'macos-latest' }).experimental | Should -BeTrue
    }
}

Describe 'New-EnvironmentMatrix - fail-fast and max-parallel' {

    It 'defaults fail-fast to true and max-parallel to combination count' {
        $config = @{ axes = [ordered]@{ os = @('ubuntu-latest', 'windows-latest') } }
        $result = New-EnvironmentMatrix -Configuration $config | ConvertFrom-Json
        $result.'fail-fast'    | Should -BeTrue
        $result.'max-parallel' | Should -Be 2
    }

    It 'passes through fail-fast=false and explicit max-parallel' {
        $config = @{
            axes           = [ordered]@{ os = @('ubuntu-latest', 'windows-latest') }
            'fail-fast'    = $false
            'max-parallel' = 1
        }
        $result = New-EnvironmentMatrix -Configuration $config | ConvertFrom-Json
        $result.'fail-fast'    | Should -BeFalse
        $result.'max-parallel' | Should -Be 1
    }
}

Describe 'New-EnvironmentMatrix - max-size validation' {

    It 'throws when the matrix size exceeds MaxSize' {
        $config = @{
            axes = [ordered]@{
                a = 1..10
                b = 1..10
            }
        }
        { New-EnvironmentMatrix -Configuration $config -MaxSize 50 } |
            Should -Throw -ExpectedMessage '*exceeds*'
    }

    It 'reads max-size from the configuration when present' {
        $config = @{
            axes       = [ordered]@{ a = 1..3; b = 1..3 }
            'max-size' = 4
        }
        { New-EnvironmentMatrix -Configuration $config } |
            Should -Throw -ExpectedMessage '*exceeds*'
    }

    It 'allows matrices exactly at the limit' {
        $config = @{ axes = [ordered]@{ a = 1..2; b = 1..2 } }
        { New-EnvironmentMatrix -Configuration $config -MaxSize 4 } | Should -Not -Throw
    }
}

Describe 'New-EnvironmentMatrix - input validation' {

    It 'throws when configuration has no axes' {
        { New-EnvironmentMatrix -Configuration @{} } | Should -Throw -ExpectedMessage '*axes*'
    }

    It 'throws when axes is empty' {
        { New-EnvironmentMatrix -Configuration @{ axes = @{} } } |
            Should -Throw -ExpectedMessage '*axes*'
    }

    It 'accepts JSON input via -Json' {
        $json = '{"axes":{"os":["ubuntu-latest"]}}'
        $result = New-EnvironmentMatrix -Json $json | ConvertFrom-Json
        $result.size | Should -Be 1
    }

    It 'accepts a file path via -Path' {
        $tmp = New-TemporaryFile
        try {
            '{"axes":{"os":["ubuntu-latest","windows-latest"]}}' | Set-Content -LiteralPath $tmp.FullName
            $result = New-EnvironmentMatrix -Path $tmp.FullName | ConvertFrom-Json
            $result.size | Should -Be 2
        } finally {
            Remove-Item -LiteralPath $tmp.FullName -ErrorAction SilentlyContinue
        }
    }

    It 'throws on missing file' {
        { New-EnvironmentMatrix -Path '/nonexistent/file/path.json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws on invalid JSON' {
        { New-EnvironmentMatrix -Json 'not-json' } |
            Should -Throw -ExpectedMessage '*Invalid configuration JSON*'
    }
}

Describe 'New-EnvironmentMatrix - JSON output shape' {

    It 'produces JSON consumable by GitHub Actions strategy.matrix' {
        $config = @{
            axes = [ordered]@{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @(18, 20)
            }
            'fail-fast'    = $false
            'max-parallel' = 2
        }
        $json = New-EnvironmentMatrix -Configuration $config
        # Must be valid JSON
        { $json | ConvertFrom-Json } | Should -Not -Throw
        $obj = $json | ConvertFrom-Json
        # Required top-level keys
        $obj.PSObject.Properties.Name | Should -Contain 'fail-fast'
        $obj.PSObject.Properties.Name | Should -Contain 'max-parallel'
        $obj.PSObject.Properties.Name | Should -Contain 'matrix'
        $obj.PSObject.Properties.Name | Should -Contain 'size'
        # Matrix has an include array
        $obj.matrix.include | Should -Not -BeNullOrEmpty
    }
}
