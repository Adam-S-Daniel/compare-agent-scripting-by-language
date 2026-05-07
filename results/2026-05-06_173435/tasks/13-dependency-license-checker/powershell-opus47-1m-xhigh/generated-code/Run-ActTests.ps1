#!/usr/bin/env pwsh
# Run-ActTests.ps1
#
# End-to-end integration harness. For each test case it:
#   1. Sets up a temp git repo containing the project files plus that
#      case's fixture data (manifest + policy + test-config.env override).
#   2. Runs `act push --rm` against the GitHub Actions workflow, capturing
#      every byte of stdout/stderr.
#   3. Appends the full captured output to act-result.txt with a clear
#      delimiter so post-mortem inspection is easy.
#   4. Asserts: act exit code == 0, every job shows "Job succeeded",
#      and the captured report contains the EXACT expected verdicts.
#
# Capped at 3 act runs per benchmark guidance.
#
# Also runs:
#   - Workflow STRUCTURE tests (parse YAML, verify file paths, run actionlint)
#     in-process via Pester — these are not "test cases", they are static
#     checks of the workflow itself.
#
# Run with:
#   pwsh -NoProfile -File Run-ActTests.ps1

[CmdletBinding()]
param(
    [string]$ResultPath = (Join-Path $PSScriptRoot 'act-result.txt')
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Reset the result file at the start of every run so we don't accumulate
# stale output across iterations.
Set-Content -Path $ResultPath -Value "act-result.txt - generated $(Get-Date -Format o)`n" -Encoding utf8

function Write-Result {
    param([string]$Text)
    Add-Content -Path $ResultPath -Value $Text
}

function Write-Banner {
    param([string]$Title)
    $line = '=' * 78
    Write-Result ''
    Write-Result $line
    Write-Result "  $Title"
    Write-Result $line
}

function Invoke-ActCase {
    <#
    .SYNOPSIS
        Set up a clean git working tree for one test case and run `act push --rm`.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CaseName,
        # Hashtable of repo-relative path -> file content. Anything not in this
        # map is copied as-is from the project root.
        [Parameter(Mandatory)][hashtable]$FixtureFiles
    )

    Write-Banner "TEST CASE: $CaseName"
    $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("act-case-" + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $tmpRoot | Out-Null
    Write-Host "[$CaseName] temp repo: $tmpRoot"

    try {
        # Copy the entire project (excluding artifacts and the temp git repo
        # itself) into the temp directory.
        $exclude = @('act-result.txt', 'pester-results.xml', 'compliance-report.json', '.git')
        Get-ChildItem -Path $PSScriptRoot -Force | Where-Object { $_.Name -notin $exclude } |
            ForEach-Object {
                Copy-Item -Path $_.FullName -Destination $tmpRoot -Recurse -Force
            }

        # Apply per-case overrides on top of the copy.
        foreach ($relPath in $FixtureFiles.Keys) {
            $absPath = Join-Path $tmpRoot $relPath
            $parent = Split-Path -Parent $absPath
            if ($parent -and -not (Test-Path $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            Set-Content -Path $absPath -Value $FixtureFiles[$relPath] -Encoding utf8
        }

        # act needs a real git repo (it inspects HEAD).
        Push-Location $tmpRoot
        try {
            git init -q -b main 2>&1 | Out-Null
            git config user.email 'harness@test.local' | Out-Null
            git config user.name  'Harness' | Out-Null
            git add -A | Out-Null
            git commit -q -m "test: $CaseName" 2>&1 | Out-Null

            # Run act with --rm to clean up the container after each run.
            # 2>&1 merges stderr so we capture progress + errors together.
            $actLog = & act push --rm 2>&1
            $actExit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        Write-Result "act exit code: $actExit"
        Write-Result ''
        Write-Result '----- BEGIN act output -----'
        Write-Result ($actLog -join [Environment]::NewLine)
        Write-Result '----- END act output -----'

        return [pscustomobject]@{
            Name     = $CaseName
            ExitCode = $actExit
            Output   = ($actLog -join "`n")
            TmpRoot  = $tmpRoot
        }
    } finally {
        # Best-effort cleanup; ignore failures so we don't mask test outcomes.
        if (Test-Path $tmpRoot) {
            Remove-Item -Recurse -Force -LiteralPath $tmpRoot -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# 1. Structure tests (parse the workflow YAML, verify referenced paths,
#    confirm actionlint is happy). Run via Pester so failures are reported
#    consistently with the unit suite.
# ---------------------------------------------------------------------------
Write-Banner 'WORKFLOW STRUCTURE TESTS'
$structureResultsXml = Join-Path $PSScriptRoot 'structure-results.xml'
$structureCfg = New-PesterConfiguration
$structureCfg.Run.Path = (Join-Path $PSScriptRoot 'tests/Workflow.Tests.ps1')
$structureCfg.Run.PassThru = $true
$structureCfg.Output.Verbosity = 'Detailed'
$structureCfg.TestResult.Enabled = $true
$structureCfg.TestResult.OutputPath = $structureResultsXml
$structureRun = Invoke-Pester -Configuration $structureCfg
Write-Result "Structure tests: passed=$($structureRun.PassedCount) failed=$($structureRun.FailedCount)"
if ($structureRun.FailedCount -gt 0) {
    throw "Structure tests failed: $($structureRun.FailedCount) failure(s). See output above."
}

# ---------------------------------------------------------------------------
# 2. Test-case fixtures. Each case is a self-contained {manifest, policy,
#    expected-output} triple. The expected-output assertions live below in
#    the assertion phase.
# ---------------------------------------------------------------------------
$policyMixed = @'
{
  "allow": ["MIT", "Apache-2.0", "BSD-3-Clause"],
  "deny":  ["GPL-3.0", "AGPL-3.0"]
}
'@

$cases = @(
    @{
        Name = 'Case1-MixedPackageJson'
        # Per-case overrides go under test-input/ so they don't clobber the
        # canonical fixtures the in-workflow Pester unit tests rely on.
        Files = @{
            'test-input/manifest.json' = @'
{
  "name": "case1",
  "version": "1.0.0",
  "dependencies": {
    "express": "4.18.2",
    "some-gpl-pkg": "1.0.0"
  },
  "devDependencies": {
    "jest": "29.7.0"
  }
}
'@
            'test-input/policy.json' = $policyMixed
            'test-config.env' = "MANIFEST_FILE=test-input/manifest.json`nPOLICY_FILE=test-input/policy.json`n"
        }
        ExpectedExitCode = 0
        # exact substrings we expect to see (or NOT see) in the act output.
        ExpectedContains = @(
            'express',
            'some-gpl-pkg',
            'jest',
            'MIT',
            'GPL-3.0',
            'Approved',
            'Denied',
            'Total:    3',
            'Approved: 2',
            'Denied:   1',
            'Unknown:  0',
            'NON-COMPLIANT',
            'VERDICT: NON-COMPLIANT',
            'Job succeeded'
        )
        ExpectedNotContains = @('VERDICT: COMPLIANT', 'VERDICT: ERROR')
    },
    @{
        Name = 'Case2-CleanPackageJson'
        Files = @{
            'test-input/manifest.json' = @'
{
  "name": "case2",
  "version": "1.0.0",
  "dependencies": {
    "express": "4.18.2",
    "lodash": "^4.17.21"
  }
}
'@
            'test-input/policy.json' = $policyMixed
            'test-config.env' = "MANIFEST_FILE=test-input/manifest.json`nPOLICY_FILE=test-input/policy.json`n"
        }
        ExpectedExitCode = 0
        ExpectedContains = @(
            'express',
            'lodash',
            'MIT',
            'Total:    2',
            'Approved: 2',
            'Denied:   0',
            'Unknown:  0',
            'COMPLIANT',
            'VERDICT: COMPLIANT',
            'Job succeeded'
        )
        ExpectedNotContains = @('NON-COMPLIANT', 'VERDICT: ERROR', 'Denied   ')
    },
    @{
        Name = 'Case3-RequirementsTxt'
        Files = @{
            'test-input/requirements.txt' = @"
requests==2.31.0
flask==3.0.0
some-gpl-pkg==1.0.0
"@
            'test-input/policy.json' = $policyMixed
            'test-config.env' = "MANIFEST_FILE=test-input/requirements.txt`nPOLICY_FILE=test-input/policy.json`n"
        }
        ExpectedExitCode = 0
        ExpectedContains = @(
            'requests',
            'flask',
            'some-gpl-pkg',
            'Apache-2.0',
            'BSD-3-Clause',
            'GPL-3.0',
            'Total:    3',
            'Approved: 2',
            'Denied:   1',
            'Unknown:  0',
            'NON-COMPLIANT',
            'VERDICT: NON-COMPLIANT',
            'Job succeeded'
        )
        ExpectedNotContains = @('VERDICT: COMPLIANT', 'VERDICT: ERROR')
    }
)

$failures = [System.Collections.Generic.List[string]]::new()

foreach ($case in $cases) {
    $r = Invoke-ActCase -CaseName $case.Name -FixtureFiles $case.Files

    Write-Result ''
    Write-Result "----- ASSERTIONS for $($case.Name) -----"

    # Assert 1: act exited with the expected code (0).
    if ($r.ExitCode -ne $case.ExpectedExitCode) {
        $msg = "[$($case.Name)] FAIL: expected exit $($case.ExpectedExitCode), got $($r.ExitCode)"
        Write-Result $msg
        $failures.Add($msg)
    } else {
        Write-Result "[$($case.Name)] PASS: act exit code == $($r.ExitCode)"
    }

    # Assert 2: every job in the workflow shows "Job succeeded". My workflow
    # has 2 jobs (unit-tests, compliance-check), so we expect >= 2 successes.
    $successCount = ([regex]::Matches($r.Output, 'Job succeeded')).Count
    if ($successCount -lt 2) {
        $msg = "[$($case.Name)] FAIL: expected >= 2 'Job succeeded', got $successCount"
        Write-Result $msg
        $failures.Add($msg)
    } else {
        Write-Result "[$($case.Name)] PASS: $successCount 'Job succeeded' messages"
    }

    # Assert 3: every expected substring is present.
    foreach ($needle in $case.ExpectedContains) {
        if ($r.Output -notmatch [regex]::Escape($needle)) {
            $msg = "[$($case.Name)] FAIL: expected to contain '$needle' but did not"
            Write-Result $msg
            $failures.Add($msg)
        } else {
            Write-Result "[$($case.Name)] PASS: contains '$needle'"
        }
    }

    # Assert 4: every forbidden substring is absent.
    foreach ($needle in $case.ExpectedNotContains) {
        if ($r.Output -match [regex]::Escape($needle)) {
            $msg = "[$($case.Name)] FAIL: expected NOT to contain '$needle' but did"
            Write-Result $msg
            $failures.Add($msg)
        } else {
            Write-Result "[$($case.Name)] PASS: does not contain '$needle'"
        }
    }
}

Write-Banner 'SUMMARY'
if ($failures.Count -gt 0) {
    Write-Result "FAILED with $($failures.Count) assertion failure(s):"
    foreach ($f in $failures) { Write-Result "  - $f" }
    Write-Host "FAILED with $($failures.Count) assertion failure(s)" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
} else {
    Write-Result "All $($cases.Count) test cases passed."
    Write-Host "All $($cases.Count) test cases passed." -ForegroundColor Green
    exit 0
}
