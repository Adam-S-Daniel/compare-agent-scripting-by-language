# New-BuildMatrix.Tests.ps1
# Pester tests for the Environment Matrix Generator
# Uses Red/Green TDD: write failing tests first, then implement the minimum code to pass

BeforeAll {
    # Dot-source the script to load functions for unit testing.
    # $ConfigFile defaults to "" so the main execution block is skipped.
    . "$PSScriptRoot/New-BuildMatrix.ps1"
}

Describe "Get-MatrixSize" {

    It "returns 1 for empty dimensions" {
        $dims = @{}
        Get-MatrixSize -Dimensions $dims | Should -Be 1
    }

    It "calculates size for a single dimension" {
        $dims = @{ os = @("ubuntu-latest", "windows-latest") }
        Get-MatrixSize -Dimensions $dims | Should -Be 2
    }

    It "calculates the cartesian product for multiple dimensions" {
        $dims = @{
            os   = @("ubuntu-latest", "windows-latest")
            node = @("18", "20", "22")
        }
        Get-MatrixSize -Dimensions $dims | Should -Be 6
    }

    It "handles three dimensions" {
        $dims = @{
            os     = @("ubuntu-latest", "windows-latest")
            node   = @("18", "20", "22")
            debug  = @($true, $false)
        }
        Get-MatrixSize -Dimensions $dims | Should -Be 12
    }
}

Describe "Invoke-MatrixGenerator" {

    Context "Basic matrix generation" {

        It "generates a matrix with only an OS dimension" {
            $config = @{ os = @("ubuntu-latest", "windows-latest") }
            $result = Invoke-MatrixGenerator -Config $config
            $result.strategy.matrix['os'] | Should -Be @("ubuntu-latest", "windows-latest")
        }

        It "generates a matrix with a version dimension from the versions key" {
            $config = @{
                versions = @{ node = @("18", "20", "22") }
            }
            $result = Invoke-MatrixGenerator -Config $config
            $result.strategy.matrix['node'] | Should -Be @("18", "20", "22")
        }

        It "generates a matrix with multiple version dimensions" {
            $config = @{
                versions = @{
                    node   = @("18", "20")
                    python = @("3.10", "3.11")
                }
            }
            $result = Invoke-MatrixGenerator -Config $config
            $result.strategy.matrix['node']   | Should -Be @("18", "20")
            $result.strategy.matrix['python'] | Should -Be @("3.10", "3.11")
        }

        It "generates a matrix with feature flag dimensions" {
            $config = @{
                features = @{ experimental = @($true, $false) }
            }
            $result = Invoke-MatrixGenerator -Config $config
            $result.strategy.matrix['experimental'] | Should -Be @($true, $false)
        }

        It "combines OS, version, and feature dimensions" {
            $config = @{
                os       = @("ubuntu-latest", "windows-latest")
                versions = @{ node = @("18", "20") }
                features = @{ debug = @($true, $false) }
            }
            $result = Invoke-MatrixGenerator -Config $config
            $result.strategy.matrix['os']    | Should -HaveCount 2
            $result.strategy.matrix['node']  | Should -HaveCount 2
            $result.strategy.matrix['debug'] | Should -HaveCount 2
        }
    }

    Context "Strategy configuration" {

        It "defaults fail-fast to false when not specified" {
            $config = @{ os = @("ubuntu-latest") }
            $result = Invoke-MatrixGenerator -Config $config
            $result.strategy['fail-fast'] | Should -Be $false
        }

        It "sets fail-fast to true when specified" {
            $config = @{
                os       = @("ubuntu-latest")
                failFast = $true
            }
            $result = Invoke-MatrixGenerator -Config $config
            $result.strategy['fail-fast'] | Should -Be $true
        }

        It "sets fail-fast to false when explicitly set to false" {
            $config = @{
                os       = @("ubuntu-latest")
                failFast = $false
            }
            $result = Invoke-MatrixGenerator -Config $config
            $result.strategy['fail-fast'] | Should -Be $false
        }

        It "sets max-parallel when specified" {
            $config = @{
                os          = @("ubuntu-latest")
                maxParallel = 4
            }
            $result = Invoke-MatrixGenerator -Config $config
            $result.strategy['max-parallel'] | Should -Be 4
        }

        It "omits max-parallel key when not specified" {
            $config = @{ os = @("ubuntu-latest") }
            $result = Invoke-MatrixGenerator -Config $config
            $result.strategy.Contains('max-parallel') | Should -Be $false
        }
    }

    Context "Include and Exclude rules" {

        It "passes a single include entry to the matrix" {
            $config = @{
                os      = @("ubuntu-latest", "windows-latest")
                include = @( @{ os = "ubuntu-latest"; extra = "custom-value" } )
            }
            $result = Invoke-MatrixGenerator -Config $config
            $result.strategy.matrix['include'] | Should -HaveCount 1
            $result.strategy.matrix['include'][0]['extra'] | Should -Be "custom-value"
        }

        It "passes a single exclude entry to the matrix" {
            $config = @{
                os      = @("ubuntu-latest", "windows-latest")
                exclude = @( @{ os = "windows-latest" } )
            }
            $result = Invoke-MatrixGenerator -Config $config
            $result.strategy.matrix['exclude'] | Should -HaveCount 1
            $result.strategy.matrix['exclude'][0]['os'] | Should -Be "windows-latest"
        }

        It "supports multiple include entries" {
            $config = @{
                os      = @("ubuntu-latest")
                include = @(
                    @{ os = "ubuntu-latest"; node = "22"; tag = "latest" }
                    @{ os = "macos-latest"; node = "20" }
                )
            }
            $result = Invoke-MatrixGenerator -Config $config
            $result.strategy.matrix['include'] | Should -HaveCount 2
            $result.strategy.matrix['include'][0]['tag'] | Should -Be "latest"
        }

        It "supports multiple exclude entries" {
            $config = @{
                os       = @("ubuntu-latest", "windows-latest")
                versions = @{ node = @("18", "20") }
                exclude  = @(
                    @{ os = "windows-latest"; node = "18" }
                    @{ os = "windows-latest"; node = "20" }
                )
            }
            $result = Invoke-MatrixGenerator -Config $config
            $result.strategy.matrix['exclude'] | Should -HaveCount 2
        }

        It "omits include key when not specified" {
            $config = @{ os = @("ubuntu-latest") }
            $result = Invoke-MatrixGenerator -Config $config
            $result.strategy.matrix.Contains('include') | Should -Be $false
        }

        It "omits exclude key when not specified" {
            $config = @{ os = @("ubuntu-latest") }
            $result = Invoke-MatrixGenerator -Config $config
            $result.strategy.matrix.Contains('exclude') | Should -Be $false
        }
    }

    Context "Matrix size validation" {

        It "throws when the computed size exceeds maxMatrixSize" {
            $config = @{
                os            = @("ubuntu-latest", "windows-latest", "macos-latest")
                versions      = @{ node = @("18", "20", "22") }
                maxMatrixSize = 5
                # 3 x 3 = 9 combinations, exceeds limit of 5
            }
            { Invoke-MatrixGenerator -Config $config } | Should -Throw "*exceeds maximum*"
        }

        It "succeeds when size equals maxMatrixSize exactly" {
            $config = @{
                os            = @("ubuntu-latest", "windows-latest")
                versions      = @{ node = @("18", "20") }
                maxMatrixSize = 4
                # 2 x 2 = 4, exactly at limit
            }
            { Invoke-MatrixGenerator -Config $config } | Should -Not -Throw
        }

        It "succeeds when size is within the default limit of 256" {
            $config = @{
                os       = @("ubuntu-latest", "windows-latest")
                versions = @{ node = @("18", "20", "22") }
                # 2 x 3 = 6, well within 256
            }
            { Invoke-MatrixGenerator -Config $config } | Should -Not -Throw
        }

        It "uses the MaxSize parameter when config does not specify maxMatrixSize" {
            $config = @{
                os       = @("ubuntu-latest", "windows-latest", "macos-latest")
                versions = @{ node = @("18", "20", "22") }
                # 3 x 3 = 9 combinations
            }
            { Invoke-MatrixGenerator -Config $config -MaxSize 5 } | Should -Throw "*exceeds maximum*"
        }

        It "config maxMatrixSize overrides the MaxSize parameter" {
            $config = @{
                os            = @("ubuntu-latest", "windows-latest")
                versions      = @{ node = @("18", "20") }
                maxMatrixSize = 10   # config says 10
                # 2 x 2 = 4, fine
            }
            # Even though MaxSize=2 is smaller, config wins
            { Invoke-MatrixGenerator -Config $config -MaxSize 2 } | Should -Not -Throw
        }
    }
}

Describe "New-BuildMatrix.ps1 end-to-end (file input)" {

    Context "Valid configuration files" {

        It "processes the basic fixture and produces correct matrix" {
            $fixturePath = "$PSScriptRoot/fixtures/basic-config.json"
            $output = & "$PSScriptRoot/New-BuildMatrix.ps1" -ConfigFile $fixturePath
            $result = $output | ConvertFrom-Json

            $result.strategy.matrix.os   | Should -Contain "ubuntu-latest"
            $result.strategy.matrix.os   | Should -Contain "windows-latest"
            $result.strategy.matrix.node | Should -Contain "18"
            $result.strategy.matrix.node | Should -Contain "20"
            $result.strategy.'fail-fast'    | Should -Be $false
            $result.strategy.'max-parallel' | Should -Be 4
        }

        It "processes the full fixture with include/exclude and produces correct matrix" {
            $fixturePath = "$PSScriptRoot/fixtures/full-config.json"
            $output = & "$PSScriptRoot/New-BuildMatrix.ps1" -ConfigFile $fixturePath
            $result = $output | ConvertFrom-Json

            $result.strategy.matrix.os | Should -Contain "ubuntu-latest"
            $result.strategy.matrix.os | Should -Contain "windows-latest"
            $result.strategy.matrix.os | Should -Contain "macos-latest"

            # Include entry should carry the 'tag' property
            $result.strategy.matrix.include | Should -HaveCount 1
            $result.strategy.matrix.include[0].tag | Should -Be "latest"

            # Exclude entry should reference windows+node18
            $result.strategy.matrix.exclude | Should -HaveCount 1
            $result.strategy.matrix.exclude[0].os   | Should -Be "windows-latest"
            $result.strategy.matrix.exclude[0].node | Should -Be "18"

            $result.strategy.'fail-fast'    | Should -Be $true
            $result.strategy.'max-parallel' | Should -Be 10
        }
    }

    Context "Error handling" {

        # When Pester runs with $EAP=Continue (host): Write-Error outputs to
        # error stream, then exit 1 sets $LASTEXITCODE=1. When Pester runs with
        # $EAP=Stop (Docker container): Write-Error propagates as an exception
        # before exit 1. Either way the script failed — we catch both signals.

        It "fails when config file does not exist" {
            $threw = $false
            try {
                & "$PSScriptRoot/New-BuildMatrix.ps1" -ConfigFile "nonexistent-file.json" 2>&1 |
                    Out-Null
            }
            catch { $threw = $true }
            ($threw -or ($LASTEXITCODE -gt 0)) | Should -Be $true
        }

        It "fails when matrix size exceeds the configured maximum" {
            $config = @{
                os            = @("ubuntu-latest", "windows-latest", "macos-latest")
                versions      = @{ node = @("18", "20", "22") }
                maxMatrixSize = 5
            } | ConvertTo-Json -Depth 5

            $tmpFile = [System.IO.Path]::ChangeExtension(
                [System.IO.Path]::GetTempFileName(), ".json")
            $config | Set-Content -Path $tmpFile
            try {
                $threw = $false
                try {
                    & "$PSScriptRoot/New-BuildMatrix.ps1" -ConfigFile $tmpFile 2>&1 | Out-Null
                }
                catch { $threw = $true }
                ($threw -or ($LASTEXITCODE -gt 0)) | Should -Be $true
            }
            finally { Remove-Item $tmpFile -ErrorAction SilentlyContinue }
        }
    }
}

Describe "Workflow structure" {

    BeforeAll {
        $script:wfPath = "$PSScriptRoot/.github/workflows/environment-matrix-generator.yml"
    }

    It "workflow file exists" {
        Test-Path $script:wfPath | Should -Be $true
    }

    It "workflow references New-BuildMatrix.ps1" {
        $content = Get-Content $script:wfPath -Raw
        $content | Should -Match "New-BuildMatrix\.ps1"
    }

    It "workflow has a push trigger" {
        $content = Get-Content $script:wfPath -Raw
        $content | Should -Match "push:"
    }

    It "workflow has a pull_request trigger" {
        $content = Get-Content $script:wfPath -Raw
        $content | Should -Match "pull_request"
    }

    It "workflow uses shell: pwsh for PowerShell steps" {
        $content = Get-Content $script:wfPath -Raw
        $content | Should -Match "shell:\s*pwsh"
    }

    It "workflow uses actions/checkout" {
        $content = Get-Content $script:wfPath -Raw
        $content | Should -Match "actions/checkout"
    }

    It "fixture files referenced by the workflow exist" {
        Test-Path "$PSScriptRoot/fixtures/basic-config.json" | Should -Be $true
        Test-Path "$PSScriptRoot/fixtures/full-config.json"  | Should -Be $true
    }

    It "passes actionlint validation" {
        $al = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $al) {
            Set-ItResult -Skipped -Because "actionlint not available in this environment"
            return
        }
        & actionlint $script:wfPath 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}
