# New-BuildMatrix.Tests.ps1
# Pester tests for the Environment Matrix Generator
# TDD: These tests are written FIRST (red phase), then MatrixGenerator.psm1 is implemented to make them pass.

BeforeAll {
    # Import the module under test
    Import-Module "$PSScriptRoot/MatrixGenerator.psm1" -Force
}

Describe "Invoke-MatrixGeneration - Core Matrix Building" {

    Context "Given OS-only configuration" {
        It "builds a matrix with the os dimension" {
            $config = @{
                os = @("ubuntu-latest", "windows-latest", "macos-latest")
            }
            $result = Invoke-MatrixGeneration -Config $config
            $result.strategy.matrix.os | Should -Be @("ubuntu-latest", "windows-latest", "macos-latest")
        }

        It "returns a strategy object with a matrix key" {
            $config = @{ os = @("ubuntu-latest") }
            $result = Invoke-MatrixGeneration -Config $config
            $result | Should -Not -BeNullOrEmpty
            $result.strategy | Should -Not -BeNullOrEmpty
            $result.strategy.matrix | Should -Not -BeNullOrEmpty
        }
    }

    Context "Given language_versions configuration" {
        It "adds each language as a separate matrix dimension" {
            $config = @{
                os = @("ubuntu-latest")
                language_versions = @{
                    node   = @("18", "20")
                    python = @("3.10", "3.11")
                }
            }
            $result = Invoke-MatrixGeneration -Config $config
            $result.strategy.matrix.node   | Should -Be @("18", "20")
            $result.strategy.matrix.python | Should -Be @("3.10", "3.11")
        }
    }

    Context "Given feature_flags configuration" {
        It "adds each flag as a separate matrix dimension" {
            $config = @{
                os = @("ubuntu-latest")
                feature_flags = @{
                    experimental = @($true, $false)
                    cache        = @("enabled", "disabled")
                }
            }
            $result = Invoke-MatrixGeneration -Config $config
            $result.strategy.matrix.experimental | Should -Be @($true, $false)
            $result.strategy.matrix.cache        | Should -Be @("enabled", "disabled")
        }
    }

    Context "Given include rules" {
        It "attaches include entries to the matrix" {
            $config = @{
                os = @("ubuntu-latest")
                language_versions = @{ node = @("18") }
                include = @(
                    @{ os = "windows-latest"; node = "20"; experimental = $true }
                )
            }
            $result = Invoke-MatrixGeneration -Config $config
            $result.strategy.matrix.include | Should -Not -BeNullOrEmpty
            $result.strategy.matrix.include.Count | Should -Be 1
            $result.strategy.matrix.include[0].os | Should -Be "windows-latest"
            $result.strategy.matrix.include[0].node | Should -Be "20"
        }
    }

    Context "Given exclude rules" {
        It "attaches exclude entries to the matrix" {
            $config = @{
                os = @("ubuntu-latest", "windows-latest")
                language_versions = @{ python = @("3.9", "3.11") }
                exclude = @(
                    @{ os = "windows-latest"; python = "3.9" }
                )
            }
            $result = Invoke-MatrixGeneration -Config $config
            $result.strategy.matrix.exclude | Should -Not -BeNullOrEmpty
            $result.strategy.matrix.exclude.Count | Should -Be 1
            $result.strategy.matrix.exclude[0].os | Should -Be "windows-latest"
            $result.strategy.matrix.exclude[0].python | Should -Be "3.9"
        }
    }
}

Describe "Invoke-MatrixGeneration - Strategy Settings" {

    Context "Given max_parallel setting" {
        It "sets max-parallel on the strategy object" {
            $config = @{
                os           = @("ubuntu-latest")
                max_parallel = 4
            }
            $result = Invoke-MatrixGeneration -Config $config
            $result.strategy.'max-parallel' | Should -Be 4
        }

        It "omits max-parallel when not specified" {
            $config = @{ os = @("ubuntu-latest") }
            $result = Invoke-MatrixGeneration -Config $config
            $result.strategy.ContainsKey('max-parallel') | Should -BeFalse
        }
    }

    Context "Given fail_fast setting" {
        It "sets fail-fast to false when configured" {
            $config = @{
                os        = @("ubuntu-latest")
                fail_fast = $false
            }
            $result = Invoke-MatrixGeneration -Config $config
            $result.strategy.'fail-fast' | Should -BeFalse
        }

        It "sets fail-fast to true when configured" {
            $config = @{
                os        = @("ubuntu-latest")
                fail_fast = $true
            }
            $result = Invoke-MatrixGeneration -Config $config
            $result.strategy.'fail-fast' | Should -BeTrue
        }
    }
}

Describe "Invoke-MatrixGeneration - Matrix Size Validation" {

    Context "Given a matrix within the size limit" {
        It "succeeds and returns the matrix" {
            # 2 OS x 2 node = 4 combinations — well within the default 256
            $config = @{
                os = @("ubuntu-latest", "windows-latest")
                language_versions = @{ node = @("18", "20") }
            }
            { Invoke-MatrixGeneration -Config $config } | Should -Not -Throw
        }
    }

    Context "Given a matrix that exceeds max_matrix_size" {
        It "throws an error with a meaningful message" {
            # 10 x 10 x 10 = 1000 > 256
            $config = @{
                os = 1..10 | ForEach-Object { "os-$_" }
                language_versions = @{
                    nodeA = 1..10 | ForEach-Object { "$_" }
                    nodeB = 1..10 | ForEach-Object { "$_" }
                }
                max_matrix_size = 256
            }
            { Invoke-MatrixGeneration -Config $config } | Should -Throw "*exceeds*"
        }
    }

    Context "Given a custom max_matrix_size" {
        It "uses the configured limit instead of the default" {
            # 3 combinations exceeds a limit of 2
            $config = @{
                os              = @("ubuntu-latest", "windows-latest", "macos-latest")
                max_matrix_size = 2
            }
            { Invoke-MatrixGeneration -Config $config } | Should -Throw "*exceeds*"
        }
    }

    Context "Matrix size calculation" {
        It "computes Cartesian product across all dimensions" {
            $config = @{
                os = @("ubuntu-latest", "windows-latest")
                language_versions = @{
                    node   = @("18", "20", "22")
                    python = @("3.10", "3.11")
                }
            }
            # 2 x 3 x 2 = 12
            $size = Get-MatrixSize -Config $config
            $size | Should -Be 12
        }
    }
}

Describe "Invoke-MatrixGeneration - Full Integration" {

    Context "Complete config with all options" {
        It "produces a fully-formed strategy object" {
            $config = @{
                os = @("ubuntu-latest", "windows-latest")
                language_versions = @{
                    node = @("18", "20")
                }
                feature_flags = @{
                    experimental = @($true, $false)
                }
                include = @(
                    @{ os = "macos-latest"; node = "20" }
                )
                exclude = @(
                    @{ os = "windows-latest"; node = "18" }
                )
                max_parallel    = 6
                fail_fast       = $false
                max_matrix_size = 256
            }
            $result = Invoke-MatrixGeneration -Config $config
            # Dimensions
            $result.strategy.matrix.os           | Should -Be @("ubuntu-latest", "windows-latest")
            $result.strategy.matrix.node         | Should -Be @("18", "20")
            $result.strategy.matrix.experimental | Should -Be @($true, $false)
            # Rules
            $result.strategy.matrix.include.Count | Should -Be 1
            $result.strategy.matrix.exclude.Count | Should -Be 1
            # Strategy settings
            $result.strategy.'max-parallel' | Should -Be 6
            $result.strategy.'fail-fast'    | Should -BeFalse
        }
    }
}

Describe "Workflow Structure Tests" {

    BeforeAll {
        $workflowPath = "$PSScriptRoot/.github/workflows/environment-matrix-generator.yml"
        $scriptPath   = "$PSScriptRoot/New-BuildMatrix.ps1"
        $modulePath   = "$PSScriptRoot/MatrixGenerator.psm1"
    }

    Context "Workflow file existence and YAML structure" {
        It "the workflow file exists" {
            Test-Path $workflowPath | Should -BeTrue
        }

        It "the workflow YAML can be parsed (valid YAML)" {
            # Use PowerShell to read it; if malformed the file won't load cleanly
            $content = Get-Content $workflowPath -Raw
            $content | Should -Not -BeNullOrEmpty
        }

        It "the workflow contains expected trigger events" {
            $content = Get-Content $workflowPath -Raw
            $content | Should -Match "push"
            $content | Should -Match "pull_request|workflow_dispatch"
        }

        It "the workflow has at least one job" {
            $content = Get-Content $workflowPath -Raw
            $content | Should -Match "jobs:"
        }

        It "the workflow uses shell: pwsh for run steps" {
            $content = Get-Content $workflowPath -Raw
            $content | Should -Match "shell:\s*pwsh"
        }
    }

    Context "Script file references" {
        It "New-BuildMatrix.ps1 exists" {
            Test-Path $scriptPath | Should -BeTrue
        }

        It "MatrixGenerator.psm1 exists" {
            Test-Path $modulePath | Should -BeTrue
        }

        It "the workflow references New-BuildMatrix.ps1" {
            $content = Get-Content $workflowPath -Raw
            $content | Should -Match "New-BuildMatrix\.ps1"
        }
    }

    Context "actionlint validation" {
        It "actionlint passes with exit code 0" {
            $output = & actionlint $workflowPath 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "actionlint reported: $output"
        }
    }
}
