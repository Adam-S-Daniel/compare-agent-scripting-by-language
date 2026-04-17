# WorkflowHarness.Tests.ps1
#
# Exercises the GitHub Actions workflow via nektos/act for every behavioural
# test case. Each case:
#   1. Copies project files + case-specific fixture into a temp git repo.
#   2. Runs `act push --rm` once.
#   3. Appends the output to ./act-result.txt (delimited).
#   4. Asserts act exited 0, every job reports success, and the SUMMARY_*
#      lines match the exact pre-computed expected values.
#
# Also includes workflow-structure tests: YAML parses, referenced script
# files exist, actionlint passes cleanly.

BeforeDiscovery {
    $script:HarnessRoot = $PSScriptRoot
    $script:ActResultPath = Join-Path $script:HarnessRoot 'act-result.txt'

    # Bail early if act isn't available — the environment promises it is.
    $script:ActBin = (Get-Command act -ErrorAction SilentlyContinue)?.Source
    if (-not $script:ActBin) {
        throw 'act is required but not found on PATH.'
    }

    # Each case feeds a fixture into the workflow and expects specific counts.
    # The expected values are pre-computed by hand from the fixture data at
    # VALIDATOR_NOW=2026-04-17, WARNING_DAYS=14 (unless overridden via warning_days).
    #
    # Case 1 (baseline): 2 expired, 0 warning, 2 ok
    #   prod-api-token  2025-08-01 +90d = 2025-10-30  -> expired (-169)
    #   db-admin-pwd    2026-04-10 +30d = 2026-05-10  -> ok (+23)
    #   stripe-webhook  2026-02-10 +60d = 2026-04-11  -> expired (-6)
    #   long-ci-token   2026-03-01 +365d= 2027-03-01  -> ok (+318)
    #
    # Case 2 (all-warning): 0 expired, 3 warning, 0 ok
    #   w1 2026-04-10 +14d = 2026-04-24  -> 7 days   -> warning
    #   w2 2026-04-10 +17d = 2026-04-27  -> 10 days  -> warning
    #   w3 2026-04-10 +21d = 2026-05-01  -> 14 days  -> warning (boundary)
    #
    # Case 3 (empty): 0 everything
    $script:Cases = @(
        @{
            Name      = 'baseline'
            FixtureJson = @'
{
  "secrets": [
    { "name": "prod-api-token",      "lastRotated": "2025-08-01", "rotationDays": 90,  "requiredBy": ["gateway","worker"] },
    { "name": "db-admin-password",   "lastRotated": "2026-04-10", "rotationDays": 30,  "requiredBy": ["payments-db"] },
    { "name": "stripe-webhook",      "lastRotated": "2026-02-10", "rotationDays": 60,  "requiredBy": ["billing"] },
    { "name": "long-lived-ci-token", "lastRotated": "2026-03-01", "rotationDays": 365, "requiredBy": ["ci"] }
  ]
}
'@
            Expected  = @{ Expired = 2; Warning = 0; Ok = 2; Total = 4 }
        }
        @{
            Name      = 'all-warning'
            FixtureJson = @'
{
  "secrets": [
    { "name": "w1", "lastRotated": "2026-04-10", "rotationDays": 14, "requiredBy": ["svc-a"] },
    { "name": "w2", "lastRotated": "2026-04-10", "rotationDays": 17, "requiredBy": ["svc-b"] },
    { "name": "w3", "lastRotated": "2026-04-10", "rotationDays": 21, "requiredBy": ["svc-c"] }
  ]
}
'@
            Expected  = @{ Expired = 0; Warning = 3; Ok = 0; Total = 3 }
        }
        @{
            Name      = 'empty'
            FixtureJson = '{ "secrets": [] }'
            Expected   = @{ Expired = 0; Warning = 0; Ok = 0; Total = 0 }
        }
    )
}

BeforeAll {
    $script:HarnessRoot = $PSScriptRoot
    $script:ActResultPath = Join-Path $script:HarnessRoot 'act-result.txt'

    # Start each run with a clean act-result.txt so old output can't mask regressions.
    if (Test-Path $script:ActResultPath) { Remove-Item $script:ActResultPath -Force }

    # Files that make up the project — everything else (including .git)
    # is regenerated in the temp repo to avoid dragging in session cruft.
    $script:ProjectFiles = @(
        'SecretRotationValidator.psm1',
        'SecretRotationValidator.Tests.ps1',
        'Invoke-SecretRotationValidator.ps1',
        '.actrc'
    )
    $script:WorkflowRel = '.github/workflows/secret-rotation-validator.yml'

    # --- helper: run one act case ------------------------------------------
    function script:Invoke-ActCase {
        param(
            [Parameter(Mandatory)][string] $CaseName,
            [Parameter(Mandatory)][string] $FixtureJson
        )
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("secret-rot-$CaseName-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            # Copy project files into temp dir.
            foreach ($f in $script:ProjectFiles) {
                Copy-Item (Join-Path $script:HarnessRoot $f) (Join-Path $tmp $f) -Force
            }
            # Workflow directory.
            New-Item -ItemType Directory -Path (Join-Path $tmp '.github/workflows') -Force | Out-Null
            Copy-Item (Join-Path $script:HarnessRoot $script:WorkflowRel) (Join-Path $tmp $script:WorkflowRel) -Force

            # Fixture dir with the case-specific JSON.
            New-Item -ItemType Directory -Path (Join-Path $tmp 'fixtures') -Force | Out-Null
            Set-Content -Path (Join-Path $tmp 'fixtures/secrets.json') -Value $FixtureJson -Encoding utf8 -NoNewline

            # act needs a git repo with at least one commit, else the push
            # trigger sees nothing. Silence git noise.
            Push-Location $tmp
            try {
                git init --quiet --initial-branch=main 2>&1 | Out-Null
                git -c user.email=a@b -c user.name=a add . 2>&1 | Out-Null
                git -c user.email=a@b -c user.name=a commit --quiet -m 'fixture' 2>&1 | Out-Null

                $output = & act push --rm 2>&1 | Out-String
                $exit = $LASTEXITCODE
            } finally {
                Pop-Location
            }

            # Append delimited output for the required artifact.
            $delim = "`n============================================================`n"
            $block = "CASE: $CaseName`nEXIT: $exit`n$delim$output$delim"
            Add-Content -Path $script:ActResultPath -Value $block

            return [pscustomobject]@{ Case = $CaseName; Exit = $exit; Output = $output }
        } finally {
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Workflow structure' {
    It 'YAML file exists at the expected path' {
        Test-Path (Join-Path $PSScriptRoot '.github/workflows/secret-rotation-validator.yml') | Should -BeTrue
    }

    It 'actionlint passes cleanly (exit 0)' {
        $out = & actionlint (Join-Path $PSScriptRoot '.github/workflows/secret-rotation-validator.yml') 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $out"
    }

    It 'defines the expected triggers (push, pull_request, workflow_dispatch, schedule)' {
        $yaml = Get-Content (Join-Path $PSScriptRoot '.github/workflows/secret-rotation-validator.yml') -Raw
        $yaml | Should -Match '(?m)^on:\s*$'
        $yaml | Should -Match '(?m)^\s*push:'
        $yaml | Should -Match '(?m)^\s*pull_request:'
        $yaml | Should -Match '(?m)^\s*workflow_dispatch:'
        $yaml | Should -Match '(?m)^\s*schedule:'
    }

    It 'defines the expected jobs (test, validate)' {
        $yaml = Get-Content (Join-Path $PSScriptRoot '.github/workflows/secret-rotation-validator.yml') -Raw
        $yaml | Should -Match '(?m)^\s*test:'
        $yaml | Should -Match '(?m)^\s*validate:'
        $yaml | Should -Match '(?m)^\s*needs:\s*test'
    }

    It 'references project script files that exist on disk' {
        $yaml = Get-Content (Join-Path $PSScriptRoot '.github/workflows/secret-rotation-validator.yml') -Raw
        $expectedRefs = @(
            'SecretRotationValidator.Tests.ps1',
            'Invoke-SecretRotationValidator.ps1',
            'fixtures/secrets.json'
        )
        foreach ($ref in $expectedRefs) {
            $yaml | Should -Match ([regex]::Escape($ref))
        }
        (Test-Path (Join-Path $PSScriptRoot 'SecretRotationValidator.Tests.ps1')) | Should -BeTrue
        (Test-Path (Join-Path $PSScriptRoot 'Invoke-SecretRotationValidator.ps1')) | Should -BeTrue
        # fixtures/secrets.json is written per-case by the harness; at minimum the baseline ships with the repo.
        (Test-Path (Join-Path $PSScriptRoot 'fixtures/secrets.json')) | Should -BeTrue
    }
}

Describe 'End-to-end via act' {
    # One run per case. Discovery-time foreach so cases expand into
    # individual It blocks in the report.
    It 'case <_.Name>: act succeeds and summary matches expected (E=<_.Expected.Expired> W=<_.Expected.Warning> O=<_.Expected.Ok> T=<_.Expected.Total>)' -ForEach $script:Cases {
        $result = script:Invoke-ActCase -CaseName $_.Name -FixtureJson $_.FixtureJson

        $result.Exit | Should -Be 0 -Because "act output:`n$($result.Output)"

        # Both jobs should report success.
        $successMatches = [regex]::Matches($result.Output, 'Job succeeded')
        $successMatches.Count | Should -BeGreaterOrEqual 2 -Because "act output:`n$($result.Output)"

        # Exact-value assertions on the SUMMARY_* lines emitted by the workflow.
        $expected = $_.Expected
        $result.Output | Should -Match ("SUMMARY_EXPIRED=$($expected.Expired)\b")
        $result.Output | Should -Match ("SUMMARY_WARNING=$($expected.Warning)\b")
        $result.Output | Should -Match ("SUMMARY_OK=$($expected.Ok)\b")
        $result.Output | Should -Match ("SUMMARY_TOTAL=$($expected.Total)\b")

        # The report JSON delimiters prove the CLI wrote actual JSON, not just a summary.
        $result.Output | Should -Match 'BEGIN REPORT JSON'
        $result.Output | Should -Match 'END REPORT JSON'
    }

    It 'act-result.txt exists and contains all case outputs' {
        Test-Path $script:ActResultPath | Should -BeTrue
        $content = Get-Content $script:ActResultPath -Raw
        foreach ($c in $script:Cases) {
            $content | Should -Match "CASE: $([regex]::Escape($c.Name))"
        }
    }
}
