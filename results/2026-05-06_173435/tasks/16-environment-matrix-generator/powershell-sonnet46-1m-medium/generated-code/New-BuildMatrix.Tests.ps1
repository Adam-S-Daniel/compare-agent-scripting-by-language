# New-BuildMatrix.Tests.ps1 - Pester tests for build matrix generator
# TDD: Tests written first before implementation

BeforeAll {
    # Dot-source the script to load functions without executing
    # Since ConfigPath has no default, we pass nothing — the script only runs main logic when $ConfigPath is set
    . "$PSScriptRoot/New-BuildMatrix.ps1"
}

Describe "Get-CartesianProductCount" {
    It "Returns 1 for single dimension with single value" {
        $dims = @{ os = @("ubuntu-latest") }
        Get-CartesianProductCount -Dimensions $dims | Should -Be 1
    }

    It "Returns correct count for single dimension with multiple values" {
        $dims = @{ os = @("ubuntu-latest", "windows-latest", "macos-latest") }
        Get-CartesianProductCount -Dimensions $dims | Should -Be 3
    }

    It "Returns cartesian product for two dimensions" {
        $dims = @{
            os                  = @("ubuntu-latest", "windows-latest")
            "language-version"  = @("3.10", "3.11")
        }
        Get-CartesianProductCount -Dimensions $dims | Should -Be 4
    }

    It "Returns cartesian product for three dimensions" {
        $dims = @{
            os                  = @("ubuntu-latest", "windows-latest")
            "language-version"  = @("3.10", "3.11")
            cache               = @($true, $false)
        }
        Get-CartesianProductCount -Dimensions $dims | Should -Be 8
    }

    It "Returns 0 for empty dimensions" {
        $dims = @{}
        Get-CartesianProductCount -Dimensions $dims | Should -Be 0
    }
}

Describe "ConvertTo-BuildMatrix" {
    Context "Basic matrix generation" {
        It "Generates matrix with OS dimension" {
            $config = @{ os = @("ubuntu-latest", "windows-latest") }
            $result = ConvertTo-BuildMatrix -Config $config
            $result | Should -Not -BeNull
            $result.matrix | Should -Not -BeNull
            $result.matrix.os | Should -Be @("ubuntu-latest", "windows-latest")
        }

        It "Calculates total combinations for 2x2 matrix" {
            $config = @{
                os                  = @("ubuntu-latest", "windows-latest")
                "language-version"  = @("3.10", "3.11")
            }
            $result = ConvertTo-BuildMatrix -Config $config
            $result.'total-combinations' | Should -Be 4
        }

        It "Calculates total combinations for 3x3 matrix" {
            $config = @{
                os                  = @("ubuntu-latest", "windows-latest", "macos-latest")
                "language-version"  = @("3.10", "3.11", "3.12")
            }
            $result = ConvertTo-BuildMatrix -Config $config
            $result.'total-combinations' | Should -Be 9
        }

        It "Throws error for empty configuration" {
            { ConvertTo-BuildMatrix -Config @{} } | Should -Throw "*at least one matrix dimension*"
        }
    }

    Context "Include rules" {
        It "Include entries appear in the matrix" {
            $config = @{
                os                  = @("ubuntu-latest")
                "language-version"  = @("3.10")
                include             = @(@{ os = "macos-latest"; "language-version" = "3.12"; experimental = $true })
            }
            $result = ConvertTo-BuildMatrix -Config $config
            $result.matrix.include | Should -Not -BeNull
            $result.matrix.include.Count | Should -Be 1
            $result.matrix.include[0].os | Should -Be "macos-latest"
        }

        It "Include entries are counted in total combinations" {
            $config = @{
                os                  = @("ubuntu-latest", "windows-latest")
                "language-version"  = @("3.10", "3.11")
                include             = @(
                    @{ os = "macos-latest"; "language-version" = "3.12" },
                    @{ os = "macos-latest"; "language-version" = "3.11" }
                )
            }
            $result = ConvertTo-BuildMatrix -Config $config
            # 4 base + 2 includes = 6
            $result.'total-combinations' | Should -Be 6
        }
    }

    Context "Exclude rules" {
        It "Exclude entries appear in the matrix" {
            $config = @{
                os                  = @("ubuntu-latest", "windows-latest")
                "language-version"  = @("3.10", "3.11")
                exclude             = @(@{ os = "windows-latest"; "language-version" = "3.10" })
            }
            $result = ConvertTo-BuildMatrix -Config $config
            $result.matrix.exclude | Should -Not -BeNull
            $result.matrix.exclude.Count | Should -Be 1
            $result.matrix.exclude[0].os | Should -Be "windows-latest"
        }
    }

    Context "MaxParallel and FailFast configuration" {
        It "Sets max-parallel in output" {
            $config = @{
                os                  = @("ubuntu-latest", "windows-latest")
                "language-version"  = @("3.10", "3.11")
                maxParallel         = 2
            }
            $result = ConvertTo-BuildMatrix -Config $config
            $result.'max-parallel' | Should -Be 2
        }

        It "Sets fail-fast to true in output" {
            $config = @{
                os       = @("ubuntu-latest")
                failFast = $true
            }
            $result = ConvertTo-BuildMatrix -Config $config
            $result.'fail-fast' | Should -Be $true
        }

        It "Sets fail-fast to false in output" {
            $config = @{
                os       = @("ubuntu-latest")
                failFast = $false
            }
            $result = ConvertTo-BuildMatrix -Config $config
            $result.'fail-fast' | Should -Be $false
        }

        It "Does not include fail-fast when not configured" {
            $config = @{ os = @("ubuntu-latest") }
            $result = ConvertTo-BuildMatrix -Config $config
            # OrderedDictionary uses .Contains(); Hashtable uses .ContainsKey()
            $result.Contains('fail-fast') | Should -Be $false
        }
    }

    Context "Max size validation" {
        It "Does not throw when combinations equal max size" {
            $config = @{
                os                  = @("ubuntu-latest", "windows-latest")
                "language-version"  = @("3.10", "3.11")
                maxSize             = 4
            }
            { ConvertTo-BuildMatrix -Config $config } | Should -Not -Throw
        }

        It "Throws error when matrix exceeds MaxSize parameter" {
            $config = @{
                os                  = @("ubuntu-latest", "windows-latest")
                "language-version"  = @("3.10", "3.11", "3.12")
            }
            # 6 combinations, MaxSize=5
            { ConvertTo-BuildMatrix -Config $config -MaxSize 5 } | Should -Throw "*exceeds the maximum*"
        }

        It "Throws error when matrix exceeds maxSize in config" {
            $config = @{
                os                  = @("ubuntu-latest", "windows-latest")
                "language-version"  = @("3.10", "3.11")
                maxSize             = 3
            }
            { ConvertTo-BuildMatrix -Config $config } | Should -Throw "*exceeds the maximum*"
        }

        It "Counts include entries toward the total when checking max size" {
            $config = @{
                os      = @("ubuntu-latest", "windows-latest")
                include = @(@{ os = "macos-latest" }, @{ os = "freebsd-latest" })
                maxSize = 3
            }
            # 2 base + 2 includes = 4, exceeds maxSize=3
            { ConvertTo-BuildMatrix -Config $config } | Should -Throw "*exceeds the maximum*"
        }
    }

    Context "Feature flags (boolean dimensions)" {
        It "Includes boolean feature flags as matrix dimensions" {
            $config = @{
                os    = @("ubuntu-latest")
                cache = @($true, $false)
            }
            $result = ConvertTo-BuildMatrix -Config $config
            $result.matrix.cache | Should -Not -BeNull
            $result.matrix.cache.Count | Should -Be 2
            $result.'total-combinations' | Should -Be 2
        }

        It "Feature flags participate in cartesian product" {
            $config = @{
                os                  = @("ubuntu-latest", "windows-latest")
                "language-version"  = @("3.10", "3.11")
                experimental        = @($true, $false)
            }
            $result = ConvertTo-BuildMatrix -Config $config
            # 2 × 2 × 2 = 8
            $result.'total-combinations' | Should -Be 8
        }
    }

    Context "Complex scenario with all options" {
        It "Handles all configuration options together" {
            $config = @{
                os                  = @("ubuntu-latest", "windows-latest")
                "language-version"  = @("3.10", "3.11")
                "node-version"      = @("18", "20")
                include             = @(@{ os = "macos-latest"; "language-version" = "3.12"; "node-version" = "20" })
                exclude             = @(@{ os = "windows-latest"; "language-version" = "3.10"; "node-version" = "18" })
                maxParallel         = 4
                failFast            = $false
            }
            $result = ConvertTo-BuildMatrix -Config $config
            # 2 × 2 × 2 = 8 base + 1 include = 9
            $result.'total-combinations' | Should -Be 9
            $result.matrix.os | Should -Be @("ubuntu-latest", "windows-latest")
            $result.matrix.'language-version' | Should -Be @("3.10", "3.11")
            $result.matrix.'node-version' | Should -Be @("18", "20")
            $result.matrix.include.Count | Should -Be 1
            $result.matrix.exclude.Count | Should -Be 1
            $result.'max-parallel' | Should -Be 4
            $result.'fail-fast' | Should -Be $false
        }
    }
}

Describe "Workflow Structure Tests" {
    BeforeAll {
        $script:workflowPath = Join-Path $PSScriptRoot ".github/workflows/environment-matrix-generator.yml"
        $script:scriptPath   = Join-Path $PSScriptRoot "New-BuildMatrix.ps1"
        $script:workflowYaml = Get-Content $script:workflowPath -Raw -ErrorAction SilentlyContinue
    }

    It "Workflow file exists" {
        $script:workflowPath | Should -Exist
    }

    It "Main script file exists" {
        $script:scriptPath | Should -Exist
    }

    It "Workflow has push trigger" {
        $script:workflowYaml | Should -Match "push:"
    }

    It "Workflow has workflow_dispatch trigger" {
        $script:workflowYaml | Should -Match "workflow_dispatch:"
    }

    It "Workflow has at least one job" {
        $script:workflowYaml | Should -Match "jobs:"
    }

    It "Workflow uses actions/checkout" {
        $script:workflowYaml | Should -Match "actions/checkout"
    }

    It "Workflow uses shell: pwsh for run steps" {
        $script:workflowYaml | Should -Match "shell: pwsh"
    }

    It "Workflow references the main script" {
        $script:workflowYaml | Should -Match "New-BuildMatrix.ps1"
    }

    It "Passes actionlint validation" {
        $lintOutput = actionlint $script:workflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint should pass cleanly: $lintOutput"
    }
}
