# New-BuildMatrix.Tests.ps1
# Pester test suite for the Environment Matrix Generator
# TDD: tests are written first (RED), then implementation makes them pass (GREEN)

BeforeAll {
    . "$PSScriptRoot/New-BuildMatrix.ps1"
}

# ===== Get-MatrixSize =====

Describe "Get-MatrixSize" {
    It "Should return 1 for empty dimensions" {
        Get-MatrixSize -Dimensions @{} | Should -Be 1
    }

    It "Should return count for single dimension" {
        Get-MatrixSize -Dimensions @{ os = @("ubuntu-latest", "windows-latest") } | Should -Be 2
    }

    It "Should return cartesian product for multiple dimensions" {
        $dims = @{
            os      = @("ubuntu-latest", "windows-latest")
            version = @("3.10", "3.11", "3.12")
        }
        Get-MatrixSize -Dimensions $dims | Should -Be 6
    }

    It "Should return product for three dimensions" {
        $dims = @{
            os         = @("ubuntu-latest", "windows-latest")
            version    = @("1.0", "2.0")
            feature    = @("a", "b", "c")
        }
        Get-MatrixSize -Dimensions $dims | Should -Be 12
    }
}

# ===== New-BuildMatrix - Basic generation =====

Describe "New-BuildMatrix - Basic matrix generation" {
    It "Should generate matrix with dimension arrays" {
        $config = @{
            dimensions = @{
                os             = @("ubuntu-latest", "windows-latest")
                "python-version" = @("3.10", "3.11")
            }
            maxParallel = 4
            failFast    = $false
            maxSize     = 256
        }

        $result = New-BuildMatrix -Config $config

        $result | Should -Not -BeNullOrEmpty
        $result.matrix.os | Should -Contain "ubuntu-latest"
        $result.matrix.os | Should -Contain "windows-latest"
        $result.matrix."python-version" | Should -Contain "3.10"
        $result.matrix."python-version" | Should -Contain "3.11"
    }

    It "Should include matrix-size in result" {
        $config = @{
            dimensions = @{
                os      = @("ubuntu-latest", "windows-latest")
                version = @("3.10", "3.11")
            }
            maxSize = 256
        }

        $result = New-BuildMatrix -Config $config
        $result."matrix-size" | Should -Be 4
    }

    It "Should set max-parallel when specified" {
        $config = @{
            dimensions = @{ os = @("ubuntu-latest", "windows-latest") }
            maxParallel = 4
            maxSize     = 256
        }

        $result = New-BuildMatrix -Config $config
        $result."max-parallel" | Should -Be 4
    }

    It "Should omit max-parallel when not specified" {
        $config = @{
            dimensions = @{ os = @("ubuntu-latest") }
            maxSize    = 256
        }

        $result = New-BuildMatrix -Config $config
        $result.ContainsKey("max-parallel") | Should -Be $false
    }

    It "Should set fail-fast to false when specified" {
        $config = @{
            dimensions = @{ os = @("ubuntu-latest", "windows-latest") }
            failFast   = $false
            maxSize    = 256
        }

        $result = New-BuildMatrix -Config $config
        $result."fail-fast" | Should -Be $false
    }

    It "Should default fail-fast to true when not specified" {
        $config = @{
            dimensions = @{ os = @("ubuntu-latest") }
            maxSize    = 256
        }

        $result = New-BuildMatrix -Config $config
        $result."fail-fast" | Should -Be $true
    }
}

# ===== New-BuildMatrix - Include/Exclude rules =====

Describe "New-BuildMatrix - Include and Exclude rules" {
    It "Should include include-rules in matrix" {
        $config = @{
            dimensions = @{
                os      = @("ubuntu-latest", "windows-latest")
                version = @("1.0", "2.0")
            }
            include = @(
                @{ os = "macos-latest"; version = "2.0"; extra = "coverage" }
            )
            maxSize = 256
        }

        $result = New-BuildMatrix -Config $config

        $result.matrix.include | Should -Not -BeNullOrEmpty
        $result.matrix.include[0].os | Should -Be "macos-latest"
        $result.matrix.include[0].extra | Should -Be "coverage"
    }

    It "Should include exclude-rules in matrix" {
        $config = @{
            dimensions = @{
                os      = @("ubuntu-latest", "windows-latest")
                version = @("1.0", "2.0")
            }
            exclude = @(
                @{ os = "windows-latest"; version = "1.0" }
            )
            maxSize = 256
        }

        $result = New-BuildMatrix -Config $config

        $result.matrix.exclude | Should -Not -BeNullOrEmpty
        $result.matrix.exclude[0].os | Should -Be "windows-latest"
        $result.matrix.exclude[0].version | Should -Be "1.0"
    }

    It "Should omit include key when no includes provided" {
        $config = @{
            dimensions = @{ os = @("ubuntu-latest") }
            maxSize    = 256
        }

        $result = New-BuildMatrix -Config $config
        $result.matrix.ContainsKey("include") | Should -Be $false
    }

    It "Should omit exclude key when no excludes provided" {
        $config = @{
            dimensions = @{ os = @("ubuntu-latest") }
            maxSize    = 256
        }

        $result = New-BuildMatrix -Config $config
        $result.matrix.ContainsKey("exclude") | Should -Be $false
    }
}

# ===== New-BuildMatrix - Validation =====

Describe "New-BuildMatrix - Validation" {
    It "Should throw when matrix exceeds maxSize" {
        $config = @{
            dimensions = @{
                os      = @("ubuntu-latest", "windows-latest", "macos-latest")
                version = @("1.0", "2.0", "3.0")
                feature = @("a", "b", "c")
            }
            maxSize = 10
        }

        { New-BuildMatrix -Config $config } | Should -Throw -ExpectedMessage "*exceeds maximum*"
    }

    It "Should not throw when matrix size equals maxSize" {
        $config = @{
            dimensions = @{
                os      = @("ubuntu-latest", "windows-latest")
                version = @("1.0", "2.0", "3.0")
            }
            maxSize = 6
        }

        { New-BuildMatrix -Config $config } | Should -Not -Throw
    }

    It "Should use default maxSize of 256" {
        # 256 dimensions would be a huge config; single dimension should always pass
        $config = @{
            dimensions = @{ os = @("ubuntu-latest") }
        }

        { New-BuildMatrix -Config $config } | Should -Not -Throw
    }

    It "Should throw with descriptive message including actual and max sizes" {
        $config = @{
            dimensions = @{
                os      = @("a", "b", "c")
                version = @("1", "2", "3", "4")
            }
            maxSize = 5
        }

        { New-BuildMatrix -Config $config } | Should -Throw -ExpectedMessage "*12*"
    }
}

# ===== Workflow structure tests =====

Describe "Workflow structure" {
    BeforeAll {
        # In Pester 5, variables set in BeforeAll are accessible in It blocks.
        # We must set $script: scope so they're visible to nested It blocks.
        $script:wfPath = Join-Path $PSScriptRoot ".github" "workflows" "environment-matrix-generator.yml"
        $script:wfContent = if (Test-Path $script:wfPath) {
            Get-Content -Raw $script:wfPath
        } else { "" }
    }

    It "Workflow file should exist" {
        $script:wfPath | Should -Exist
    }

    It "Workflow should have push trigger" {
        $script:wfContent | Should -Match 'push'
    }

    It "Workflow should reference actions/checkout@v4" {
        $script:wfContent | Should -Match 'actions/checkout@v4'
    }

    It "Workflow should use shell: pwsh" {
        $script:wfContent | Should -Match 'shell:\s+pwsh'
    }

    It "Workflow should reference Invoke-MatrixGenerator.ps1" {
        $script:wfContent | Should -Match 'Invoke-MatrixGenerator\.ps1'
    }

    It "Workflow should reference New-BuildMatrix.Tests.ps1" {
        $script:wfContent | Should -Match 'New-BuildMatrix\.Tests\.ps1'
    }

    It "New-BuildMatrix.ps1 should exist" {
        Join-Path $PSScriptRoot "New-BuildMatrix.ps1" | Should -Exist
    }

    It "Invoke-MatrixGenerator.ps1 should exist" {
        Join-Path $PSScriptRoot "Invoke-MatrixGenerator.ps1" | Should -Exist
    }

    It "test-fixtures/test1-basic.json should exist" {
        Join-Path $PSScriptRoot "test-fixtures" "test1-basic.json" | Should -Exist
    }

    It "test-fixtures/test2-includes.json should exist" {
        Join-Path $PSScriptRoot "test-fixtures" "test2-includes.json" | Should -Exist
    }
}
