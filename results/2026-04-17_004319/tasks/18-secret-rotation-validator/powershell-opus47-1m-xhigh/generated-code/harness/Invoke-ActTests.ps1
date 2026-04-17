#!/usr/bin/env pwsh
# Test harness that drives the secret-rotation-validator workflow through
# `act` for multiple fixture variations. Follows the requirement that
# EVERY test case runs through the GitHub Actions pipeline, not the script
# directly.
#
# For each test case it:
#   1. Copies the project to a temp dir.
#   2. Rewrites fixtures/secrets.json with that case's mock secrets.
#   3. Optionally rewrites the workflow's OUTPUT_FORMAT default.
#   4. Initializes a git repo (act needs one to synthesize a push event).
#   5. Runs `act push --rm`, captures stdout/stderr and exit code.
#   6. Appends the output (with a delimiter) to act-result.txt.
#   7. Asserts exit 0, every job "Job succeeded", and exact expected values.
#
# Plus two non-act structure checks (YAML parse + actionlint).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot    = Split-Path -Parent $PSScriptRoot
$ResultFile  = Join-Path $RepoRoot 'act-result.txt'
$WorkflowRel = '.github/workflows/secret-rotation-validator.yml'

# Truncate the aggregate output file — the test harness re-creates it fresh.
Set-Content -Path $ResultFile -Value "# act-result.txt (generated $(Get-Date -Format o))`n"

$FailureMessages = New-Object System.Collections.Generic.List[string]

function Append-Section {
    param([string] $Title, [string] $Body)
    $banner = '=' * 78
    Add-Content -Path $ResultFile -Value ""
    Add-Content -Path $ResultFile -Value $banner
    Add-Content -Path $ResultFile -Value "## $Title"
    Add-Content -Path $ResultFile -Value $banner
    Add-Content -Path $ResultFile -Value $Body
}

function Assert-True {
    param([string] $Case, [string] $Description, [bool] $Condition, [string] $Detail = '')
    if ($Condition) {
        Write-Host "    PASS: $Description" -ForegroundColor Green
    } else {
        $msg = "FAIL [$Case]: $Description"
        if ($Detail) { $msg += " -- $Detail" }
        Write-Host "    $msg" -ForegroundColor Red
        $FailureMessages.Add($msg) | Out-Null
    }
}

# ---------------------------------------------------------------------------
# Structure checks: don't need act.
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "=== Workflow structure tests ===" -ForegroundColor Cyan

$workflowPath = Join-Path $RepoRoot $WorkflowRel
Assert-True 'structure' 'workflow file exists' (Test-Path $workflowPath)

# Minimal YAML parse using pwsh's built-in tooling. ConvertFrom-Yaml is not in
# core PowerShell, so we shell out to `python3 -c 'import yaml; ...'` if
# available. Otherwise fall back to regex sanity checks.
$pythonAvailable = $null -ne (Get-Command python3 -ErrorAction SilentlyContinue)
if ($pythonAvailable) {
    $parseScript = @"
import sys, yaml, json
with open(r'$workflowPath') as f:
    doc = yaml.safe_load(f)
print(json.dumps(doc))
"@
    $parsedJson = $parseScript | python3 - 2>&1
    if ($LASTEXITCODE -ne 0) {
        Assert-True 'structure' 'workflow YAML parses' $false $parsedJson
        $parsedDoc = $null
    } else {
        Assert-True 'structure' 'workflow YAML parses' $true
        $parsedDoc = $parsedJson | ConvertFrom-Json
    }
} else {
    Write-Host "    python3 not found — skipping YAML parse check" -ForegroundColor Yellow
    $parsedDoc = $null
}

if ($parsedDoc) {
    # Note: "on" key is tricky — YAML 1.1 can coerce it to boolean true. PyYAML
    # preserves it as a string. Either way the parsed form surfaces as 'on' or 'True'.
    $triggers = if ($parsedDoc.PSObject.Properties.Name -contains 'on') {
        $parsedDoc.on
    } elseif ($parsedDoc.PSObject.Properties.Name -contains 'True') {
        $parsedDoc.True
    } else { $null }
    Assert-True 'structure' 'has push trigger'             ($null -ne $triggers.push)
    Assert-True 'structure' 'has pull_request trigger'     ($null -ne $triggers.pull_request)
    Assert-True 'structure' 'has workflow_dispatch trigger' ($null -ne $triggers.workflow_dispatch)
    Assert-True 'structure' 'has schedule trigger'          ($null -ne $triggers.schedule)

    $jobs = $parsedDoc.jobs
    Assert-True 'structure' 'declares unit-tests job'     ($null -ne $jobs.'unit-tests')
    Assert-True 'structure' 'declares rotation-report job' ($null -ne $jobs.'rotation-report')
    Assert-True 'structure' 'rotation-report needs unit-tests' `
        ($jobs.'rotation-report'.needs -eq 'unit-tests')

    # Walk the workflow steps; check each referenced file exists locally.
    $allSteps = @()
    foreach ($job in $jobs.PSObject.Properties.Value) {
        if ($job.steps) { $allSteps += $job.steps }
    }
    $usesValues = foreach ($step in $allSteps) {
        if ($step.PSObject.Properties.Name -contains 'uses') { $step.uses }
    }
    Assert-True 'structure' 'uses actions/checkout@v4' (
        $usesValues -contains 'actions/checkout@v4'
    )

    # Script files referenced from inline shell commands.
    $scriptRefs = @('Invoke-Report.ps1', 'tests/SecretRotationValidator.Tests.ps1',
                    'src/SecretRotationValidator.psm1', 'fixtures/secrets.json')
    foreach ($p in $scriptRefs) {
        Assert-True 'structure' "referenced file exists: $p" (Test-Path (Join-Path $RepoRoot $p))
    }
}

# actionlint is an instant external check; assert it passes.
$actionlintOutput = & actionlint $workflowPath 2>&1
$actionlintExit = $LASTEXITCODE
Assert-True 'structure' 'actionlint exits 0' ($actionlintExit -eq 0) `
    ($actionlintOutput -join "`n")
Append-Section 'actionlint' (($actionlintOutput -join "`n") + "`n(exit $actionlintExit)")

# ---------------------------------------------------------------------------
# Test cases: each runs act once against its own fixture.
# ---------------------------------------------------------------------------

$TestCases = @(
    @{
        Name         = 'all-ok-markdown'
        Description  = 'all secrets well within policy, markdown output'
        Format       = 'markdown'
        Fixture      = @(
            @{ name='ok-one'; lastRotated='2026-04-10'; rotationPolicyDays=90; requiredBy=@('api')    },
            @{ name='ok-two'; lastRotated='2026-04-05'; rotationPolicyDays=60; requiredBy=@('worker') }
        )
        Assertions   = {
            param($text)
            @(
                @{ Want='contains';    Value='# Secret Rotation Report' }
                @{ Want='contains';    Value='## OK (2)' }
                @{ Want='contains';    Value='ok-one' }
                @{ Want='contains';    Value='ok-two' }
                @{ Want='not-contains'; Value='## Expired' }
                @{ Want='not-contains'; Value='## Warning' }
                @{ Want='contains';    Value='_Total secrets: 2_' }
            )
        }
    },
    @{
        Name         = 'mixed-markdown'
        Description  = '1 expired, 1 warning, 1 ok — markdown tables'
        Format       = 'markdown'
        Fixture      = @(
            @{ name='db-primary-password';   lastRotated='2026-01-01'; rotationPolicyDays=30; requiredBy=@('api','worker') },
            @{ name='session-signing-key';   lastRotated='2026-04-01'; rotationPolicyDays=20; requiredBy=@('web','api') },
            @{ name='stripe-webhook-secret'; lastRotated='2026-04-01'; rotationPolicyDays=90; requiredBy=@('billing') }
        )
        Assertions   = {
            param($text)
            @(
                @{ Want='contains'; Value='## Expired (1)' }
                @{ Want='contains'; Value='## Warning (1)' }
                @{ Want='contains'; Value='## OK (1)' }
                @{ Want='contains'; Value='db-primary-password' }
                @{ Want='contains'; Value='session-signing-key' }
                @{ Want='contains'; Value='stripe-webhook-secret' }
                @{ Want='contains'; Value='| -76 |' }   # days-until-rotation for the expired secret
                @{ Want='contains'; Value='| 4 |' }     # days-until-rotation for the warning secret
                @{ Want='contains'; Value='| 74 |' }    # days-until-rotation for the ok secret
                @{ Want='contains'; Value='api, worker' }  # required-by joined
            )
        }
    },
    @{
        Name         = 'mixed-json'
        Description  = '1 expired + 1 ok — JSON output'
        Format       = 'json'
        Fixture      = @(
            @{ name='legacy-api-key'; lastRotated='2025-11-01'; rotationPolicyDays=30; requiredBy=@('legacy-svc') },
            @{ name='fresh-key';      lastRotated='2026-04-10'; rotationPolicyDays=180; requiredBy=@('api') }
        )
        Assertions   = {
            param($text)
            @(
                # The JSON report is delimited in workflow logs with ===BEGIN REPORT===/===END REPORT===.
                @{ Want='contains'; Value='"expired"' }
                @{ Want='contains'; Value='"warning"' }
                @{ Want='contains'; Value='"ok"' }
                @{ Want='contains'; Value='"totalSecrets": 2' }
                @{ Want='contains'; Value='"warningDays": 7' }
                @{ Want='contains'; Value='"name": "legacy-api-key"' }
                @{ Want='contains'; Value='"name": "fresh-key"' }
                @{ Want='contains'; Value='"status": "expired"' }
                @{ Want='contains'; Value='"status": "ok"' }
            )
        }
    }
)

foreach ($case in $TestCases) {
    Write-Host ""
    Write-Host "=== Test case: $($case.Name) === ($($case.Description))" -ForegroundColor Cyan

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("srv-act-" + $case.Name + "-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    try {
        # Copy project files (excluding .git, act-result.txt, etc.).
        $excludes = @('.git','act-result.txt','node_modules','.actrc-temp')
        Get-ChildItem -Path $RepoRoot -Force | Where-Object { $excludes -notcontains $_.Name } |
            ForEach-Object { Copy-Item -Path $_.FullName -Destination $tempDir -Recurse -Force }

        # Write case-specific fixture.
        $fixturePath = Join-Path $tempDir 'fixtures/secrets.json'
        $case.Fixture | ConvertTo-Json -Depth 6 | Set-Content -Path $fixturePath -Encoding UTF8

        # Override OUTPUT_FORMAT default if needed (default in workflow is markdown).
        # Line-based regex is unambiguous regardless of the original expression syntax.
        if ($case.Format -ne 'markdown') {
            $wf = Join-Path $tempDir $WorkflowRel
            $content = Get-Content -Path $wf -Raw
            $replacement = "`${1}OUTPUT_FORMAT: '" + $case.Format + "'"
            $content = [regex]::Replace($content, '(?m)^(\s*)OUTPUT_FORMAT:.*$', $replacement)
            Set-Content -Path $wf -Value $content -NoNewline
        }

        # act needs a git repo to synthesize a push event.
        Push-Location $tempDir
        try {
            git init --quiet 2>&1 | Out-Null
            git -c user.email=harness@example.com -c user.name=harness add -A 2>&1 | Out-Null
            git -c user.email=harness@example.com -c user.name=harness commit --quiet -m "test case: $($case.Name)" 2>&1 | Out-Null

            # --pull=false: the custom act-ubuntu-pwsh image is local-only;
            # act's default forcePull=true would hit docker-hub auth denial.
            $log = & act push --rm --pull=false 2>&1
            $actExit = $LASTEXITCODE
            $logText = ($log | Out-String)
        } finally {
            Pop-Location
        }

        Append-Section "test-case: $($case.Name) (exit=$actExit)" $logText

        Assert-True $case.Name 'act exited 0' ($actExit -eq 0) "exit=$actExit"

        # Every job in the workflow must report "Job succeeded".
        $jobSucceededCount = ([regex]::Matches($logText, 'Job succeeded')).Count
        Assert-True $case.Name 'both jobs reported "Job succeeded"' ($jobSucceededCount -ge 2) `
            "found $jobSucceededCount 'Job succeeded' markers"

        # Content assertions against expected values.
        foreach ($a in & $case.Assertions $logText) {
            if ($a.Want -eq 'contains') {
                Assert-True $case.Name "output contains '$($a.Value)'" `
                    ($logText.Contains($a.Value)) ''
            } elseif ($a.Want -eq 'not-contains') {
                Assert-True $case.Name "output does NOT contain '$($a.Value)'" `
                    (-not $logText.Contains($a.Value)) ''
            }
        }
    }
    finally {
        # Clean up the temp dir to keep /tmp tidy.
        Remove-Item -Recurse -Force -Path $tempDir -ErrorAction SilentlyContinue
    }
}

Write-Host ""
if ($FailureMessages.Count -eq 0) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
    Append-Section 'summary' "ALL TESTS PASSED"
    exit 0
} else {
    Write-Host "FAILURES:" -ForegroundColor Red
    $FailureMessages | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Append-Section 'summary' ("FAILURES:`n" + ($FailureMessages -join "`n"))
    exit 1
}
