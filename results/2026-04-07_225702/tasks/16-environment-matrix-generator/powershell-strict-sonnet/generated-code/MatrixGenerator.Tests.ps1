# MatrixGenerator.Tests.ps1
# TDD tests for the GitHub Actions environment matrix generator
# Run with: Invoke-Pester

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    # Import the module under test; $PSScriptRoot is valid inside BeforeAll in Pester 5
    Import-Module (Join-Path $PSScriptRoot 'MatrixGenerator.psm1') -Force
}

Describe 'New-MatrixConfig' {
    # Test 1 (RED): Basic config creation with required fields
    It 'creates a config object with os, language versions, and feature flags' {
        $config = New-MatrixConfig `
            -OsOptions @('ubuntu-latest', 'windows-latest') `
            -LanguageVersions @('3.8', '3.9') `
            -FeatureFlags @('flag1')

        $config.os | Should -Be @('ubuntu-latest', 'windows-latest')
        $config.language_versions | Should -Be @('3.8', '3.9')
        $config.feature_flags | Should -Be @('flag1')
    }

    # Test 2 (RED): Config with default values for optional fields
    It 'sets default values for optional fields' {
        $config = New-MatrixConfig `
            -OsOptions @('ubuntu-latest') `
            -LanguageVersions @('3.9')

        $config.fail_fast | Should -Be $true
        $config.max_parallel | Should -Be 0
        $config.max_size | Should -Be 256
        $config.feature_flags | Should -HaveCount 0
        $config.include_rules | Should -HaveCount 0
        $config.exclude_rules | Should -HaveCount 0
    }

    # Test 3 (RED): Config with all optional fields specified
    It 'accepts all optional fields' {
        $include = @(@{ os = 'ubuntu-latest'; language = '3.11' })
        $exclude = @(@{ os = 'windows-latest'; language = '3.8' })

        $config = New-MatrixConfig `
            -OsOptions @('ubuntu-latest', 'windows-latest') `
            -LanguageVersions @('3.8', '3.9') `
            -FeatureFlags @('flag1', 'flag2') `
            -IncludeRules $include `
            -ExcludeRules $exclude `
            -MaxParallel 4 `
            -FailFast $false `
            -MaxSize 50

        $config.max_parallel | Should -Be 4
        $config.fail_fast | Should -Be $false
        $config.max_size | Should -Be 50
        $config.include_rules | Should -HaveCount 1
        $config.exclude_rules | Should -HaveCount 1
    }

    # Test 4 (RED): Validation - must have at least one OS
    It 'throws when no OS options provided' {
        { New-MatrixConfig -OsOptions @() -LanguageVersions @('3.9') } |
            Should -Throw '*at least one OS*'
    }

    # Test 5 (RED): Validation - must have at least one language version
    It 'throws when no language versions provided' {
        { New-MatrixConfig -OsOptions @('ubuntu-latest') -LanguageVersions @() } |
            Should -Throw '*at least one language version*'
    }
}

Describe 'Get-MatrixCombinations' {
    # Test 6 (RED): Generate combinations from os x language_versions
    It 'generates cartesian product of os x language versions' {
        $config = New-MatrixConfig `
            -OsOptions @('ubuntu-latest', 'windows-latest') `
            -LanguageVersions @('3.8', '3.9')

        $combos = Get-MatrixCombinations -Config $config

        $combos | Should -HaveCount 4
        $combos[0].os | Should -Be 'ubuntu-latest'
        $combos[0].language | Should -Be '3.8'
        $combos[1].os | Should -Be 'ubuntu-latest'
        $combos[1].language | Should -Be '3.9'
        $combos[2].os | Should -Be 'windows-latest'
        $combos[2].language | Should -Be '3.8'
        $combos[3].os | Should -Be 'windows-latest'
        $combos[3].language | Should -Be '3.9'
    }

    # Test 7 (RED): Feature flags multiply combinations
    It 'includes feature flags in the cartesian product' {
        $config = New-MatrixConfig `
            -OsOptions @('ubuntu-latest') `
            -LanguageVersions @('3.8', '3.9') `
            -FeatureFlags @('flag1', 'flag2')

        $combos = Get-MatrixCombinations -Config $config

        # 1 OS x 2 versions x 2 flags = 4 combinations
        $combos | Should -HaveCount 4
        $combos[0].feature | Should -Be 'flag1'
        $combos[1].feature | Should -Be 'flag2'
    }

    # Test 8 (RED): No feature flags means no feature dimension
    It 'omits feature key when no feature flags configured' {
        $config = New-MatrixConfig `
            -OsOptions @('ubuntu-latest') `
            -LanguageVersions @('3.8')

        $combos = Get-MatrixCombinations -Config $config

        $combos | Should -HaveCount 1
        $combos[0].Keys | Should -Not -Contain 'feature'
    }
}

Describe 'Invoke-ExcludeRules' {
    # Test 9 (RED): Exclude rules remove matching combinations
    It 'removes combinations matching exclude rules' {
        $config = New-MatrixConfig `
            -OsOptions @('ubuntu-latest', 'windows-latest') `
            -LanguageVersions @('3.8', '3.9') `
            -ExcludeRules @(@{ os = 'windows-latest'; language = '3.8' })

        $combos = Get-MatrixCombinations -Config $config
        $filtered = Invoke-ExcludeRules -Combinations $combos -ExcludeRules $config.exclude_rules

        # 4 total - 1 excluded = 3
        $filtered | Should -HaveCount 3
        $filtered | Where-Object { $_.os -eq 'windows-latest' -and $_.language -eq '3.8' } |
            Should -HaveCount 0
    }

    # Test 10 (RED): Partial exclude rules match on partial keys
    It 'excludes all combinations matching partial exclude rule' {
        $config = New-MatrixConfig `
            -OsOptions @('ubuntu-latest', 'windows-latest') `
            -LanguageVersions @('3.8', '3.9') `
            -ExcludeRules @(@{ os = 'windows-latest' })

        $combos = Get-MatrixCombinations -Config $config
        $filtered = Invoke-ExcludeRules -Combinations $combos -ExcludeRules $config.exclude_rules

        # Removes all windows combinations (2 removed)
        $filtered | Should -HaveCount 2
        $filtered | Where-Object { $_.os -eq 'windows-latest' } | Should -HaveCount 0
    }

    # Test 11 (RED): No exclude rules returns all combinations unchanged
    It 'returns all combinations when no exclude rules' {
        $combos = @(
            @{ os = 'ubuntu-latest'; language = '3.8' },
            @{ os = 'ubuntu-latest'; language = '3.9' }
        )
        $filtered = Invoke-ExcludeRules -Combinations $combos -ExcludeRules @()

        $filtered | Should -HaveCount 2
    }
}

Describe 'Test-MatrixSize' {
    # Test 12 (RED): Passes when combination count is within limit
    It 'does not throw when matrix size is within max_size' {
        $combos = @(
            @{ os = 'ubuntu-latest'; language = '3.8' },
            @{ os = 'ubuntu-latest'; language = '3.9' }
        )
        { Test-MatrixSize -Combinations $combos -MaxSize 10 } | Should -Not -Throw
    }

    # Test 13 (RED): Throws when combination count exceeds limit
    It 'throws when matrix size exceeds max_size' {
        $combos = @(
            @{ os = 'ubuntu-latest'; language = '3.8' },
            @{ os = 'ubuntu-latest'; language = '3.9' },
            @{ os = 'windows-latest'; language = '3.8' }
        )
        { Test-MatrixSize -Combinations $combos -MaxSize 2 } |
            Should -Throw '*exceeds maximum*'
    }
}

Describe 'ConvertTo-GitHubActionsMatrix' {
    # Test 14 (RED): Outputs correct GitHub Actions matrix JSON structure
    It 'produces a valid GitHub Actions strategy.matrix structure' {
        $config = New-MatrixConfig `
            -OsOptions @('ubuntu-latest', 'windows-latest') `
            -LanguageVersions @('3.8', '3.9') `
            -MaxParallel 4 `
            -FailFast $false

        $json = ConvertTo-GitHubActionsMatrix -Config $config

        $parsed = $json | ConvertFrom-Json
        $parsed.'max-parallel' | Should -Be 4
        $parsed.'fail-fast' | Should -Be $false
        $parsed.matrix | Should -Not -BeNullOrEmpty
        $parsed.matrix.os | Should -Contain 'ubuntu-latest'
        $parsed.matrix.os | Should -Contain 'windows-latest'
        $parsed.matrix.language | Should -Contain '3.8'
        $parsed.matrix.language | Should -Contain '3.9'
    }

    # Test 15 (RED): Include rules appear in output matrix
    It 'includes include rules in the matrix output' {
        $includeRule = @{ os = 'macos-latest'; language = '3.11'; extra = 'special' }
        $config = New-MatrixConfig `
            -OsOptions @('ubuntu-latest') `
            -LanguageVersions @('3.9') `
            -IncludeRules @($includeRule)

        $json = ConvertTo-GitHubActionsMatrix -Config $config
        $parsed = $json | ConvertFrom-Json

        $parsed.matrix.include | Should -HaveCount 1
        $parsed.matrix.include[0].os | Should -Be 'macos-latest'
        $parsed.matrix.include[0].language | Should -Be '3.11'
    }

    # Test 16 (RED): Exclude rules appear in output matrix
    It 'includes exclude rules in the matrix output' {
        $excludeRule = @{ os = 'ubuntu-latest'; language = '3.8' }
        $config = New-MatrixConfig `
            -OsOptions @('ubuntu-latest', 'windows-latest') `
            -LanguageVersions @('3.8', '3.9') `
            -ExcludeRules @($excludeRule)

        $json = ConvertTo-GitHubActionsMatrix -Config $config
        $parsed = $json | ConvertFrom-Json

        $parsed.matrix.exclude | Should -HaveCount 1
        $parsed.matrix.exclude[0].os | Should -Be 'ubuntu-latest'
        $parsed.matrix.exclude[0].language | Should -Be '3.8'
    }

    # Test 17 (RED): Feature flags appear as 'feature' dimension in matrix
    It 'includes feature flags as a dimension in the matrix' {
        $config = New-MatrixConfig `
            -OsOptions @('ubuntu-latest') `
            -LanguageVersions @('3.9') `
            -FeatureFlags @('experimental', 'stable')

        $json = ConvertTo-GitHubActionsMatrix -Config $config
        $parsed = $json | ConvertFrom-Json

        $parsed.matrix.feature | Should -Contain 'experimental'
        $parsed.matrix.feature | Should -Contain 'stable'
    }

    # Test 18 (RED): max-parallel of 0 means omit the field
    It 'omits max-parallel when set to 0' {
        $config = New-MatrixConfig `
            -OsOptions @('ubuntu-latest') `
            -LanguageVersions @('3.9') `
            -MaxParallel 0

        $json = ConvertTo-GitHubActionsMatrix -Config $config
        $parsed = $json | ConvertFrom-Json

        # max-parallel should not be present (or null)
        $parsed.PSObject.Properties.Name | Should -Not -Contain 'max-parallel'
    }

    # Test 19 (RED): Throws when generated matrix exceeds max size
    It 'throws when the matrix exceeds max_size' {
        $config = New-MatrixConfig `
            -OsOptions @('ubuntu-latest', 'windows-latest', 'macos-latest') `
            -LanguageVersions @('3.8', '3.9', '3.10', '3.11') `
            -MaxSize 5

        { ConvertTo-GitHubActionsMatrix -Config $config } |
            Should -Throw '*exceeds maximum*'
    }

    # Test 20 (RED): Output is valid JSON string
    It 'outputs valid JSON' {
        $config = New-MatrixConfig `
            -OsOptions @('ubuntu-latest') `
            -LanguageVersions @('3.9')

        $json = ConvertTo-GitHubActionsMatrix -Config $config

        { $json | ConvertFrom-Json } | Should -Not -Throw
    }
}

Describe 'Invoke-MatrixGenerator (Integration)' {
    # Test 21 (RED): Full pipeline integration test
    It 'generates a complete matrix from a config hashtable' {
        $inputConfig = @{
            os               = @('ubuntu-latest', 'windows-latest')
            language_versions = @('3.9', '3.10')
            feature_flags    = @('cache', 'no-cache')
            exclude_rules    = @(@{ os = 'windows-latest'; language = '3.9' })
            max_parallel     = 6
            fail_fast        = $true
            max_size         = 100
        }

        $json = Invoke-MatrixGenerator -InputConfig $inputConfig
        $parsed = $json | ConvertFrom-Json

        # Should have fail-fast and max-parallel
        $parsed.'fail-fast' | Should -Be $true
        $parsed.'max-parallel' | Should -Be 6

        # Matrix dimensions should be present
        $parsed.matrix.os | Should -HaveCount 2
        $parsed.matrix.language | Should -HaveCount 2
        $parsed.matrix.feature | Should -HaveCount 2

        # Exclude rule should appear
        $parsed.matrix.exclude | Should -HaveCount 1
    }

    # Test 22 (RED): Outputs to file when path specified
    It 'writes the JSON to a file when OutputPath is specified' {
        $tmpFile = Join-Path $TestDrive 'matrix-output.json'

        $inputConfig = @{
            os               = @('ubuntu-latest')
            language_versions = @('3.9')
        }

        Invoke-MatrixGenerator -InputConfig $inputConfig -OutputPath $tmpFile
        $tmpFile | Should -Exist

        $content = Get-Content $tmpFile -Raw
        { $content | ConvertFrom-Json } | Should -Not -Throw
    }
}
