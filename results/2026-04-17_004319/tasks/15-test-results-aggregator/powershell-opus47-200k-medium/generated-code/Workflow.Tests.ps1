# Workflow + act integration tests.
# - Validates the YAML structure and references.
# - Runs `act push --rm` against 3 fixture variants in isolated temp repos.
# - Appends all act output to ./act-result.txt in the working directory.
# - Asserts exit code 0 and exact expected totals per case.

BeforeAll {
    $ProjectRoot = $PSScriptRoot
    $WorkflowPath = Join-Path $ProjectRoot '.github/workflows/test-results-aggregator.yml'
    $ActResultFile = Join-Path $ProjectRoot 'act-result.txt'
    if (Test-Path $ActResultFile) { Remove-Item $ActResultFile -Force }

    function Invoke-ActCase {
        param(
            [string]$CaseName,
            [hashtable]$Fixtures,   # relative path -> content
            [hashtable]$Expected    # TOTAL/PASSED/FAILED/SKIPPED/FLAKY_COUNT
        )
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("act-case-" + [Guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            # Copy project files (module, script, tests, workflow, .actrc).
            Copy-Item (Join-Path $ProjectRoot 'Aggregator.psm1')        $tmp
            Copy-Item (Join-Path $ProjectRoot 'Aggregator.Tests.ps1')   $tmp
            Copy-Item (Join-Path $ProjectRoot 'Invoke-AggregatorCli.ps1') $tmp
            Copy-Item (Join-Path $ProjectRoot '.actrc')                 $tmp
            New-Item -ItemType Directory -Path (Join-Path $tmp '.github/workflows') -Force | Out-Null
            Copy-Item $WorkflowPath (Join-Path $tmp '.github/workflows/test-results-aggregator.yml')

            # Write fixture data for this case.
            foreach ($rel in $Fixtures.Keys) {
                $p = Join-Path $tmp $rel
                $dir = Split-Path -Parent $p
                if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                Set-Content -LiteralPath $p -Value $Fixtures[$rel] -Encoding utf8
            }

            # act requires a git repo.
            Push-Location $tmp
            try {
                git init -q
                git add -A
                git -c user.email=t@t -c user.name=t commit -q -m "case $CaseName" | Out-Null
                $log = & act push --rm 2>&1
                $exit = $LASTEXITCODE
            } finally { Pop-Location }

            $header = "`n===== CASE: $CaseName (exit=$exit) =====`n"
            Add-Content -LiteralPath $ActResultFile -Value $header
            Add-Content -LiteralPath $ActResultFile -Value ($log -join "`n")

            return [pscustomobject]@{ Exit = $exit; Log = ($log -join "`n"); Expected = $Expected }
        } finally {
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Workflow structure' {
    It 'exists at the expected path' {
        Test-Path $WorkflowPath | Should -BeTrue
    }

    It 'passes actionlint' {
        $null = & actionlint $WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }

    It 'declares push, pull_request, and workflow_dispatch triggers' {
        $content = Get-Content $WorkflowPath -Raw
        $content | Should -Match '(?m)^\s*push:'
        $content | Should -Match '(?m)^\s*pull_request:'
        $content | Should -Match '(?m)^\s*workflow_dispatch:'
    }

    It 'references script files that actually exist' {
        $content = Get-Content $WorkflowPath -Raw
        $content | Should -Match 'Invoke-AggregatorCli\.ps1'
        Test-Path (Join-Path $ProjectRoot 'Aggregator.Tests.ps1')   | Should -BeTrue
        Test-Path (Join-Path $ProjectRoot 'Invoke-AggregatorCli.ps1') | Should -BeTrue
        Test-Path (Join-Path $ProjectRoot 'Aggregator.psm1')        | Should -BeTrue
    }

    It 'uses actions/checkout@v4' {
        (Get-Content $WorkflowPath -Raw) | Should -Match 'actions/checkout@v4'
    }
}

Describe 'act integration' {
    BeforeAll {
        # --- Case 1: full fixture set (matrix of 2 runs). ---
        $case1 = @{
            'fixtures/run1/junit.xml' = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="SuiteA" tests="3" failures="1" skipped="1" time="0.600">
    <testcase classname="SuiteA" name="test_add" time="0.100"/>
    <testcase classname="SuiteA" name="test_divide" time="0.200"><failure message="bad"/></testcase>
    <testcase classname="SuiteA" name="test_legacy" time="0.300"><skipped/></testcase>
  </testsuite>
</testsuites>
'@
            'fixtures/run1/results.json' = '{"tests":[{"name":"SuiteB.test_http","status":"passed","duration":0.45},{"name":"SuiteB.test_flaky","status":"passed","duration":0.10}]}'
            'fixtures/run2/junit.xml' = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="SuiteA" tests="3" failures="0" skipped="1" time="0.500">
    <testcase classname="SuiteA" name="test_add" time="0.100"/>
    <testcase classname="SuiteA" name="test_divide" time="0.200"/>
    <testcase classname="SuiteA" name="test_legacy" time="0.200"><skipped/></testcase>
  </testsuite>
</testsuites>
'@
            'fixtures/run2/results.json' = '{"tests":[{"name":"SuiteB.test_http","status":"passed","duration":0.50},{"name":"SuiteB.test_flaky","status":"failed","duration":0.12}]}'
        }
        $script:Result1 = Invoke-ActCase -CaseName 'full-matrix' -Fixtures $case1 -Expected @{
            TOTAL=10; PASSED=6; FAILED=2; SKIPPED=2; FLAKY_COUNT=2
        }

        # --- Case 2: all-green single run, no flaky. ---
        $case2 = @{
            'fixtures/only/results.json' = '{"tests":[{"name":"t1","status":"passed","duration":0.1},{"name":"t2","status":"passed","duration":0.2}]}'
        }
        $script:Result2 = Invoke-ActCase -CaseName 'all-green' -Fixtures $case2 -Expected @{
            TOTAL=2; PASSED=2; FAILED=0; SKIPPED=0; FLAKY_COUNT=0
        }

        # --- Case 3: JUnit-only, includes one failure and one skip. ---
        $case3 = @{
            'fixtures/xml/junit.xml' = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="OnlyXml" tests="4" failures="1" skipped="1" time="1.000">
  <testcase classname="X" name="a" time="0.250"/>
  <testcase classname="X" name="b" time="0.250"/>
  <testcase classname="X" name="c" time="0.250"><failure message="x"/></testcase>
  <testcase classname="X" name="d" time="0.250"><skipped/></testcase>
</testsuite>
'@
        }
        $script:Result3 = Invoke-ActCase -CaseName 'junit-only' -Fixtures $case3 -Expected @{
            TOTAL=4; PASSED=2; FAILED=1; SKIPPED=1; FLAKY_COUNT=0
        }

        $script:AllResults = @($Result1, $Result2, $Result3)
    }

    It 'all three cases exited 0' {
        foreach ($r in $AllResults) { $r.Exit | Should -Be 0 }
    }

    It 'all three cases show "Job succeeded"' {
        foreach ($r in $AllResults) { $r.Log | Should -Match 'Job succeeded' }
    }

    It 'case 1 (full matrix) produces exact expected totals' {
        $log = $Result1.Log
        $log | Should -Match 'TOTAL=10'
        $log | Should -Match 'PASSED=6'
        $log | Should -Match 'FAILED=2'
        $log | Should -Match 'SKIPPED=2'
        $log | Should -Match 'FLAKY_COUNT=2'
        $log | Should -Match 'SuiteA\.test_divide'
        $log | Should -Match 'SuiteB\.test_flaky'
    }

    It 'case 2 (all green) produces exact expected totals' {
        $log = $Result2.Log
        $log | Should -Match 'TOTAL=2'
        $log | Should -Match 'PASSED=2'
        $log | Should -Match 'FAILED=0'
        $log | Should -Match 'FLAKY_COUNT=0'
        $log | Should -Match 'SUCCESS'
    }

    It 'case 3 (junit-only) produces exact expected totals' {
        $log = $Result3.Log
        $log | Should -Match 'TOTAL=4'
        $log | Should -Match 'PASSED=2'
        $log | Should -Match 'FAILED=1'
        $log | Should -Match 'SKIPPED=1'
        $log | Should -Match 'FLAKY_COUNT=0'
    }

    It 'act-result.txt was created' {
        Test-Path $ActResultFile | Should -BeTrue
    }
}
