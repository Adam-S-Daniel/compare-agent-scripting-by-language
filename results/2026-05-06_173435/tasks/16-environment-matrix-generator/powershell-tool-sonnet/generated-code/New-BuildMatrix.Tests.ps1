#Requires -Modules Pester
<#
.SYNOPSIS
    Pester tests for New-BuildMatrix.ps1 — Environment Matrix Generator
    Written using red/green TDD: each Describe block represents one TDD cycle.
    Tests were written BEFORE the implementation to drive development.
#>

BeforeAll {
    # Dot-source the script to import the New-BuildMatrix function.
    # This is the TDD "red" setup — tests will fail until the implementation exists.
    . "$PSScriptRoot/New-BuildMatrix.ps1"
}

# =============================================================================
# TDD CYCLE 1 (Red then Green): Basic matrix generation
# Written first with no implementation — initially fails.
# =============================================================================
Describe "New-BuildMatrix - Basic Matrix Generation" {
    It "generates matrix with a single OS dimension" {
        $config = @{
            os = @("ubuntu-latest", "windows-latest", "macos-latest")
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.os | Should -BeExactly @("ubuntu-latest", "windows-latest", "macos-latest")
    }

    It "generates matrix with OS and python-version dimensions" {
        $config = @{
            os             = @("ubuntu-latest", "windows-latest")
            "python-version" = @("3.9", "3.10", "3.11")
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.os | Should -BeExactly @("ubuntu-latest", "windows-latest")
        $result.matrix."python-version" | Should -BeExactly @("3.9", "3.10", "3.11")
    }

    It "generates matrix with node-version dimension" {
        $config = @{
            os             = @("ubuntu-latest")
            "node-version" = @("18", "20")
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix."node-version" | Should -BeExactly @("18", "20")
    }

    It "generates matrix with custom feature-flag dimension" {
        $config = @{
            os       = @("ubuntu-latest")
            features = @("feature-a", "feature-b", "feature-c")
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.features | Should -BeExactly @("feature-a", "feature-b", "feature-c")
    }

    It "returns a result with a 'matrix' key" {
        $config = @{ os = @("ubuntu-latest") }
        $result = New-BuildMatrix -Config $config
        $result | Should -Not -BeNullOrEmpty
        $result.matrix | Should -Not -BeNullOrEmpty
    }
}

# =============================================================================
# TDD CYCLE 2 (Red then Green): Include and exclude rules
# =============================================================================
Describe "New-BuildMatrix - Include/Exclude Rules" {
    It "passes include rules through to the matrix output" {
        $include = @(
            @{ os = "macos-latest"; "python-version" = "3.12"; experimental = $true }
        )
        $config = @{
            os             = @("ubuntu-latest", "windows-latest")
            "python-version" = @("3.9", "3.10")
            include        = $include
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 1
        $result.matrix.include[0].os | Should -Be "macos-latest"
    }

    It "passes exclude rules through to the matrix output" {
        $exclude = @(
            @{ os = "windows-latest"; "python-version" = "3.9" }
        )
        $config = @{
            os             = @("ubuntu-latest", "windows-latest")
            "python-version" = @("3.9", "3.10")
            exclude        = $exclude
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.exclude.Count | Should -Be 1
        $result.matrix.exclude[0].os | Should -Be "windows-latest"
    }

    It "supports multiple include entries" {
        $include = @(
            @{ os = "macos-latest"; experimental = $true }
            @{ os = "ubuntu-latest"; "extra-feature" = "enabled" }
        )
        $config = @{
            os      = @("ubuntu-latest")
            include = $include
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 2
    }

    It "omits include key when not provided" {
        $config = @{ os = @("ubuntu-latest") }
        $result = New-BuildMatrix -Config $config
        $result.matrix.ContainsKey("include") | Should -Be $false
    }

    It "omits exclude key when not provided" {
        $config = @{ os = @("ubuntu-latest") }
        $result = New-BuildMatrix -Config $config
        $result.matrix.ContainsKey("exclude") | Should -Be $false
    }
}

# =============================================================================
# TDD CYCLE 3 (Red then Green): max-parallel and fail-fast configuration
# =============================================================================
Describe "New-BuildMatrix - Max-Parallel and Fail-Fast" {
    It "includes max-parallel at the top level of the result" {
        $config = @{
            os             = @("ubuntu-latest", "windows-latest")
            "max-parallel" = 5
        }
        $result = New-BuildMatrix -Config $config
        $result."max-parallel" | Should -Be 5
    }

    It "includes fail-fast=false at the top level of the result" {
        $config = @{
            os          = @("ubuntu-latest")
            "fail-fast" = $false
        }
        $result = New-BuildMatrix -Config $config
        $result."fail-fast" | Should -Be $false
    }

    It "includes fail-fast=true at the top level of the result" {
        $config = @{
            os          = @("ubuntu-latest")
            "fail-fast" = $true
        }
        $result = New-BuildMatrix -Config $config
        $result."fail-fast" | Should -Be $true
    }

    It "omits max-parallel when not provided" {
        $config = @{ os = @("ubuntu-latest") }
        $result = New-BuildMatrix -Config $config
        $result.ContainsKey("max-parallel") | Should -Be $false
    }

    It "omits fail-fast when not provided" {
        $config = @{ os = @("ubuntu-latest") }
        $result = New-BuildMatrix -Config $config
        $result.ContainsKey("fail-fast") | Should -Be $false
    }

    It "does not include max-parallel inside the matrix key" {
        $config = @{
            os             = @("ubuntu-latest")
            "max-parallel" = 3
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.ContainsKey("max-parallel") | Should -Be $false
    }
}

# =============================================================================
# TDD CYCLE 4 (Red then Green): Matrix size validation
# =============================================================================
Describe "New-BuildMatrix - Matrix Size Validation" {
    It "throws when matrix size exceeds max-size" {
        $config = @{
            os             = @("ubuntu-latest", "windows-latest", "macos-latest")
            "python-version" = @("3.8", "3.9", "3.10", "3.11")
            "node-version"   = @("14", "16", "18", "20")
            "max-size"       = 10  # 3 x 4 x 4 = 48, exceeds 10
        }
        { New-BuildMatrix -Config $config } | Should -Throw "*exceeds maximum*"
    }

    It "succeeds when matrix size is exactly at max-size" {
        $config = @{
            os             = @("ubuntu-latest", "windows-latest")
            "python-version" = @("3.9", "3.10", "3.11")
            "max-size"       = 6  # 2 x 3 = 6, exactly at limit
        }
        { New-BuildMatrix -Config $config } | Should -Not -Throw
    }

    It "succeeds when matrix size is below max-size" {
        $config = @{
            os             = @("ubuntu-latest", "windows-latest")
            "python-version" = @("3.9", "3.10")
            "max-size"       = 256
        }
        { New-BuildMatrix -Config $config } | Should -Not -Throw
    }

    It "does not include max-size in the matrix output" {
        $config = @{
            os         = @("ubuntu-latest")
            "max-size" = 50
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.ContainsKey("max-size") | Should -Be $false
        $result.ContainsKey("max-size") | Should -Be $false
    }

    It "correctly calculates matrix size for single-dimension config" {
        # 3 OS x 1 = 3, well within max-size=5
        $config = @{
            os         = @("ubuntu-latest", "windows-latest", "macos-latest")
            "max-size" = 5
        }
        { New-BuildMatrix -Config $config } | Should -Not -Throw
    }

    It "throws with a meaningful error message containing the actual and max sizes" {
        $config = @{
            os         = @("ubuntu-latest", "windows-latest")
            features   = @("a", "b", "c")
            "max-size" = 5  # 2 x 3 = 6, exceeds 5
        }
        { New-BuildMatrix -Config $config } | Should -Throw "*6*"
    }
}

# =============================================================================
# TDD CYCLE 5 (Red then Green): Full integration — combined config
# =============================================================================
Describe "New-BuildMatrix - Full Integration" {
    It "generates a complete matrix with all options set" {
        $config = @{
            os               = @("ubuntu-latest", "windows-latest")
            "python-version" = @("3.9", "3.10")
            include          = @(@{ os = "macos-latest"; "python-version" = "3.11" })
            exclude          = @(@{ os = "windows-latest"; "python-version" = "3.9" })
            "max-parallel"   = 4
            "fail-fast"      = $false
            "max-size"       = 20
        }
        $result = New-BuildMatrix -Config $config

        # matrix dimensions
        $result.matrix.os | Should -BeExactly @("ubuntu-latest", "windows-latest")
        $result.matrix."python-version" | Should -BeExactly @("3.9", "3.10")

        # include/exclude
        $result.matrix.include.Count | Should -Be 1
        $result.matrix.exclude.Count | Should -Be 1

        # strategy options
        $result."max-parallel" | Should -Be 4
        $result."fail-fast" | Should -Be $false
    }

    It "generates valid JSON output" {
        $config = @{
            os               = @("ubuntu-latest")
            "python-version" = @("3.9")
        }
        $result = New-BuildMatrix -Config $config
        # Should convert to JSON without error
        $json = $result | ConvertTo-Json -Depth 10
        $json | Should -Not -BeNullOrEmpty
        # Should be parseable back to JSON
        { $json | ConvertFrom-Json } | Should -Not -Throw
    }
}

# =============================================================================
# WORKFLOW STRUCTURE TESTS (run inside act via the workflow, or directly)
# =============================================================================
Describe "Workflow Structure Validation" {
    It "workflow file exists at .github/workflows/environment-matrix-generator.yml" {
        $workflowPath = Join-Path $PSScriptRoot ".github/workflows/environment-matrix-generator.yml"
        Test-Path $workflowPath | Should -Be $true
    }

    It "main script New-BuildMatrix.ps1 exists" {
        $scriptPath = Join-Path $PSScriptRoot "New-BuildMatrix.ps1"
        Test-Path $scriptPath | Should -Be $true
    }

    It "workflow references New-BuildMatrix.ps1 which exists" {
        $workflowPath = Join-Path $PSScriptRoot ".github/workflows/environment-matrix-generator.yml"
        $workflowContent = Get-Content $workflowPath -Raw
        $workflowContent | Should -Match "New-BuildMatrix\.ps1"
    }

    It "workflow has push trigger" {
        $workflowPath = Join-Path $PSScriptRoot ".github/workflows/environment-matrix-generator.yml"
        $workflowContent = Get-Content $workflowPath -Raw
        $workflowContent | Should -Match "push:"
    }

    It "workflow has workflow_dispatch trigger" {
        $workflowPath = Join-Path $PSScriptRoot ".github/workflows/environment-matrix-generator.yml"
        $workflowContent = Get-Content $workflowPath -Raw
        $workflowContent | Should -Match "workflow_dispatch"
    }

    It "workflow uses pwsh shell for PowerShell steps" {
        $workflowPath = Join-Path $PSScriptRoot ".github/workflows/environment-matrix-generator.yml"
        $workflowContent = Get-Content $workflowPath -Raw
        $workflowContent | Should -Match "shell: pwsh"
    }

    It "workflow uses actions/checkout" {
        $workflowPath = Join-Path $PSScriptRoot ".github/workflows/environment-matrix-generator.yml"
        $workflowContent = Get-Content $workflowPath -Raw
        $workflowContent | Should -Match "actions/checkout"
    }
}
