BeforeAll {
    . "$PSScriptRoot/MatrixGenerator.ps1"
}

Describe "New-BuildMatrix" {

    # ── Basic cartesian product ──────────────────────────────────────────
    Context "Basic matrix generation" {

        It "generates a cartesian product of OS, language, and feature-flag dimensions" {
            $config = @{
                os       = @("ubuntu-latest", "windows-latest")
                language = @("3.9", "3.10")
                feature  = @("enabled")
            }
            $result = New-BuildMatrix -Config $config
            # 2 OS × 2 language × 1 feature = 4 combinations
            $result.matrix.include.Count | Should -Be 4
        }

        It "returns valid JSON when converted" {
            $config = @{
                os       = @("ubuntu-latest")
                language = @("3.9")
            }
            $result = New-BuildMatrix -Config $config
            $json = $result | ConvertTo-Json -Depth 10
            { $json | ConvertFrom-Json } | Should -Not -Throw
        }

        It "each combination contains all dimension keys" {
            $config = @{
                os       = @("ubuntu-latest")
                language = @("3.9", "3.10")
                feature  = @("on")
            }
            $result = New-BuildMatrix -Config $config
            foreach ($entry in $result.matrix.include) {
                $entry.os      | Should -Not -BeNullOrEmpty
                $entry.language | Should -Not -BeNullOrEmpty
                $entry.feature | Should -Not -BeNullOrEmpty
            }
        }
    }

    # ── Exclude rules ────────────────────────────────────────────────────
    Context "Exclude rules" {

        It "removes combinations matching an exclude rule" {
            $config = @{
                os       = @("ubuntu-latest", "windows-latest")
                language = @("3.9", "3.10")
            }
            $exclude = @(
                @{ os = "windows-latest"; language = "3.9" }
            )
            $result = New-BuildMatrix -Config $config -Exclude $exclude
            # 2×2=4 minus 1 excluded = 3
            $result.matrix.include.Count | Should -Be 3
        }

        It "does not remove non-matching combinations" {
            $config = @{
                os       = @("ubuntu-latest", "windows-latest")
                language = @("3.9", "3.10")
            }
            $exclude = @(
                @{ os = "macos-latest" }
            )
            $result = New-BuildMatrix -Config $config -Exclude $exclude
            $result.matrix.include.Count | Should -Be 4
        }

        It "supports partial-key excludes (matches on subset of dimensions)" {
            $config = @{
                os       = @("ubuntu-latest", "windows-latest")
                language = @("3.9", "3.10")
            }
            # Exclude all windows entries regardless of language
            $exclude = @(
                @{ os = "windows-latest" }
            )
            $result = New-BuildMatrix -Config $config -Exclude $exclude
            $result.matrix.include.Count | Should -Be 2
            $result.matrix.include | ForEach-Object { $_.os | Should -Be "ubuntu-latest" }
        }
    }

    # ── Include rules ────────────────────────────────────────────────────
    Context "Include rules" {

        It "adds a standalone entry when include doesn't match any existing combo" {
            $config = @{
                os       = @("ubuntu-latest")
                language = @("3.9")
            }
            $include = @(
                @{ os = "macos-latest"; language = "3.11"; experimental = $true }
            )
            $result = New-BuildMatrix -Config $config -Include $include
            # 1 original + 1 standalone include
            $result.matrix.include.Count | Should -Be 2
        }

        It "merges extra keys into matching combinations" {
            $config = @{
                os       = @("ubuntu-latest")
                language = @("3.9", "3.10")
            }
            # Add a "compiler" key to the ubuntu+3.10 combo
            $include = @(
                @{ os = "ubuntu-latest"; language = "3.10"; compiler = "gcc" }
            )
            $result = New-BuildMatrix -Config $config -Include $include
            # Still 2 combos — one got an extra key merged
            $result.matrix.include.Count | Should -Be 2
            $matched = $result.matrix.include | Where-Object { $_.language -eq "3.10" }
            $matched.compiler | Should -Be "gcc"
        }
    }

    # ── Max-parallel and fail-fast ───────────────────────────────────────
    Context "Strategy options" {

        It "includes max-parallel when specified" {
            $config = @{ os = @("ubuntu-latest") }
            $result = New-BuildMatrix -Config $config -MaxParallel 2
            $result["max-parallel"] | Should -Be 2
        }

        It "does not include max-parallel when not specified" {
            $config = @{ os = @("ubuntu-latest") }
            $result = New-BuildMatrix -Config $config
            $result.ContainsKey("max-parallel") | Should -Be $false
        }

        It "includes fail-fast when set to true" {
            $config = @{ os = @("ubuntu-latest") }
            $result = New-BuildMatrix -Config $config -FailFast $true
            $result["fail-fast"] | Should -Be $true
        }

        It "includes fail-fast when set to false" {
            $config = @{ os = @("ubuntu-latest") }
            $result = New-BuildMatrix -Config $config -FailFast $false
            $result["fail-fast"] | Should -Be $false
        }

        It "does not include fail-fast when not specified" {
            $config = @{ os = @("ubuntu-latest") }
            $result = New-BuildMatrix -Config $config
            $result.ContainsKey("fail-fast") | Should -Be $false
        }
    }

    # ── Size validation ──────────────────────────────────────────────────
    Context "Matrix size validation" {

        It "throws when matrix exceeds MaxSize" {
            $config = @{
                os       = @("a", "b", "c")
                language = @("1", "2", "3")
            }
            # 3×3=9 combos, limit to 5
            { New-BuildMatrix -Config $config -MaxSize 5 } |
                Should -Throw "*exceeds maximum*"
        }

        It "does not throw when matrix is at exactly MaxSize" {
            $config = @{
                os       = @("a", "b")
                language = @("1", "2")
            }
            # 2×2=4, limit 4
            { New-BuildMatrix -Config $config -MaxSize 4 } |
                Should -Not -Throw
        }

        It "uses GitHub's 256 default limit" {
            # Build something small — just ensure default doesn't choke
            $config = @{ os = @("ubuntu-latest") }
            $result = New-BuildMatrix -Config $config
            $result.matrix.include.Count | Should -Be 1
        }
    }

    # ── Error handling ───────────────────────────────────────────────────
    Context "Error handling" {

        It "throws on empty config" {
            { New-BuildMatrix -Config @{} } |
                Should -Throw "*at least one dimension*"
        }
    }

    # ── Combined include + exclude ───────────────────────────────────────
    Context "Include and exclude together" {

        It "applies exclude first, then include adds new entries" {
            $config = @{
                os       = @("ubuntu-latest", "windows-latest")
                language = @("3.9", "3.10")
            }
            $exclude = @(
                @{ os = "windows-latest"; language = "3.9" }
            )
            $include = @(
                @{ os = "macos-latest"; language = "3.11" }
            )
            $result = New-BuildMatrix -Config $config -Exclude $exclude -Include $include
            # (2×2=4) - 1 excluded + 1 included = 4
            $result.matrix.include.Count | Should -Be 4
        }
    }
}

# ── ConvertTo-MatrixJson ─────────────────────────────────────────────────
Describe "ConvertTo-MatrixJson" {

    It "returns a valid JSON string" {
        $config = @{
            os       = @("ubuntu-latest", "windows-latest")
            language = @("3.9", "3.10")
        }
        $json = ConvertTo-MatrixJson -Config $config
        $parsed = $json | ConvertFrom-Json
        $parsed.matrix.include.Count | Should -Be 4
    }

    It "includes strategy fields in the JSON output" {
        $config = @{ os = @("ubuntu-latest") }
        $json = ConvertTo-MatrixJson -Config $config -MaxParallel 3 -FailFast $false
        $parsed = $json | ConvertFrom-Json
        $parsed."max-parallel" | Should -Be 3
        $parsed."fail-fast" | Should -Be $false
    }
}

# ── End-to-end integration test ──────────────────────────────────────────
Describe "End-to-end: realistic CI matrix" {

    It "generates a complete matrix for a multi-language, multi-OS CI pipeline" {
        $config = @{
            os       = @("ubuntu-latest", "windows-latest", "macos-latest")
            node     = @("18", "20", "22")
            feature  = @("stable", "experimental")
        }
        $exclude = @(
            # Don't run experimental on Windows
            @{ os = "windows-latest"; feature = "experimental" }
            # Don't run Node 18 on macOS (EOL)
            @{ os = "macos-latest"; node = "18" }
        )
        $include = @(
            # Add a special ARM build
            @{ os = "ubuntu-arm"; node = "22"; feature = "stable"; arch = "arm64" }
        )
        $result = New-BuildMatrix -Config $config `
            -Exclude $exclude `
            -Include $include `
            -MaxParallel 4 `
            -FailFast $false `
            -MaxSize 50

        # 3×3×2 = 18 base
        # minus 3 (windows×experimental for node 18,20,22) = 15
        # minus 2 (macos×node18 for stable,experimental) = 13
        # plus 1 include = 14
        $result.matrix.include.Count | Should -Be 14
        $result["max-parallel"] | Should -Be 4
        $result["fail-fast"] | Should -Be $false

        # Verify no excluded combos snuck in
        $windowsExperimental = $result.matrix.include | Where-Object {
            $_.os -eq "windows-latest" -and $_.feature -eq "experimental"
        }
        $windowsExperimental | Should -BeNullOrEmpty

        $macosNode18 = $result.matrix.include | Where-Object {
            $_.os -eq "macos-latest" -and $_.node -eq "18"
        }
        $macosNode18 | Should -BeNullOrEmpty

        # Verify the ARM include was added
        $armBuild = $result.matrix.include | Where-Object { $_.arch -eq "arm64" }
        $armBuild | Should -Not -BeNullOrEmpty
        $armBuild.os | Should -Be "ubuntu-arm"

        # Verify JSON output is valid
        $json = $result | ConvertTo-Json -Depth 10
        { $json | ConvertFrom-Json } | Should -Not -Throw
    }
}
