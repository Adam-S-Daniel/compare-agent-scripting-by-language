# Run-ActTests.ps1
# Outer test harness: copies project files into a temp git repo, runs act push --rm,
# saves output to act-result.txt, and asserts on exact expected values in the output.

$ErrorActionPreference = "Stop"
$ProjectRoot   = $PSScriptRoot
$ActResultFile = Join-Path $ProjectRoot "act-result.txt"

# ── Workflow structure tests (no act needed) ─────────────────────────────────

function Test-WorkflowStructure {
    Write-Host "`n=== Workflow structure tests ==="

    $wfPath = Join-Path $ProjectRoot ".github/workflows/semantic-version-bumper.yml"

    # File exists
    if (-not (Test-Path $wfPath)) { throw "Workflow file not found: $wfPath" }
    Write-Host "PASS: workflow file exists"

    # actionlint passes
    $lint = & actionlint $wfPath 2>&1
    if ($LASTEXITCODE -ne 0) { throw "actionlint failed:`n$lint" }
    Write-Host "PASS: actionlint exit 0"

    # Parse YAML (use PowerShell to read raw and check key strings)
    $wfContent = Get-Content $wfPath -Raw
    foreach ($trigger in @("push", "workflow_dispatch")) {
        if ($wfContent -notmatch $trigger) { throw "Workflow missing trigger: $trigger" }
    }
    Write-Host "PASS: triggers present (push, workflow_dispatch)"

    # Jobs present
    foreach ($job in @("test")) {
        if ($wfContent -notmatch "(?m)^\s+${job}:") { throw "Missing job: $job" }
    }
    Write-Host "PASS: job 'test' present"

    # Script references exist
    foreach ($scriptFile in @("SemanticVersionBumper.psm1", "SemanticVersionBumper.Tests.ps1", "Invoke-SemanticVersionBump.ps1")) {
        if (-not (Test-Path (Join-Path $ProjectRoot $scriptFile))) {
            throw "Referenced script file missing: $scriptFile"
        }
    }
    Write-Host "PASS: all referenced script files exist"

    Write-Host "Workflow structure: ALL CHECKS PASSED"
}

# ── Act execution test ────────────────────────────────────────────────────────

function Invoke-ActTest {
    param(
        [string]   $TestName,
        [string[]] $ExpectedOutputs
    )

    Write-Host "`n=== act test: $TestName ==="

    # Build a clean temp git repo containing all project files
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("semver-act-" + [System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    try {
        # Copy project files
        $items = @(
            "SemanticVersionBumper.psm1",
            "SemanticVersionBumper.Tests.ps1",
            "Invoke-SemanticVersionBump.ps1",
            "fixtures",
            ".github",
            ".actrc"
        )
        foreach ($item in $items) {
            $src = Join-Path $ProjectRoot $item
            if (Test-Path $src -PathType Container) {
                Copy-Item -Path $src -Destination (Join-Path $tempDir $item) -Recurse
            } elseif (Test-Path $src) {
                Copy-Item -Path $src -Destination $tempDir
            }
        }

        # Initialise git repo so act triggers on push
        Push-Location $tempDir
        & git init -q
        & git config user.email "ci@example.com"
        & git config user.name  "CI"
        & git add -A
        & git commit -q -m "chore: initial commit"

        Write-Host "Running: act push --rm --pull=false  (this may take 30-90 s)"
        $output  = & act push --rm --pull=false 2>&1
        $exitCode = $LASTEXITCODE

    } finally {
        Pop-Location
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # ── Save to act-result.txt ────────────────────────────────────────────────
    $divider = "=" * 60
    $block   = @(
        $divider,
        "TEST: $TestName",
        "EXIT CODE: $exitCode",
        $divider,
        ($output -join "`n"),
        ""
    ) -join "`n"
    Add-Content -Path $ActResultFile -Value $block

    # ── Assertions ────────────────────────────────────────────────────────────
    if ($exitCode -ne 0) {
        throw "act exited $exitCode for '$TestName'. See act-result.txt for details."
    }
    Write-Host "PASS: act exit code 0"

    $outputStr = $output -join "`n"

    if ($outputStr -notmatch "Job succeeded") {
        throw "'Job succeeded' not found in act output for '$TestName'"
    }
    Write-Host "PASS: Job succeeded"

    foreach ($expected in $ExpectedOutputs) {
        if ($outputStr -notmatch [regex]::Escape($expected)) {
            throw "Expected value not found: '$expected'  (test: $TestName)"
        }
        Write-Host "PASS: found '$expected'"
    }

    Write-Host "act test '$TestName': ALL ASSERTIONS PASSED"
}

# ── Main ──────────────────────────────────────────────────────────────────────

# Clear previous results
if (Test-Path $ActResultFile) { Remove-Item $ActResultFile }
New-Item -ItemType File -Path $ActResultFile | Out-Null

Test-WorkflowStructure

# One act run exercises every scenario (the workflow runs all of them internally)
Invoke-ActTest -TestName "All scenarios" -ExpectedOutputs @(
    "SCENARIO fix: NEW_VERSION=1.0.1",
    "SCENARIO feat: NEW_VERSION=1.1.0",
    "SCENARIO breaking: NEW_VERSION=2.0.0",
    "SCENARIO mixed: NEW_VERSION=2.4.0",
    "SCENARIO package-json: NEW_VERSION=3.2.2",
    "All integration scenarios passed.",
    "Job succeeded"
)

Write-Host "`nAll tests completed. Results in $ActResultFile"
