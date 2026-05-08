# Workflow.Tests.ps1
#
# Two suites:
#   1. Structural tests on .github/workflows/dependency-license-checker.yml
#      (triggers, jobs, steps, file references, actionlint).
#   2. Integration tests that drive the workflow with `act push --rm` against
#      isolated temp git repos for each fixture case. All act stdout/stderr
#      lands in act-result.txt at the project root, clearly delimited per case.
#
# The integration suite is tagged 'Act' so it can be skipped with
#   Invoke-Pester ./tests -ExcludeTagFilter Act
# in environments where docker / act are unavailable. By default it runs.

# Discovery-phase: probe for act + docker so -Skip flags below see real values.
# (BeforeAll runs at run-time, AFTER -Skip is evaluated, so a hasAct variable
# set in BeforeAll would still be $null when Pester decides whether to skip.)
$HasAct = ($null -ne (Get-Command act    -ErrorAction SilentlyContinue)) -and `
          ($null -ne (Get-Command docker -ErrorAction SilentlyContinue))

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:workflowPath = Join-Path $script:repoRoot '.github/workflows/dependency-license-checker.yml'
    $script:actLog = Join-Path $script:repoRoot 'act-result.txt'
    $script:hasAct = ($null -ne (Get-Command act    -ErrorAction SilentlyContinue)) -and `
                    ($null -ne (Get-Command docker -ErrorAction SilentlyContinue))

    if (-not (Test-Path -LiteralPath $script:workflowPath)) {
        throw "Workflow file missing: $script:workflowPath"
    }
    $script:workflowText = Get-Content -LiteralPath $script:workflowPath -Raw
}

Describe 'Workflow file structure' {

    It 'exists at the expected path' {
        Test-Path -LiteralPath $script:workflowPath | Should -BeTrue
    }

    It 'declares the standard CI trigger events' {
        $script:workflowText | Should -Match '(?ms)^on:'
        $script:workflowText | Should -Match '(?ms)^\s*push:'
        $script:workflowText | Should -Match '(?ms)^\s*pull_request:'
        $script:workflowText | Should -Match '(?ms)^\s*workflow_dispatch:'
        # schedule trigger lets us re-check transitive licenses periodically.
        $script:workflowText | Should -Match '(?ms)^\s*schedule:'
    }

    It 'declares least-privilege contents:read permissions' {
        $script:workflowText | Should -Match '(?ms)permissions:\s*\r?\n\s*contents:\s*read'
    }

    It 'pins actions/checkout to a major version' {
        $script:workflowText | Should -Match 'actions/checkout@v4'
    }

    It 'uses "shell: pwsh" on its run steps (PowerShell mode requirement)' {
        $script:workflowText | Should -Match 'shell:\s*pwsh'
    }

    It 'defines both pester-tests and license-check jobs' {
        $script:workflowText | Should -Match '(?m)^\s*pester-tests:'
        $script:workflowText | Should -Match '(?m)^\s*license-check:'
    }

    It 'wires license-check to depend on pester-tests' {
        $script:workflowText | Should -Match '(?m)needs:\s*pester-tests'
    }

    It 'references the actual entry-point script that exists in the repo' {
        $script:workflowText | Should -Match './src/Invoke-LicenseCheck\.ps1'
        Test-Path -LiteralPath (Join-Path $script:repoRoot 'src/Invoke-LicenseCheck.ps1') |
            Should -BeTrue
    }

    It 'references the Pester test file that exists in the repo' {
        $script:workflowText | Should -Match './tests/DependencyLicenseChecker\.Tests\.ps1'
        Test-Path -LiteralPath (Join-Path $script:repoRoot 'tests/DependencyLicenseChecker.Tests.ps1') |
            Should -BeTrue
    }

    It 'references license-config.json and license-database.json fixtures that exist' {
        $script:workflowText | Should -Match 'fixtures/license-config\.json'
        $script:workflowText | Should -Match 'fixtures/license-database\.json'
        Test-Path -LiteralPath (Join-Path $script:repoRoot 'fixtures/license-config.json')   | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:repoRoot 'fixtures/license-database.json') | Should -BeTrue
    }

    It 'passes actionlint cleanly (exit 0, no errors)' {
        $alOut = & actionlint $script:workflowPath 2>&1
        $alExit = $LASTEXITCODE
        if ($alExit -ne 0) {
            Write-Host ($alOut | Out-String)
        }
        $alExit | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# Integration tests via `act`.
#
# For each fixture case we create an isolated temp dir, copy the project
# files plus that case's fixture, init a throwaway git repo, and run
# `act push --rm` once. Output is captured, appended to act-result.txt
# (the required artifact), and asserted on for both job success and
# specific report content matching that fixture's known-good output.
# ---------------------------------------------------------------------------

Describe 'Workflow integration via act' -Tag 'Act' {

    BeforeAll {
        # Make sure act and docker are present; otherwise the suite would
        # produce inscrutable errors. If we have to skip, we still leave
        # the act-result.txt artifact in place with an explanatory header.
        $script:actExe    = (Get-Command act -ErrorAction SilentlyContinue)?.Path
        $script:dockerExe = (Get-Command docker -ErrorAction SilentlyContinue)?.Path
        $script:hasAct    = ($null -ne $script:actExe) -and ($null -ne $script:dockerExe)

        # Reset the artifact so each Pester run starts clean. Keeping append
        # semantics within a run lets multiple cases accumulate.
        $hdr = @"
# act-result.txt
# Generated by tests/Workflow.Tests.ps1 on $((Get-Date).ToUniversalTime().ToString('o'))
# Each section below is the captured stdout/stderr of one ``act push --rm`` run
# against an isolated temp git repo seeded with one fixture case.

"@
        Set-Content -LiteralPath $script:actLog -Value $hdr -Encoding utf8

        if (-not $script:hasAct) {
            Add-Content -LiteralPath $script:actLog -Value "(act or docker not found on PATH; integration cases skipped)`n"
        }

        # Helper: stage an isolated temp git repo containing project files
        # plus the named fixture, run act, return @{ Output; Exit; TempDir }.
        function Invoke-ActCase {
            param(
                [Parameter(Mandatory)][string]$CaseName,
                [Parameter(Mandatory)][string]$ManifestPath,   # repo-relative
                [Parameter(Mandatory)][bool]  $FailOnViolation
            )

            $stage = Join-Path ([System.IO.Path]::GetTempPath()) "act-$CaseName-$([Guid]::NewGuid())"
            New-Item -ItemType Directory -Path $stage | Out-Null

            # Mirror the project tree the workflow needs.
            foreach ($entry in 'src', 'tests', 'fixtures', '.github', '.actrc') {
                $src = Join-Path $script:repoRoot $entry
                if (Test-Path -LiteralPath $src) {
                    Copy-Item -LiteralPath $src -Destination $stage -Recurse -Force
                }
            }

            Push-Location $stage
            try {
                # Init a throwaway repo (act needs a git repo to discover events).
                git init -b main *>$null
                git -c user.email='test@test.test' -c user.name='test' add -A *>$null
                git -c user.email='test@test.test' -c user.name='test' commit -m 'init' *>$null

                $failFlag = if ($FailOnViolation) { 'true' } else { 'false' }
                $envArgs = @(
                    '--env', "TEST_MANIFEST_PATH=$ManifestPath",
                    '--env', "TEST_FAIL_ON_VIOLATION=$failFlag"
                )
                # --pull=false: the act-ubuntu-pwsh image is built locally and
                # not in any registry, so we must skip the registry pull that
                # act otherwise does on every run.
                # .actrc in the staged repo pins ubuntu-latest to that image.
                $output = & act push --rm --pull=false @envArgs 2>&1 | Out-String
                $exit   = $LASTEXITCODE
            } finally {
                Pop-Location
            }

            return @{
                Output  = $output
                Exit    = $exit
                TempDir = $stage
            }
        }
    }

    Context 'Case 1: package.json with mixed Approved/Denied/Unknown licenses' {

        BeforeAll {
            if (-not $script:hasAct) { return }
            $script:case1 = Invoke-ActCase `
                -CaseName 'case1' `
                -ManifestPath 'fixtures/case1/package.json' `
                -FailOnViolation $false

            $delim = "`n=== CASE 1: fixtures/case1/package.json (mixed licenses, FAIL_ON_VIOLATION=false) ===`n"
            Add-Content -LiteralPath $script:actLog -Value $delim
            Add-Content -LiteralPath $script:actLog -Value $script:case1.Output
            Add-Content -LiteralPath $script:actLog -Value "[exit code: $($script:case1.Exit)]`n"
        }

        It 'act exits with code 0' -Skip:(-not $HasAct) {
            $script:case1.Exit | Should -Be 0
        }

        It 'every job reports "Job succeeded"' -Skip:(-not $HasAct) {
            # We expect 2 "Job succeeded" lines: pester-tests + license-check.
            $count = ([regex]::Matches($script:case1.Output, 'Job succeeded')).Count
            $count | Should -BeGreaterOrEqual 2
        }

        It 'reports react@18.2.0 as Approved (license MIT)' -Skip:(-not $HasAct) {
            $script:case1.Output | Should -Match '\[Approved\]\s+react@18\.2\.0\s+license=MIT'
        }

        It 'reports lodash@4.17.21 as Approved (license MIT)' -Skip:(-not $HasAct) {
            $script:case1.Output | Should -Match '\[Approved\]\s+lodash@4\.17\.21\s+license=MIT'
        }

        It 'reports evil-gpl-lib@1.0.0 as Denied (license GPL-3.0)' -Skip:(-not $HasAct) {
            $script:case1.Output | Should -Match '\[Denied\]\s+evil-gpl-lib@1\.0\.0\s+license=GPL-3\.0'
        }

        It 'reports mystery-pkg@0.1.0 as Unknown' -Skip:(-not $HasAct) {
            $script:case1.Output | Should -Match '\[Unknown\]\s+mystery-pkg@0\.1\.0'
        }

        It 'shows the exact summary "Total: 4  Approved: 2  Denied: 1  Unknown: 1"' -Skip:(-not $HasAct) {
            $script:case1.Output | Should -Match 'Total:\s*4\s+Approved:\s*2\s+Denied:\s*1\s+Unknown:\s*1'
        }

        It 'records the license-check script exit code as 1' -Skip:(-not $HasAct) {
            $script:case1.Output | Should -Match 'license-check-exit-code:\s*1'
        }

        It 'runs the Pester unit-test suite inside the workflow with 19 passes' -Skip:(-not $HasAct) {
            $script:case1.Output | Should -Match 'Tests Passed:\s*19'
        }
    }

    Context 'Case 2: requirements.txt with all-Approved licenses' {

        BeforeAll {
            if (-not $script:hasAct) { return }
            $script:case2 = Invoke-ActCase `
                -CaseName 'case2' `
                -ManifestPath 'fixtures/case2/requirements.txt' `
                -FailOnViolation $true

            $delim = "`n=== CASE 2: fixtures/case2/requirements.txt (all-approved, FAIL_ON_VIOLATION=true) ===`n"
            Add-Content -LiteralPath $script:actLog -Value $delim
            Add-Content -LiteralPath $script:actLog -Value $script:case2.Output
            Add-Content -LiteralPath $script:actLog -Value "[exit code: $($script:case2.Exit)]`n"
        }

        It 'act exits with code 0' -Skip:(-not $HasAct) {
            $script:case2.Exit | Should -Be 0
        }

        It 'every job reports "Job succeeded"' -Skip:(-not $HasAct) {
            $count = ([regex]::Matches($script:case2.Output, 'Job succeeded')).Count
            $count | Should -BeGreaterOrEqual 2
        }

        It 'reports requests@2.31.0 as Approved (license Apache-2.0)' -Skip:(-not $HasAct) {
            $script:case2.Output | Should -Match '\[Approved\]\s+requests@2\.31\.0\s+license=Apache-2\.0'
        }

        It 'reports pytest@7.4.0 as Approved (license MIT)' -Skip:(-not $HasAct) {
            $script:case2.Output | Should -Match '\[Approved\]\s+pytest@7\.4\.0\s+license=MIT'
        }

        It 'reports flask@2.3.3 as Approved (license BSD-3-Clause)' -Skip:(-not $HasAct) {
            $script:case2.Output | Should -Match '\[Approved\]\s+flask@2\.3\.3\s+license=BSD-3-Clause'
        }

        It 'shows the exact summary "Total: 3  Approved: 3  Denied: 0  Unknown: 0"' -Skip:(-not $HasAct) {
            $script:case2.Output | Should -Match 'Total:\s*3\s+Approved:\s*3\s+Denied:\s*0\s+Unknown:\s*0'
        }

        It 'records the license-check script exit code as 0' -Skip:(-not $HasAct) {
            $script:case2.Output | Should -Match 'license-check-exit-code:\s*0'
        }
    }
}
