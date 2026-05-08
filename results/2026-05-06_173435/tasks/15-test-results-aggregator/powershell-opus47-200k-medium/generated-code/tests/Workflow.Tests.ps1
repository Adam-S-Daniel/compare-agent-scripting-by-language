# Workflow + act integration tests.
#
# These tests exercise the GitHub Actions workflow end-to-end. For each
# test case we set up an isolated temp directory with a copy of the
# project + that case's fixture data, run `act push --rm`, append the
# output to act-result.txt (a required artifact), and assert on the
# exact aggregate line for that input.
#
# To stay under the 3-`act push` budget, we batch the three cases as
# three sequential runs (one per case) and avoid retries.

BeforeDiscovery {
    $script:RepoRoot     = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:WorkflowFile = Join-Path $script:RepoRoot '.github/workflows/test-results-aggregator.yml'
    $script:ActResultLog = Join-Path $script:RepoRoot 'act-result.txt'
    $script:CasesRoot    = Join-Path $script:RepoRoot 'test-cases'

    # Each case: a directory containing test result fixtures + an expected
    # aggregate line emitted by Aggregate-TestResults.ps1.
    $script:Cases = @(
        @{ Name = 'mixed-flaky'
           # Two runs: same suite of three tests; one test flakes between runs.
           Files = @(
              @{ Path='runA.xml';  Content = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="s" tests="3" failures="1" time="1.0">
  <testcase classname="c" name="alpha" time="0.1"/>
  <testcase classname="c" name="beta"  time="0.4"><failure message="bad"/></testcase>
  <testcase classname="c" name="gamma" time="0.5"/>
</testsuite>
'@ },
              @{ Path='runB.json'; Content = @'
{"suite":"s","duration":1.0,"tests":[
  {"classname":"c","name":"alpha","status":"passed","duration":0.1},
  {"classname":"c","name":"beta","status":"passed","duration":0.4},
  {"classname":"c","name":"gamma","status":"passed","duration":0.5}
]}
'@ }
           )
           Expected = 'AGGREGATE: runs=2 total=6 passed=5 failed=1 skipped=0 flaky=1 duration=2'
        },
        @{ Name = 'all-green'
           Files = @(
              @{ Path='r1.json'; Content = '{"suite":"g","duration":0.5,"tests":[{"classname":"c","name":"a","status":"passed","duration":0.5}]}' },
              @{ Path='r2.json'; Content = '{"suite":"g","duration":0.5,"tests":[{"classname":"c","name":"a","status":"passed","duration":0.5}]}' }
           )
           Expected = 'AGGREGATE: runs=2 total=2 passed=2 failed=0 skipped=0 flaky=0 duration=1'
        },
        @{ Name = 'always-failing'
           Files = @(
              @{ Path='only.xml'; Content = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="x" tests="2" failures="2" time="0.3">
  <testcase classname="c" name="bad1" time="0.1"><failure message="oops"/></testcase>
  <testcase classname="c" name="bad2" time="0.2"><error message="explode"/></testcase>
</testsuite>
'@ }
           )
           Expected = 'AGGREGATE: runs=1 total=2 passed=0 failed=2 skipped=0 flaky=0 duration=0.3'
        }
    )
}

BeforeAll {
    $script:RepoRoot     = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:WorkflowFile = Join-Path $script:RepoRoot '.github/workflows/test-results-aggregator.yml'
    $script:ActResultLog = Join-Path $script:RepoRoot 'act-result.txt'
    # Reset the act result log at the start of the run.
    Set-Content -LiteralPath $script:ActResultLog -Value '' -Encoding UTF8
}

Describe 'Workflow structure' {
    It 'exists and references the aggregator script' {
        Test-Path $script:WorkflowFile | Should -BeTrue
        $content = Get-Content -LiteralPath $script:WorkflowFile -Raw
        $content | Should -Match 'scripts/Aggregate-TestResults\.ps1'
        # The script path must actually exist.
        Test-Path (Join-Path $script:RepoRoot 'scripts/Aggregate-TestResults.ps1') | Should -BeTrue
    }

    It 'declares the required triggers and a job' {
        $content = Get-Content -LiteralPath $script:WorkflowFile -Raw
        $content | Should -Match '(?m)^on:'
        $content | Should -Match 'push:'
        $content | Should -Match 'pull_request:'
        $content | Should -Match 'workflow_dispatch:'
        $content | Should -Match '(?m)^jobs:'
        $content | Should -Match 'runs-on:\s*ubuntu-latest'
        $content | Should -Match 'actions/checkout@v4'
        $content | Should -Match 'shell:\s*pwsh'
    }

    It 'passes actionlint' {
        $out = & actionlint $script:WorkflowFile 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $out"
    }
}

Describe 'Workflow runs under act' -Tag 'act' {
    BeforeAll {
        $script:ActBin = (Get-Command act -ErrorAction Stop).Source
    }

    It 'runs case <_.Name> through act and produces the expected aggregate' -ForEach $script:Cases {
        $case   = $_
        $caseId = $case.Name

        # Build an isolated temp directory: copy project files, replace fixtures
        # with this case's inputs, init a git repo (act needs one), and run act.
        $work = Join-Path ([System.IO.Path]::GetTempPath()) "agg-$caseId-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $work | Out-Null

        try {
            # Copy project files we need (skip .git, large/unnecessary dirs).
            foreach ($d in 'src','scripts','tests','.github') {
                Copy-Item -Recurse -Force (Join-Path $script:RepoRoot $d) (Join-Path $work $d)
            }
            # Strip the original fixtures and write this case's files into a
            # case-specific fixtures dir.
            Remove-Item -Recurse -Force (Join-Path $work 'tests/fixtures')
            $fxDir = Join-Path $work 'tests/fixtures'
            New-Item -ItemType Directory -Path $fxDir | Out-Null
            foreach ($f in $case.Files) {
                Set-Content -LiteralPath (Join-Path $fxDir $f.Path) -Value $f.Content -Encoding UTF8
            }
            # Drop the workflow tests file inside the temp project; we don't
            # want act re-running this Describe inside the container.
            Remove-Item -Force (Join-Path $work 'tests/Workflow.Tests.ps1') -ErrorAction SilentlyContinue

            # Pin act to the pre-built pwsh image (mirrors the .actrc at repo root).
            Set-Content -LiteralPath (Join-Path $work '.actrc') `
                -Value '-P ubuntu-latest=act-ubuntu-pwsh:latest' -Encoding UTF8

            Push-Location $work
            try {
                & git init -q
                & git config user.email 'ci@example.com'
                & git config user.name 'ci'
                & git add -A
                & git commit -q -m "case $caseId" | Out-Null

                # --pull=false: the pwsh runner image is local-only; act's default
                # forcePull=true causes a registry lookup that fails.
                $output = & $script:ActBin push --rm --pull=false 2>&1 | Out-String
                $exit = $LASTEXITCODE
            } finally {
                Pop-Location
            }

            $delim = "===== CASE: $caseId (exit=$exit) ====="
            Add-Content -LiteralPath $script:ActResultLog -Value $delim
            Add-Content -LiteralPath $script:ActResultLog -Value $output
            Add-Content -LiteralPath $script:ActResultLog -Value ''

            $exit   | Should -Be 0 -Because "act failed for case $caseId. Output:`n$output"
            $output | Should -Match 'Job succeeded' -Because "case $caseId did not show 'Job succeeded'"
            $output | Should -Match ([regex]::Escape("RESULT_LINE: $($case.Expected)")) `
                -Because "case $caseId expected '$($case.Expected)' in output:`n$output"
        }
        finally {
            if (Test-Path $work) { Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue }
        }
    }
}
