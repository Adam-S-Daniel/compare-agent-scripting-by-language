# Test harness: runs workflow through act and validates output.
# Produces act-result.txt as required artifact.

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$actResultFile = Join-Path $projectRoot 'act-result.txt'

# Clear previous results
if (Test-Path $actResultFile) { Remove-Item $actResultFile }
'' | Set-Content $actResultFile

function Write-Result {
    param([string]$Text)
    $Text | Add-Content $actResultFile
    Write-Host $Text
}

# ─── Workflow structure tests ───

Write-Result '====== WORKFLOW STRUCTURE TESTS ======'

$workflowPath = Join-Path $projectRoot '.github/workflows/environment-matrix-generator.yml'
$scriptPath = Join-Path $projectRoot 'New-EnvironmentMatrix.ps1'
$testPath = Join-Path $projectRoot 'New-EnvironmentMatrix.Tests.ps1'

# Test: workflow YAML exists and parses
$yaml = Get-Content -Raw $workflowPath
if (-not $yaml) { Write-Result 'FAIL: workflow YAML is empty'; exit 1 }
Write-Result 'PASS: Workflow YAML file exists and is readable'

# Test: workflow references script files that exist
$refsScript = $yaml -match 'New-EnvironmentMatrix\.ps1'
$refsTest = $yaml -match 'New-EnvironmentMatrix\.Tests\.ps1'
if (-not $refsScript) { Write-Result 'FAIL: workflow does not reference New-EnvironmentMatrix.ps1'; exit 1 }
if (-not $refsTest) { Write-Result 'FAIL: workflow does not reference New-EnvironmentMatrix.Tests.ps1'; exit 1 }
if (-not (Test-Path $scriptPath)) { Write-Result 'FAIL: New-EnvironmentMatrix.ps1 does not exist'; exit 1 }
if (-not (Test-Path $testPath)) { Write-Result 'FAIL: New-EnvironmentMatrix.Tests.ps1 does not exist'; exit 1 }
Write-Result 'PASS: Workflow references script files and they exist'

# Test: workflow has expected triggers
if ($yaml -notmatch 'push:') { Write-Result 'FAIL: missing push trigger'; exit 1 }
if ($yaml -notmatch 'pull_request:') { Write-Result 'FAIL: missing pull_request trigger'; exit 1 }
if ($yaml -notmatch 'workflow_dispatch') { Write-Result 'FAIL: missing workflow_dispatch trigger'; exit 1 }
Write-Result 'PASS: Workflow has push, pull_request, and workflow_dispatch triggers'

# Test: workflow has expected job structure
if ($yaml -notmatch 'jobs:') { Write-Result 'FAIL: no jobs section'; exit 1 }
if ($yaml -notmatch 'runs-on:') { Write-Result 'FAIL: no runs-on'; exit 1 }
if ($yaml -notmatch 'shell: pwsh') { Write-Result 'FAIL: no shell: pwsh steps'; exit 1 }
if ($yaml -notmatch 'actions/checkout@v4') { Write-Result 'FAIL: missing checkout action'; exit 1 }
Write-Result 'PASS: Workflow has expected job structure (jobs, runs-on, shell: pwsh, checkout)'

# Test: actionlint passes
$lintOutput = actionlint $workflowPath 2>&1
$lintExit = $LASTEXITCODE
if ($lintExit -ne 0) {
    Write-Result "FAIL: actionlint failed (exit $lintExit): $lintOutput"
    exit 1
}
Write-Result 'PASS: actionlint passes with exit code 0'

Write-Result '====== END WORKFLOW STRUCTURE TESTS ======'
Write-Result ''

# ─── Act integration test ───

Write-Result '====== ACT INTEGRATION TEST ======'

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)"
New-Item -ItemType Directory -Path $tmpDir | Out-Null

try {
    # Set up a temp git repo with project files
    Push-Location $tmpDir
    git init --initial-branch=main 2>&1 | Out-Null
    git config user.email 'test@test.com' 2>&1 | Out-Null
    git config user.name 'Test' 2>&1 | Out-Null

    # Copy project files
    Copy-Item $scriptPath $tmpDir/
    Copy-Item $testPath $tmpDir/
    $wfDir = Join-Path $tmpDir '.github/workflows'
    New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
    Copy-Item $workflowPath $wfDir/

    # Copy .actrc if it exists
    $actrcSource = Join-Path $projectRoot '.actrc'
    if (Test-Path $actrcSource) { Copy-Item $actrcSource $tmpDir/ }

    git add -A 2>&1 | Out-Null
    git commit -m 'initial' 2>&1 | Out-Null

    Write-Result "Running act push in $tmpDir ..."
    $actOutput = & act push --rm --pull=false 2>&1 | Out-String
    $actExit = $LASTEXITCODE

    Write-Result '--- ACT OUTPUT START ---'
    Write-Result $actOutput
    Write-Result '--- ACT OUTPUT END ---'

    # Assertion: act exit code 0
    if ($actExit -ne 0) {
        Write-Result "FAIL: act exited with code $actExit"
        exit 1
    }
    Write-Result 'PASS: act exited with code 0'

    # Assertion: Job succeeded
    if ($actOutput -notmatch 'Job succeeded') {
        Write-Result 'FAIL: "Job succeeded" not found in act output'
        exit 1
    }
    Write-Result 'PASS: "Job succeeded" found in act output'

    # Assertion: All 14 Pester tests passed
    if ($actOutput -match 'Tests Passed:\s*14') {
        Write-Result 'PASS: All 14 Pester tests passed'
    } else {
        Write-Result 'FAIL: Expected 14 Pester tests to pass'
        exit 1
    }

    # Assertion: No test failures
    if ($actOutput -match 'Failed:\s*0') {
        Write-Result 'PASS: Zero test failures'
    } else {
        Write-Result 'FAIL: Some tests failed'
        exit 1
    }

    # ─── Exact value assertions on matrix output ───

    # Basic matrix: should contain all 3 OSes and 3 language versions
    if ($actOutput -match '=== BASIC MATRIX ===') {
        Write-Result 'PASS: Basic matrix section found'
    } else {
        Write-Result 'FAIL: Basic matrix section not found'
        exit 1
    }
    foreach ($os in @('ubuntu-latest', 'windows-latest', 'macos-latest')) {
        if ($actOutput -match [regex]::Escape("`"$os`"")) {
            Write-Result "PASS: Basic matrix contains OS '$os'"
        } else {
            Write-Result "FAIL: Basic matrix missing OS '$os'"
            exit 1
        }
    }
    foreach ($lang in @('3.9', '3.10', '3.11')) {
        if ($actOutput -match [regex]::Escape("`"$lang`"")) {
            Write-Result "PASS: Basic matrix contains language '$lang'"
        } else {
            Write-Result "FAIL: Basic matrix missing language '$lang'"
            exit 1
        }
    }
    foreach ($feat in @('standard', 'experimental')) {
        if ($actOutput -match [regex]::Escape("`"$feat`"")) {
            Write-Result "PASS: Basic matrix contains feature '$feat'"
        } else {
            Write-Result "FAIL: Basic matrix missing feature '$feat'"
            exit 1
        }
    }

    # Advanced matrix: check fail-fast false, max-parallel 4, include/exclude
    if ($actOutput -match '=== ADVANCED MATRIX ===') {
        Write-Result 'PASS: Advanced matrix section found'
    } else {
        Write-Result 'FAIL: Advanced matrix section not found'
        exit 1
    }
    if ($actOutput -match '"fail-fast":\s*false') {
        Write-Result 'PASS: Advanced matrix has fail-fast: false'
    } else {
        Write-Result 'FAIL: Advanced matrix should have fail-fast: false'
        exit 1
    }
    if ($actOutput -match '"max-parallel":\s*4') {
        Write-Result 'PASS: Advanced matrix has max-parallel: 4'
    } else {
        Write-Result 'FAIL: Advanced matrix should have max-parallel: 4'
        exit 1
    }
    if ($actOutput -match [regex]::Escape('"language": "3.11"')) {
        Write-Result 'PASS: Advanced matrix include has language 3.11'
    } else {
        Write-Result 'FAIL: Advanced matrix include should have language 3.11'
        exit 1
    }

    # JSON file matrix: should have exactly ubuntu-latest and node 18, 20, 22
    if ($actOutput -match '=== JSON FILE MATRIX ===') {
        Write-Result 'PASS: JSON file matrix section found'
    } else {
        Write-Result 'FAIL: JSON file matrix section not found'
        exit 1
    }
    foreach ($ver in @('18', '20', '22')) {
        if ($actOutput -match [regex]::Escape("`"$ver`"")) {
            Write-Result "PASS: JSON file matrix contains language version '$ver'"
        } else {
            Write-Result "FAIL: JSON file matrix missing language version '$ver'"
            exit 1
        }
    }

    # Size validation: should show the rejection message
    if ($actOutput -match '=== SIZE VALIDATION ===') {
        Write-Result 'PASS: Size validation section found'
    } else {
        Write-Result 'FAIL: Size validation section not found'
        exit 1
    }
    if ($actOutput -match 'Correctly rejected oversized matrix.*exceeds') {
        Write-Result 'PASS: Size validation correctly rejected oversized matrix'
    } else {
        Write-Result 'FAIL: Size validation message not found'
        exit 1
    }

} finally {
    Pop-Location
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
}

Write-Result '====== END ACT INTEGRATION TEST ======'
Write-Result ''
Write-Result '====== ALL TESTS PASSED ======'

Write-Host ''
Write-Host "Results saved to: $actResultFile"
