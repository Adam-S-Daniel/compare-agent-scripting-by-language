<#
.SYNOPSIS
  End-to-end test harness: runs the GitHub Actions workflow via `act` against
  multiple fixture variations in isolated temp git repos, captures every act
  invocation into act-result.txt, and asserts on EXACT expected output values.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$ActResultPath = Join-Path $ProjectRoot 'act-result.txt'

# Fresh start per run.
Set-Content -LiteralPath $ActResultPath -Value "act harness run $(Get-Date -Format o)`n" -Encoding utf8

function Copy-ProjectInto {
    param([string]$Dest)
    $items = @('src', 'tests', '.github', '.actrc')
    foreach ($i in $items) {
        $src = Join-Path $ProjectRoot $i
        if (Test-Path $src) {
            Copy-Item -Recurse -Force $src (Join-Path $Dest $i)
        }
    }
}

function Invoke-ActCase {
    param(
        [string]$CaseName,
        [scriptblock]$SetupFixtures,   # takes $Dest param; populates $Dest/fixtures
        [string[]]$ExpectedLiterals,    # strings that MUST appear in act output
        [string[]]$UnexpectedLiterals = @()
    )
    Write-Host "=== Case: $CaseName ==="
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("act-trsa-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        Copy-ProjectInto -Dest $tmp
        # SetupFixtures is responsible for creating $tmp/fixtures with case data.
        & $SetupFixtures $tmp

        Push-Location $tmp
        try {
            git init -q
            git -c user.email=t@t -c user.name=t add -A
            git -c user.email=t@t -c user.name=t commit -q -m "case: $CaseName" | Out-Null

            $out = & act push --rm --pull=false 2>&1 | Out-String
            $exit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        $delim = ("=" * 70)
        Add-Content -LiteralPath $ActResultPath -Value "`n$delim`nCASE: $CaseName (exit=$exit)`n$delim`n$out"

        if ($exit -ne 0) { throw "act exited with $exit for case '$CaseName'" }

        # The workflow has two jobs; both must succeed.
        $succeededCount = ([regex]::Matches($out, '(?im)^\s*.*Job succeeded')).Count
        if ($succeededCount -lt 2) {
            throw "Expected >=2 'Job succeeded' markers, got $succeededCount for '$CaseName'."
        }

        foreach ($lit in $ExpectedLiterals) {
            if ($out -notlike "*$lit*") {
                throw "Case '$CaseName': expected literal '$lit' not found in act output."
            }
        }
        foreach ($lit in $UnexpectedLiterals) {
            if ($out -like "*$lit*") {
                throw "Case '$CaseName': unexpected literal '$lit' was present."
            }
        }

        Write-Host "PASS: $CaseName"
    } finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}

# ---------- Case 1: full default fixture set ----------
# 4 files: run1.xml (5 tests 3P/1F/1S), run1.json (3 tests 2P/1F),
# run2.xml (4 tests 3P/0F/1S), run3.xml (3 tests 2P/1F).
# Totals: 15 / 10P / 3F / 2S. Flaky: test_network (2P/1F).
$setupFull = {
    param($Dest)
    $src = Join-Path $ProjectRoot 'fixtures'
    Copy-Item -Recurse -Force $src (Join-Path $Dest 'fixtures') # overwrites empty dir
}
Invoke-ActCase -CaseName 'full-fixtures' `
    -SetupFixtures $setupFull `
    -ExpectedLiterals @(
        'TOTAL=15 PASSED=10 FAILED=3 SKIPPED=2 FLAKY=1',
        '# Test Results',
        '| Passed | 10 |',
        '| Failed | 3 |',
        '| Skipped | 2 |',
        'test_network'
    )

# ---------- Case 2: only-passing fixtures (no flaky, no failures) ----------
$setupClean = {
    param($Dest)
    $fx = Join-Path $Dest 'fixtures'
    Remove-Item -Recurse -Force $fx -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $fx | Out-Null
    @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="clean" tests="2" failures="0" skipped="0" time="0.04">
    <testcase classname="c.t" name="t_one" time="0.02"/>
    <testcase classname="c.t" name="t_two" time="0.02"/>
  </testsuite>
</testsuites>
'@ | Set-Content -LiteralPath (Join-Path $fx 'clean.xml') -Encoding utf8
}
Invoke-ActCase -CaseName 'all-passing' `
    -SetupFixtures $setupClean `
    -ExpectedLiterals @(
        'TOTAL=2 PASSED=2 FAILED=0 SKIPPED=0 FLAKY=0',
        'No flaky tests detected.'
    ) `
    -UnexpectedLiterals @('| Failed | 1 |')

Write-Host "`nAll act cases passed."
