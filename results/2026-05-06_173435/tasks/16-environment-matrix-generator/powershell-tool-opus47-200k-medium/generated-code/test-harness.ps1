# test-harness.ps1
#
# End-to-end harness: runs the matrix generator workflow through `act` once
# per fixture (capped at 3 act runs), captures combined output to
# act-result.txt, and asserts each run's parsed matrix JSON matches its
# known-good expected value. Also asserts both jobs report success.

param(
    [string] $WorkflowFile = '.github/workflows/environment-matrix-generator.yml',
    [string] $OutputFile   = 'act-result.txt'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
Set-Location $ProjectRoot

# Each test case maps a fixture file to the JSON we expect the script to emit
# inside the workflow's BEGIN/END MATRIX JSON markers.
$cases = @(
    @{
        Name            = 'basic'
        Fixture         = 'basic.json'
        ExpectedMatrix  = @(
            @{ os = 'ubuntu-latest';  node = '18' },
            @{ os = 'ubuntu-latest';  node = '20'; experimental = $true },
            @{ os = 'windows-latest'; node = '20' }
        )
        ExpectedFailFast    = $false
        ExpectedMaxParallel = 2
    },
    @{
        Name            = 'simple'
        Fixture         = 'simple.json'
        ExpectedMatrix  = @(
            @{ python = '3.10' },
            @{ python = '3.11' },
            @{ python = '3.12' }
        )
        ExpectedFailFast    = $true
        ExpectedMaxParallel = $null
    },
    @{
        Name            = 'flags'
        Fixture         = 'flags.json'
        ExpectedMatrix  = @(
            @{ os = 'linux'; feature = 'a' },
            @{ os = 'linux'; feature = 'b' },
            @{ extra = 'x' }
        )
        ExpectedFailFast    = $true
        ExpectedMaxParallel = 4
    }
)

if (Test-Path $OutputFile) { Remove-Item $OutputFile }

function Assert-Equal {
    param($Actual, $Expected, [string] $Message)
    if ($Actual -ne $Expected) {
        throw "Assertion failed: $Message. Expected '$Expected', got '$Actual'."
    }
}

# Compare an entry hashtable from expected output against a parsed JSON
# entry, ignoring property ordering.
function Compare-Entry {
    param([hashtable] $Expected, $Actual)
    $actualKeys = @($Actual.PSObject.Properties.Name | Sort-Object)
    $expectedKeys = @($Expected.Keys | Sort-Object)
    if (($actualKeys -join ',') -ne ($expectedKeys -join ',')) {
        throw "Entry key mismatch. Expected [$($expectedKeys -join ',')], got [$($actualKeys -join ',')]."
    }
    foreach ($k in $expectedKeys) {
        if ($Actual.$k -ne $Expected[$k]) {
            throw "Entry value mismatch on '$k'. Expected '$($Expected[$k])', got '$($Actual.$k)'."
        }
    }
}

$failures = 0
foreach ($case in $cases) {
    Write-Host "==> Running act for case '$($case.Name)' (fixture=$($case.Fixture))" -ForegroundColor Cyan

    Add-Content -Path $OutputFile -Value "===== CASE: $($case.Name) (fixture=$($case.Fixture)) ====="

    # act --env propagates ACTIVE_FIXTURE into the runner so the workflow picks
    # the right fixture without us having to mutate the YAML between runs.
    $actArgs = @('push', '--rm', '--env', "ACTIVE_FIXTURE=$($case.Fixture)")
    $combined = & act @actArgs 2>&1 | Out-String
    $exitCode = $LASTEXITCODE

    Add-Content -Path $OutputFile -Value $combined
    Add-Content -Path $OutputFile -Value "----- exit code: $exitCode -----`n"

    try {
        Assert-Equal -Actual $exitCode -Expected 0 -Message "act exit code for '$($case.Name)'"

        # Both jobs should report success in act's output.
        if ($combined -notmatch 'Job succeeded') {
            throw "No 'Job succeeded' line found in act output for '$($case.Name)'."
        }
        # We expect exactly two job-succeeded lines (test + generate).
        $successCount = ([regex]::Matches($combined, 'Job succeeded')).Count
        if ($successCount -lt 2) {
            throw "Expected >=2 'Job succeeded' lines, found $successCount for '$($case.Name)'."
        }

        if ($combined -notmatch '----BEGIN MATRIX JSON----(?<json>[\s\S]*?)----END MATRIX JSON----') {
            throw "Could not find matrix JSON markers in output for '$($case.Name)'."
        }
        # act prefixes each line with "[name] | ". Strip those before parsing.
        $rawJson = $Matches.json
        $cleanLines = $rawJson -split "`n" | ForEach-Object {
            ($_ -replace '^\s*\[[^\]]*\]\s*\|\s?', '').TrimEnd("`r")
        }
        $jsonText = ($cleanLines -join "`n").Trim()
        $parsed = $jsonText | ConvertFrom-Json

        Assert-Equal -Actual $parsed.'fail-fast' -Expected $case.ExpectedFailFast `
            -Message "fail-fast for '$($case.Name)'"

        if ($null -ne $case.ExpectedMaxParallel) {
            Assert-Equal -Actual $parsed.'max-parallel' -Expected $case.ExpectedMaxParallel `
                -Message "max-parallel for '$($case.Name)'"
        }

        $actualEntries = @($parsed.matrix.include)
        Assert-Equal -Actual $actualEntries.Count -Expected $case.ExpectedMatrix.Count `
            -Message "matrix size for '$($case.Name)'"

        # Entry order is deterministic from our cartesian product implementation,
        # but include-extension can rewrite a slot in place; compare by content
        # using set-style matching keyed on a canonical signature.
        function Get-Sig($entry) {
            $props = if ($entry -is [hashtable]) {
                $entry.GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key)=$($_.Value)" }
            } else {
                $entry.PSObject.Properties | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }
            }
            ($props -join '|')
        }
        $expectedSigs = @($case.ExpectedMatrix | ForEach-Object { Get-Sig $_ } | Sort-Object)
        $actualSigs   = @($actualEntries       | ForEach-Object { Get-Sig $_ } | Sort-Object)
        if (($expectedSigs -join "`n") -ne ($actualSigs -join "`n")) {
            throw "Matrix entries mismatch for '$($case.Name)'.`nExpected:`n$($expectedSigs -join "`n")`nActual:`n$($actualSigs -join "`n")"
        }

        Write-Host "    PASS '$($case.Name)'" -ForegroundColor Green
    } catch {
        Write-Host "    FAIL '$($case.Name)': $_" -ForegroundColor Red
        $failures++
    }
}

if ($failures -gt 0) {
    Write-Error "$failures test case(s) failed. See $OutputFile for full act output."
    exit 1
}
Write-Host "`nAll harness cases passed. act output written to $OutputFile" -ForegroundColor Green
