<#
.SYNOPSIS
    Act integration test harness for the PR Label Assigner workflow.
.DESCRIPTION
    1. Runs actionlint on the workflow file (host machine).
    2. Checks workflow YAML structure (triggers, script references).
    3. Sets up a temporary git repo with all project files.
    4. Executes `act push --rm` and captures the full output.
    5. Asserts exit code 0, "Job succeeded", and exact TC*_LABELS: values.
    6. Saves all output to act-result.txt in the current working directory.
    Limit: at most 3 `act push` invocations across the entire session.
#>

$ErrorActionPreference = "Stop"
$projectDir   = $PSScriptRoot
$actResultFile = Join-Path $projectDir "act-result.txt"

function Write-Result {
    param([string]$Line)
    Add-Content -Path $actResultFile -Value $Line
}

# Initialise (overwrite) the results file
"" | Set-Content -Path $actResultFile -Encoding UTF8

# ── Step 1: actionlint validation ────────────────────────────────────────────
Write-Host "=== actionlint validation ===" -ForegroundColor Cyan
$workflowFile   = Join-Path $projectDir ".github/workflows/pr-label-assigner.yml"
$lintOutput     = (& actionlint $workflowFile 2>&1) -join "`n"
$lintExit       = $LASTEXITCODE

Write-Result "=== ACTIONLINT VALIDATION ==="
Write-Result $lintOutput
Write-Result "Exit code: $lintExit"
Write-Result ""

if ($lintExit -ne 0) {
    Write-Host "FAIL: actionlint" -ForegroundColor Red
    throw "actionlint failed:`n$lintOutput"
}
Write-Host "PASS: actionlint" -ForegroundColor Green
Write-Result "PASS: actionlint"

# ── Step 2: workflow structure assertions (host-side, no act needed) ─────────
Write-Host "=== Workflow structure checks ===" -ForegroundColor Cyan
Write-Result ""
Write-Result "=== WORKFLOW STRUCTURE CHECKS ==="

$wfContent = Get-Content $workflowFile -Raw

$structureChecks = @(
    @{ Pattern = 'push:';                      Name = "push trigger" },
    @{ Pattern = 'pull_request:';              Name = "pull_request trigger" },
    @{ Pattern = 'workflow_dispatch:';         Name = "workflow_dispatch trigger" },
    @{ Pattern = 'actions/checkout@v4';        Name = "checkout action" },
    @{ Pattern = 'Invoke-PrLabelAssigner\.ps1';Name = "script reference" },
    @{ Pattern = 'shell:\s*pwsh';              Name = "pwsh shell directive" }
)

$structFail = $false
foreach ($chk in $structureChecks) {
    if ($wfContent -match $chk.Pattern) {
        Write-Host "  PASS: $($chk.Name)" -ForegroundColor Green
        Write-Result "PASS: $($chk.Name)"
    } else {
        Write-Host "  FAIL: $($chk.Name) missing" -ForegroundColor Red
        Write-Result "FAIL: $($chk.Name) missing"
        $structFail = $true
    }
}

# Verify referenced script actually exists
$scriptPath = Join-Path $projectDir "Invoke-PrLabelAssigner.ps1"
if (Test-Path $scriptPath) {
    Write-Host "  PASS: Invoke-PrLabelAssigner.ps1 exists" -ForegroundColor Green
    Write-Result "PASS: Invoke-PrLabelAssigner.ps1 exists"
} else {
    Write-Host "  FAIL: Invoke-PrLabelAssigner.ps1 not found" -ForegroundColor Red
    Write-Result "FAIL: Invoke-PrLabelAssigner.ps1 not found"
    $structFail = $true
}

if ($structFail) {
    throw "Workflow structure checks failed — see act-result.txt"
}

# ── Step 3: act integration run ──────────────────────────────────────────────
Write-Host ""
Write-Host "=== Running act push --rm ===" -ForegroundColor Cyan

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempDir | Out-Null

try {
    # Copy all project files to the temp repo (exclude act-result.txt to keep it clean)
    Get-ChildItem -Path $projectDir -Force | Where-Object { $_.Name -ne "act-result.txt" } | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $tempDir -Recurse -Force
    }

    Push-Location $tempDir

    # Initialise a git repo so act can detect the push event context
    git init --quiet
    git config user.email "ci@example.com"
    git config user.name  "CI Test"
    git add -A
    git commit -m "ci: initial commit for act test" --quiet

    # Run act — capture both stdout and stderr
    Write-Host "  Starting act push --rm (may take 30-90 s)..." -ForegroundColor Yellow
    $actRaw    = act push --rm --pull=false 2>&1
    $actExit   = $LASTEXITCODE
    $actOutput = $actRaw -join "`n"

    Write-Result ""
    Write-Result "=== ACT RUN OUTPUT ==="
    Write-Result $actOutput
    Write-Result ""
    Write-Result "=== ACT EXIT CODE: $actExit ==="
    Write-Result ""

    # Assert exit code
    if ($actExit -ne 0) {
        Write-Host "FAIL: act exited with code $actExit" -ForegroundColor Red
        Write-Result "FAIL: act non-zero exit"
        throw "act push --rm exited with code $actExit"
    }
    Write-Host "PASS: act exit code 0" -ForegroundColor Green
    Write-Result "PASS: act exit code 0"

    # Assert exact expected label outputs from the workflow steps
    $assertions = @(
        @{ Pattern = 'TC1_LABELS: documentation';                  Desc = "TC1 – documentation label" },
        @{ Pattern = 'TC2_LABELS: api,tests';                      Desc = "TC2 – api and tests labels" },
        @{ Pattern = 'TC3_LABELS: <empty>';                        Desc = "TC3 – no labels (<empty>)" },
        @{ Pattern = 'TC4_LABELS: documentation,api,frontend,tests'; Desc = "TC4 – priority-ordered labels" },
        @{ Pattern = 'Job succeeded';                              Desc = "Job succeeded" }
    )

    $allPassed = $true
    foreach ($a in $assertions) {
        if ($actOutput -match [regex]::Escape($a.Pattern)) {
            Write-Host "  PASS: $($a.Desc)" -ForegroundColor Green
            Write-Result "PASS: $($a.Desc)"
        } else {
            Write-Host "  FAIL: $($a.Desc) — expected '$($a.Pattern)' in output" -ForegroundColor Red
            Write-Result "FAIL: $($a.Desc) — expected '$($a.Pattern)'"
            $allPassed = $false
        }
    }

    if (-not $allPassed) {
        throw "One or more act output assertions failed — see act-result.txt"
    }

    Write-Host ""
    Write-Host "All act integration tests PASSED." -ForegroundColor Green
    Write-Result ""
    Write-Result "All act integration tests PASSED."

} finally {
    if ((Get-Location).Path -eq $tempDir) { Pop-Location }
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
}
