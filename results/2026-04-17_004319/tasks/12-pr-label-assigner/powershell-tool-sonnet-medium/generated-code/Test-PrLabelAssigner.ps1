# Test-PrLabelAssigner.ps1
# Integration test runner: executes the label assigner against known fixture inputs
# and prints PASS/FAIL lines that the act test harness can assert on.

$ErrorActionPreference = 'Stop'
$script:allPassed = $true

function Assert-Labels {
    param(
        [string]$Name,
        [string[]]$Files,
        [string[]]$ExpectedLabels
    )

    $jsonOut = & "$PSScriptRoot/Invoke-PrLabelAssigner.ps1" -ChangedFiles $Files
    # ConvertTo-Json emits "null" for empty array, handle gracefully
    if ($jsonOut -eq 'null' -or [string]::IsNullOrWhiteSpace($jsonOut)) {
        $actual = @()
    } else {
        $actual = $jsonOut | ConvertFrom-Json
    }

    $ok = $true
    foreach ($exp in $ExpectedLabels) {
        if ($actual -notcontains $exp) { $ok = $false }
    }
    if ($ok -and $actual.Count -eq $ExpectedLabels.Count) {
        Write-Output "PASS: $Name => [$($actual -join ', ')]"
    } else {
        Write-Output "FAIL: $Name => expected [$($ExpectedLabels -join ', ')] got [$($actual -join ', ')]"
        $script:allPassed = $false
    }
}

# TC1: single docs file
Assert-Labels "TC1-docs-only" @("docs/README.md") @("documentation")

# TC2: API file (matches api + source)
Assert-Labels "TC2-api-file" @("src/api/users.ts") @("api", "source")

# TC3: test file (matches tests + source)
Assert-Labels "TC3-test-file" @("src/utils.test.ts") @("tests", "source")

# TC4: multiple files yield multiple labels, sorted by priority
Assert-Labels "TC4-multiple-files" @("docs/README.md", "src/api/users.ts") @("documentation", "api", "source")

# TC5: file that matches no rules
Assert-Labels "TC5-no-match" @("random/unmatched.txt") @()

# TC6: file matching both api and tests (nested test in api dir)
Assert-Labels "TC6-api-test-file" @("src/api/users.test.ts") @("api", "tests", "source")

# TC7: CI workflow file
Assert-Labels "TC7-ci-file" @(".github/workflows/ci.yml") @("ci")

if ($script:allPassed) {
    Write-Output "ALL_TESTS_PASSED"
    exit 0
} else {
    Write-Error "One or more integration tests failed"
    exit 1
}
