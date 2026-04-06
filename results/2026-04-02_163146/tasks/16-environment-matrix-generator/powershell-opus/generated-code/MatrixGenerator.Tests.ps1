# MatrixGenerator.Tests.ps1
# Pester tests for the Environment Matrix Generator.
#
# TDD approach: each Describe/Context block was written as a failing test first,
# then the corresponding implementation was added to MatrixGenerator.ps1 to make
# it pass. The tests are organized by feature area.

BeforeAll {
    . "$PSScriptRoot/MatrixGenerator.ps1"
}

# ============================================================================
# HELPER: Compare two hashtables for equality (used in assertions)
# ============================================================================
function Compare-Hashtable {
    param([hashtable]$A, [hashtable]$B)
    if ($A.Keys.Count -ne $B.Keys.Count) { return $false }
    foreach ($key in $A.Keys) {
        if (-not $B.ContainsKey($key)) { return $false }
        if ($A[$key] -ne $B[$key]) { return $false }
    }
    return $true
}

# ============================================================================
# TEST 1 (RED→GREEN): Basic cartesian product generation
# ============================================================================
Describe 'New-BuildMatrix - Basic cartesian product' {

    It 'generates all combinations of two dimensions (2x2=4)' {
        $config = @{
            matrix = @{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @('18', '20')
            }
        }

        $result = New-BuildMatrix -Config $config

        $result.matrix.include | Should -HaveCount 4

        # Verify every expected combination exists
        $combos = $result.matrix.include
        $found = $combos | Where-Object { $_.os -eq 'ubuntu-latest' -and $_.node -eq '18' }
        $found | Should -Not -BeNullOrEmpty

        $found = $combos | Where-Object { $_.os -eq 'ubuntu-latest' -and $_.node -eq '20' }
        $found | Should -Not -BeNullOrEmpty

        $found = $combos | Where-Object { $_.os -eq 'windows-latest' -and $_.node -eq '18' }
        $found | Should -Not -BeNullOrEmpty

        $found = $combos | Where-Object { $_.os -eq 'windows-latest' -and $_.node -eq '20' }
        $found | Should -Not -BeNullOrEmpty
    }

    It 'handles a single dimension with three values' {
        $config = @{
            matrix = @{
                os = @('ubuntu-latest', 'macos-latest', 'windows-latest')
            }
        }

        $result = New-BuildMatrix -Config $config
        $result.matrix.include | Should -HaveCount 3

        $osValues = $result.matrix.include | ForEach-Object { $_.os }
        $osValues | Should -Contain 'ubuntu-latest'
        $osValues | Should -Contain 'macos-latest'
        $osValues | Should -Contain 'windows-latest'
    }

    It 'handles three dimensions (2x2x2=8)' {
        $config = @{
            matrix = @{
                os      = @('ubuntu-latest', 'windows-latest')
                node    = @('18', '20')
                feature = @('on', 'off')
            }
        }

        $result = New-BuildMatrix -Config $config
        $result.matrix.include | Should -HaveCount 8
    }

    It 'handles four dimensions (2x3x2x2=24)' {
        $config = @{
            matrix = @{
                os       = @('ubuntu-latest', 'windows-latest')
                python   = @('3.9', '3.10', '3.11')
                debug    = @('true', 'false')
                compiler = @('gcc', 'clang')
            }
        }

        $result = New-BuildMatrix -Config $config
        $result.matrix.include | Should -HaveCount 24
    }

    It 'handles single-value dimensions' {
        $config = @{
            matrix = @{
                os   = @('ubuntu-latest')
                node = @('20')
            }
        }

        $result = New-BuildMatrix -Config $config
        $result.matrix.include | Should -HaveCount 1
        $result.matrix.include[0].os | Should -Be 'ubuntu-latest'
        $result.matrix.include[0].node | Should -Be '20'
    }
}

# ============================================================================
# TEST 2 (RED→GREEN): Exclude rules
# ============================================================================
Describe 'New-BuildMatrix - Exclude rules' {

    It 'removes combinations matching an exclude rule' {
        $config = @{
            matrix = @{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @('18', '20')
            }
            exclude = @(
                @{ os = 'windows-latest'; node = '18' }
            )
        }

        $result = New-BuildMatrix -Config $config
        $result.matrix.include | Should -HaveCount 3

        # The excluded combo should not exist
        $excluded = $result.matrix.include | Where-Object {
            $_.os -eq 'windows-latest' -and $_.node -eq '18'
        }
        $excluded | Should -BeNullOrEmpty
    }

    It 'removes multiple combinations with multiple exclude rules' {
        $config = @{
            matrix = @{
                os   = @('ubuntu-latest', 'windows-latest', 'macos-latest')
                node = @('18', '20')
            }
            exclude = @(
                @{ os = 'windows-latest'; node = '18' },
                @{ os = 'macos-latest'; node = '18' }
            )
        }

        $result = New-BuildMatrix -Config $config
        # 3x2 = 6, minus 2 excluded = 4
        $result.matrix.include | Should -HaveCount 4
    }

    It 'supports partial exclude rules (match on subset of dimensions)' {
        $config = @{
            matrix = @{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @('18', '20')
            }
            # Exclude all windows combinations regardless of node
            exclude = @(
                @{ os = 'windows-latest' }
            )
        }

        $result = New-BuildMatrix -Config $config
        # Should remove both windows combos, leaving only ubuntu ones
        $result.matrix.include | Should -HaveCount 2
        $result.matrix.include | ForEach-Object { $_.os | Should -Be 'ubuntu-latest' }
    }

    It 'handles exclude that matches nothing (no-op)' {
        $config = @{
            matrix = @{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @('18', '20')
            }
            exclude = @(
                @{ os = 'macos-latest' }
            )
        }

        $result = New-BuildMatrix -Config $config
        $result.matrix.include | Should -HaveCount 4
    }
}

# ============================================================================
# TEST 3 (RED→GREEN): Include rules
# ============================================================================
Describe 'New-BuildMatrix - Include rules' {

    It 'adds a new combination when include does not overlap existing combos' {
        $config = @{
            matrix = @{
                os   = @('ubuntu-latest')
                node = @('18')
            }
            include = @(
                @{ os = 'macos-latest'; node = '20' }
            )
        }

        $result = New-BuildMatrix -Config $config
        # 1 from cartesian + 1 from include = 2
        $result.matrix.include | Should -HaveCount 2

        $macosCombo = $result.matrix.include | Where-Object { $_.os -eq 'macos-latest' }
        $macosCombo | Should -Not -BeNullOrEmpty
        $macosCombo.node | Should -Be '20'
    }

    It 'merges extra keys into matching existing combinations' {
        $config = @{
            matrix = @{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @('18')
            }
            include = @(
                @{ os = 'ubuntu-latest'; node = '18'; npm = '9' }
            )
        }

        $result = New-BuildMatrix -Config $config
        # Should still have 2 combos (no new row added)
        $result.matrix.include | Should -HaveCount 2

        # The ubuntu combo should have the npm key merged
        $ubuntuCombo = $result.matrix.include | Where-Object { $_.os -eq 'ubuntu-latest' }
        $ubuntuCombo.npm | Should -Be '9'
    }

    It 'adds an include with entirely new dimension keys as a new row' {
        $config = @{
            matrix = @{
                os = @('ubuntu-latest')
            }
            include = @(
                @{ custom_runner = 'self-hosted'; arch = 'arm64' }
            )
        }

        $result = New-BuildMatrix -Config $config
        # 1 from matrix + 1 from include
        $result.matrix.include | Should -HaveCount 2
    }

    It 'handles multiple include rules' {
        $config = @{
            matrix = @{
                os   = @('ubuntu-latest')
                node = @('18')
            }
            include = @(
                @{ os = 'macos-latest'; node = '20' },
                @{ os = 'windows-latest'; node = '20' }
            )
        }

        $result = New-BuildMatrix -Config $config
        # 1 from matrix + 2 from include
        $result.matrix.include | Should -HaveCount 3
    }
}

# ============================================================================
# TEST 4 (RED→GREEN): Combined include and exclude
# ============================================================================
Describe 'New-BuildMatrix - Combined include and exclude' {

    It 'applies excludes first, then includes' {
        $config = @{
            matrix = @{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @('18', '20')
            }
            exclude = @(
                @{ os = 'windows-latest'; node = '18' }
            )
            include = @(
                @{ os = 'macos-latest'; node = '20' }
            )
        }

        $result = New-BuildMatrix -Config $config
        # 4 original - 1 excluded + 1 included = 4
        $result.matrix.include | Should -HaveCount 4

        # Excluded combo should not exist
        $excluded = $result.matrix.include | Where-Object {
            $_.os -eq 'windows-latest' -and $_.node -eq '18'
        }
        $excluded | Should -BeNullOrEmpty

        # Included combo should exist
        $included = $result.matrix.include | Where-Object { $_.os -eq 'macos-latest' }
        $included | Should -Not -BeNullOrEmpty
    }
}

# ============================================================================
# TEST 5 (RED→GREEN): max-parallel and fail-fast configuration
# ============================================================================
Describe 'New-BuildMatrix - Strategy settings' {

    It 'includes fail-fast when specified as true' {
        $config = @{
            matrix    = @{ os = @('ubuntu-latest') }
            fail_fast = $true
        }

        $result = New-BuildMatrix -Config $config
        $result['fail-fast'] | Should -BeTrue
    }

    It 'includes fail-fast when specified as false' {
        $config = @{
            matrix    = @{ os = @('ubuntu-latest') }
            fail_fast = $false
        }

        $result = New-BuildMatrix -Config $config
        $result['fail-fast'] | Should -BeFalse
    }

    It 'does not include fail-fast when not specified' {
        $config = @{
            matrix = @{ os = @('ubuntu-latest') }
        }

        $result = New-BuildMatrix -Config $config
        $result.ContainsKey('fail-fast') | Should -BeFalse
    }

    It 'includes max-parallel when specified' {
        $config = @{
            matrix       = @{ os = @('ubuntu-latest') }
            max_parallel = 3
        }

        $result = New-BuildMatrix -Config $config
        $result['max-parallel'] | Should -Be 3
    }

    It 'does not include max-parallel when not specified' {
        $config = @{
            matrix = @{ os = @('ubuntu-latest') }
        }

        $result = New-BuildMatrix -Config $config
        $result.ContainsKey('max-parallel') | Should -BeFalse
    }

    It 'includes both fail-fast and max-parallel together' {
        $config = @{
            matrix       = @{ os = @('ubuntu-latest', 'windows-latest') }
            fail_fast    = $false
            max_parallel = 2
        }

        $result = New-BuildMatrix -Config $config
        $result['fail-fast'] | Should -BeFalse
        $result['max-parallel'] | Should -Be 2
        $result.matrix.include | Should -HaveCount 2
    }
}

# ============================================================================
# TEST 6 (RED→GREEN): Matrix size validation
# ============================================================================
Describe 'New-BuildMatrix - Matrix size validation' {

    It 'allows a matrix within the default 256 limit' {
        # 4 x 4 = 16 combos, well under 256
        $config = @{
            matrix = @{
                os   = @('a', 'b', 'c', 'd')
                lang = @('1', '2', '3', '4')
            }
        }

        { New-BuildMatrix -Config $config } | Should -Not -Throw
        $result = New-BuildMatrix -Config $config
        $result.matrix.include | Should -HaveCount 16
    }

    It 'throws when matrix exceeds default 256 limit' {
        # 20 x 20 = 400 > 256
        $config = @{
            matrix = @{
                dim1 = 1..20 | ForEach-Object { "v$_" }
                dim2 = 1..20 | ForEach-Object { "w$_" }
            }
        }

        { New-BuildMatrix -Config $config } | Should -Throw "*exceeds maximum*"
    }

    It 'respects a custom max_size limit' {
        # 2 x 3 = 6, with max_size = 5 should throw
        $config = @{
            matrix   = @{
                os   = @('a', 'b')
                lang = @('1', '2', '3')
            }
            max_size = 5
        }

        { New-BuildMatrix -Config $config } | Should -Throw "*exceeds maximum*"
    }

    It 'allows a matrix exactly at the custom limit' {
        $config = @{
            matrix   = @{
                os   = @('a', 'b')
                lang = @('1', '2')
            }
            max_size = 4
        }

        { New-BuildMatrix -Config $config } | Should -Not -Throw
        $result = New-BuildMatrix -Config $config
        $result.matrix.include | Should -HaveCount 4
    }

    It 'counts include rules towards the size limit' {
        # 2 combos from matrix + 1 from include = 3, limit = 2
        $config = @{
            matrix   = @{
                os = @('a', 'b')
            }
            include  = @(
                @{ os = 'c' }
            )
            max_size = 2
        }

        { New-BuildMatrix -Config $config } | Should -Throw "*exceeds maximum*"
    }

    It 'counts after excludes are applied' {
        # 2x2=4, exclude 1 = 3, limit = 3 should pass
        $config = @{
            matrix   = @{
                os   = @('a', 'b')
                lang = @('1', '2')
            }
            exclude  = @(
                @{ os = 'a'; lang = '1' }
            )
            max_size = 3
        }

        { New-BuildMatrix -Config $config } | Should -Not -Throw
        $result = New-BuildMatrix -Config $config
        $result.matrix.include | Should -HaveCount 3
    }
}

# ============================================================================
# TEST 7 (RED→GREEN): Error handling and input validation
# ============================================================================
Describe 'New-BuildMatrix - Error handling' {

    It 'throws when Config is null' {
        { New-BuildMatrix -Config $null } | Should -Throw "*required*"
    }

    It 'throws when matrix key is missing' {
        { New-BuildMatrix -Config @{} } | Should -Throw "*matrix*"
    }

    It 'throws when matrix is not a hashtable' {
        { New-BuildMatrix -Config @{ matrix = 'invalid' } } | Should -Throw "*hashtable*"
    }

    It 'throws when a matrix dimension has empty values' {
        $config = @{
            matrix = @{
                os = @()
            }
        }
        { New-BuildMatrix -Config $config } | Should -Throw "*at least one value*"
    }

    It 'throws when max_parallel is zero or negative' {
        $config = @{
            matrix       = @{ os = @('ubuntu-latest') }
            max_parallel = 0
        }
        { New-BuildMatrix -Config $config } | Should -Throw "*positive integer*"
    }

    It 'throws when max_size is zero or negative' {
        $config = @{
            matrix   = @{ os = @('ubuntu-latest') }
            max_size = -1
        }
        { New-BuildMatrix -Config $config } | Should -Throw "*positive integer*"
    }
}

# ============================================================================
# TEST 8 (RED→GREEN): JSON output via ConvertTo-MatrixJson
# ============================================================================
Describe 'ConvertTo-MatrixJson' {

    It 'produces valid JSON from a config hashtable' {
        $config = @{
            matrix = @{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @('18')
            }
        }

        $json = ConvertTo-MatrixJson -ConfigInput $config
        # Should be parseable JSON
        $parsed = $json | ConvertFrom-Json
        $parsed | Should -Not -BeNullOrEmpty
        $parsed.matrix.include | Should -HaveCount 2
    }

    It 'produces valid JSON from a JSON string input' {
        $jsonInput = @'
{
    "matrix": {
        "os": ["ubuntu-latest"],
        "node": ["18", "20"]
    },
    "fail_fast": true,
    "max_parallel": 2
}
'@

        $json = ConvertTo-MatrixJson -ConfigInput $jsonInput
        $parsed = $json | ConvertFrom-Json
        $parsed | Should -Not -BeNullOrEmpty
        $parsed.matrix.include | Should -HaveCount 2
        # fail-fast key in JSON (note: ConvertTo-Json uses the key name from the hashtable)
        $parsed.'fail-fast' | Should -BeTrue
        $parsed.'max-parallel' | Should -Be 2
    }
}

# ============================================================================
# TEST 9 (RED→GREEN): Realistic GitHub Actions scenario
# ============================================================================
Describe 'New-BuildMatrix - Realistic CI scenario' {

    It 'generates a real-world Node.js CI matrix with excludes and includes' {
        $config = @{
            matrix = @{
                os   = @('ubuntu-latest', 'windows-latest', 'macos-latest')
                node = @('18', '20', '22')
            }
            exclude = @(
                # Don't test Node 18 on macOS (deprecated combo)
                @{ os = 'macos-latest'; node = '18' }
            )
            include = @(
                # Add a special experimental build
                @{ os = 'ubuntu-latest'; node = '22'; experimental = 'true' }
            )
            fail_fast    = $false
            max_parallel = 4
        }

        $result = New-BuildMatrix -Config $config

        # 3x3=9 - 1 excluded = 8 (the include merges into existing ubuntu/22)
        $result.matrix.include | Should -HaveCount 8
        $result['fail-fast'] | Should -BeFalse
        $result['max-parallel'] | Should -Be 4

        # Excluded combo gone
        $excludedCombo = $result.matrix.include | Where-Object {
            $_.os -eq 'macos-latest' -and $_.node -eq '18'
        }
        $excludedCombo | Should -BeNullOrEmpty

        # Experimental flag merged into ubuntu/22
        $experimental = $result.matrix.include | Where-Object {
            $_.os -eq 'ubuntu-latest' -and $_.node -eq '22'
        }
        $experimental.experimental | Should -Be 'true'
    }

    It 'generates a Python multi-version matrix with feature flags' {
        $config = @{
            matrix = @{
                os      = @('ubuntu-latest', 'windows-latest')
                python  = @('3.9', '3.10', '3.11', '3.12')
                feature = @('standard', 'experimental')
            }
            exclude = @(
                # No experimental on 3.9
                @{ python = '3.9'; feature = 'experimental' }
            )
            max_size = 256
        }

        $result = New-BuildMatrix -Config $config
        # 2 x 4 x 2 = 16, minus 2 (both OS with python 3.9 + experimental) = 14
        $result.matrix.include | Should -HaveCount 14
    }
}

# ============================================================================
# TEST 10: Get-CartesianProduct unit tests
# ============================================================================
Describe 'Get-CartesianProduct - Unit tests' {

    It 'returns single empty hashtable for no dimensions' {
        $result = @(Get-CartesianProduct -DimensionNames @() -Dimensions @{})
        $result | Should -HaveCount 1
        $result[0].Keys.Count | Should -Be 0
    }

    It 'returns correct combos for one dimension' {
        $result = @(Get-CartesianProduct -DimensionNames @('os') -Dimensions @{ os = @('a', 'b') })
        $result | Should -HaveCount 2
    }

    It 'returns correct combos for two dimensions' {
        $dims = @{
            os   = @('a', 'b')
            lang = @('1', '2', '3')
        }
        $result = @(Get-CartesianProduct -DimensionNames @('os', 'lang') -Dimensions $dims)
        $result | Should -HaveCount 6
    }
}

# ============================================================================
# TEST 11: Test-CombinationMatchesRule unit tests
# ============================================================================
Describe 'Test-CombinationMatchesRule - Unit tests' {

    It 'returns true when all rule keys match' {
        $combo = @{ os = 'ubuntu'; node = '18' }
        $rule  = @{ os = 'ubuntu'; node = '18' }
        Test-CombinationMatchesRule -Combination $combo -Rule $rule | Should -BeTrue
    }

    It 'returns true for partial rule match' {
        $combo = @{ os = 'ubuntu'; node = '18'; python = '3.9' }
        $rule  = @{ os = 'ubuntu' }
        Test-CombinationMatchesRule -Combination $combo -Rule $rule | Should -BeTrue
    }

    It 'returns false when a rule key does not match' {
        $combo = @{ os = 'ubuntu'; node = '18' }
        $rule  = @{ os = 'windows' }
        Test-CombinationMatchesRule -Combination $combo -Rule $rule | Should -BeFalse
    }

    It 'returns false when rule has a key not in the combination' {
        $combo = @{ os = 'ubuntu' }
        $rule  = @{ os = 'ubuntu'; extra = 'yes' }
        Test-CombinationMatchesRule -Combination $combo -Rule $rule | Should -BeFalse
    }

    It 'returns true for an empty rule (matches everything)' {
        $combo = @{ os = 'ubuntu'; node = '18' }
        $rule  = @{}
        Test-CombinationMatchesRule -Combination $combo -Rule $rule | Should -BeTrue
    }
}
