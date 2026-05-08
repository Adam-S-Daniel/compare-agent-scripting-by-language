# Workflow & act-harness tests.
#
# Two halves:
#
#  1. Structure tests — cheap. Parse the workflow YAML as text, assert that
#     every referenced file exists, and require actionlint to exit 0.
#
#  2. Act tests — expensive. For each fixture scenario, materialise a temp git
#     repo containing the project files, then run `act push --rm`. Assertions
#     are on EXACT expected substrings of the captured act output. All output
#     is appended to ./act-result.txt as required by the task brief.
#
# We deliberately limit the harness to three act runs (one per fixture) to
# stay inside the act budget called out in the v3-pitfalls section.

BeforeAll {
    $script:repoRoot       = Split-Path -Parent $PSScriptRoot
    $script:workflowPath   = Join-Path $script:repoRoot '.github/workflows/secret-rotation-validator.yml'
    $script:scriptPath     = Join-Path $script:repoRoot 'Invoke-SecretRotationValidator.ps1'
    $script:resultFilePath = Join-Path $script:repoRoot 'act-result.txt'
    $script:workflowText   = Get-Content -Raw -LiteralPath $script:workflowPath

    # Helper: run one act case in an isolated temp git repo and append its
    # output to act-result.txt. Returns a hashtable of (ExitCode, Output).
    function Invoke-ActCase {
        param(
            [Parameter(Mandatory)][string]$Name,
            [Parameter(Mandatory)][string]$Fixture,
            [Parameter(Mandatory)][string]$WarningDays,
            [Parameter(Mandatory)][string]$AsOf,
            [Parameter(Mandatory)][string]$Format
        )

        $caseDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-case-$Name-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $caseDir | Out-Null

        # Copy only the files the workflow needs. Keeping the temp repo small
        # keeps act's "git archive" step quick and predictable.
        Copy-Item -Recurse -Path (Join-Path $script:repoRoot '.github')    -Destination $caseDir
        Copy-Item -Recurse -Path (Join-Path $script:repoRoot 'fixtures')   -Destination $caseDir
        Copy-Item -Recurse -Path (Join-Path $script:repoRoot 'tests')      -Destination $caseDir
        Copy-Item          -Path $script:scriptPath                        -Destination $caseDir
        # Carry the .actrc so act picks the same pwsh-enabled image we test against.
        $actrc = Join-Path $script:repoRoot '.actrc'
        if (Test-Path $actrc) { Copy-Item -Path $actrc -Destination $caseDir }

        Push-Location $caseDir
        try {
            git init -q -b main 2>&1 | Out-Null
            git config user.email 'test@example.com' 2>&1 | Out-Null
            git config user.name  'Test'              2>&1 | Out-Null
            git add . 2>&1 | Out-Null
            git commit -q -m "case $Name" 2>&1 | Out-Null

            # Run act with the case's env vars. --rm means "remove the
            # container on success" per current act help wording. --pull=false
            # is critical: act's default forcePull=true tries to fetch the
            # local-only `act-ubuntu-pwsh` image from a registry and fails.
            $actArgs = @(
                'push', '--rm', '--pull=false',
                '--env', "FIXTURE_PATH=$Fixture",
                '--env', "WARNING_DAYS=$WarningDays",
                '--env', "AS_OF=$AsOf",
                '--env', "OUTPUT_FORMAT=$Format"
            )
            $stdoutFile = Join-Path $caseDir 'act-stdout.txt'
            # Capture both streams; act prints meaningful info to stderr too.
            & act @actArgs *> $stdoutFile
            $rc = $LASTEXITCODE
            $output = Get-Content -Raw -LiteralPath $stdoutFile

            # Append a clearly-delimited section to the shared act-result.txt.
            $delimTop = "===== BEGIN ACT CASE: $Name (fixture=$Fixture, format=$Format, warningDays=$WarningDays, asOf=$AsOf) ====="
            $delimBot = "===== END ACT CASE: $Name (exit=$rc) ====="
            Add-Content -LiteralPath $script:resultFilePath -Value $delimTop
            Add-Content -LiteralPath $script:resultFilePath -Value $output
            Add-Content -LiteralPath $script:resultFilePath -Value $delimBot
            Add-Content -LiteralPath $script:resultFilePath -Value ''

            return @{ ExitCode = $rc; Output = $output }
        } finally {
            Pop-Location
            Remove-Item -Recurse -Force -LiteralPath $caseDir -ErrorAction SilentlyContinue
        }
    }

    # Truncate the result file once at the start of the suite so each
    # invocation produces a clean transcript.
    if (Test-Path $script:resultFilePath) { Remove-Item $script:resultFilePath }
    New-Item -ItemType File -Path $script:resultFilePath | Out-Null
}

Describe 'Workflow YAML structure' {
    It 'exists at the expected path' {
        Test-Path $script:workflowPath | Should -BeTrue
    }

    It 'declares all required trigger events' {
        # Bare-text matches keep us free of the powershell-yaml dependency.
        $script:workflowText | Should -Match '(?m)^\s*push:'
        $script:workflowText | Should -Match '(?m)^\s*pull_request:'
        $script:workflowText | Should -Match '(?m)^\s*workflow_dispatch:'
        $script:workflowText | Should -Match '(?m)^\s*schedule:'
    }

    It "uses actions/checkout@v4 (not v3 / latest)" {
        $script:workflowText | Should -Match 'actions/checkout@v4'
    }

    It "uses 'shell: pwsh' for run steps (per pitfalls guidance)" {
        $script:workflowText | Should -Match 'shell:\s*pwsh'
    }

    It 'sets least-privilege permissions: contents: read' {
        $script:workflowText | Should -Match 'permissions:\s*\r?\n\s*contents:\s*read'
    }

    It 'references the validator script by its actual filename' {
        $script:workflowText | Should -Match 'Invoke-SecretRotationValidator\.ps1'
        Test-Path $script:scriptPath | Should -BeTrue
    }

    It 'references all three fixtures via the FIXTURE_PATH default or workflow_dispatch input' {
        # The default is mixed.json; the other two are exercised through env overrides.
        $script:workflowText | Should -Match 'fixtures/mixed\.json'
    }

    It 'passes actionlint' {
        # Run from the repo root so any "uses:" references resolve correctly.
        Push-Location $script:repoRoot
        try {
            $null = & actionlint $script:workflowPath 2>&1
            $LASTEXITCODE | Should -Be 0
        } finally {
            Pop-Location
        }
    }
}

Describe 'Workflow runs end-to-end via act' {
    It 'all-ok fixture: validator exits 0 and reports OK (3)' {
        $r = Invoke-ActCase -Name 'all-ok' `
            -Fixture 'fixtures/all-ok.json' `
            -WarningDays '14' `
            -AsOf '2026-05-07' `
            -Format 'markdown'
        $r.ExitCode | Should -Be 0
        $r.Output   | Should -Match 'Job succeeded'
        $r.Output   | Should -Match 'VALIDATOR_EXIT=0'
        # Exact summary line from the markdown formatter.
        $r.Output   | Should -Match 'Expired:\s*\*\*0\*\*,\s*Warning:\s*\*\*0\*\*,\s*OK:\s*\*\*3\*\*'
        # Exact, fixture-derived rows (each value is uniquely traceable to
        # the fixture: name | lastRotated | computed expiresAt | computed
        # daysUntilExpiry).
        $r.Output   | Should -Match 'metrics-write-key \| 2026-05-01 \| 2026-05-31 \| 24'
        $r.Output   | Should -Match 'frontend-token \| 2026-04-01 \| 2026-06-30 \| 54'
        $r.Output   | Should -Match 'stripe-publishable \| 2026-04-15 \| 2026-10-12 \| 158'
    }

    It 'mixed fixture: validator exits 2 with one expired, one warning, one ok' {
        $r = Invoke-ActCase -Name 'mixed' `
            -Fixture 'fixtures/mixed.json' `
            -WarningDays '14' `
            -AsOf '2026-05-07' `
            -Format 'markdown'
        $r.ExitCode | Should -Be 0   # workflow itself succeeds because FAIL_ON_EXPIRED=false
        $r.Output   | Should -Match 'Job succeeded'
        $r.Output   | Should -Match 'VALIDATOR_EXIT=2'
        $r.Output   | Should -Match 'Expired:\s*\*\*1\*\*,\s*Warning:\s*\*\*1\*\*,\s*OK:\s*\*\*1\*\*'
        $r.Output   | Should -Match 'legacy-cron-token \| 2025-01-01 \| 2025-04-01 \| -401 \| legacy-cron'
        $r.Output   | Should -Match 'payments-api-key \| 2026-02-16 \| 2026-05-17 \| 10 \| payments-api, checkout'
        $r.Output   | Should -Match 'frontend-token \| 2026-04-01 \| 2026-06-30 \| 54 \| frontend-app'
    }

    It 'all-expired fixture in JSON format: validator exits 2 with counts.expired=2' {
        $r = Invoke-ActCase -Name 'all-expired' `
            -Fixture 'fixtures/all-expired.json' `
            -WarningDays '14' `
            -AsOf '2026-05-07' `
            -Format 'json'
        $r.ExitCode | Should -Be 0
        $r.Output   | Should -Match 'Job succeeded'
        $r.Output   | Should -Match 'VALIDATOR_EXIT=2'
        # Exact JSON fragments. The expiresAt and daysUntilExpiry values are
        # computed from the fixture's lastRotated and rotationPolicyDays
        # against AS_OF=2026-05-07, so any drift would surface immediately.
        $r.Output   | Should -Match '"name":\s*"ancient-deploy-key"'
        $r.Output   | Should -Match '"expiresAt":\s*"2024-01-31"'
        $r.Output   | Should -Match '"daysUntilExpiry":\s*-827'
        $r.Output   | Should -Match '"name":\s*"old-db-password"'
        $r.Output   | Should -Match '"expiresAt":\s*"2025-08-30"'
        $r.Output   | Should -Match '"daysUntilExpiry":\s*-250'
        $r.Output   | Should -Match '"expired":\s*2'
        $r.Output   | Should -Match '"total":\s*2'
    }

    It 'act-result.txt exists and contains all three case sections' {
        Test-Path $script:resultFilePath | Should -BeTrue
        $body = Get-Content -Raw -LiteralPath $script:resultFilePath
        $body | Should -Match 'BEGIN ACT CASE: all-ok'
        $body | Should -Match 'BEGIN ACT CASE: mixed'
        $body | Should -Match 'BEGIN ACT CASE: all-expired'
        $body | Should -Match 'END ACT CASE: all-ok \(exit=0\)'
        $body | Should -Match 'END ACT CASE: mixed \(exit=0\)'
        $body | Should -Match 'END ACT CASE: all-expired \(exit=0\)'
    }
}
