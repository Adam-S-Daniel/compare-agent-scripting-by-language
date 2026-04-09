# run-tests.ps1
# Test harness that runs all tests through GitHub Actions via act.
# Each test case sets up an isolated temp git repo, runs the workflow with act,
# captures output, and asserts on exact expected values.
#
# Produces act-result.txt as a required artifact.

$ErrorActionPreference = 'Continue'
$ProjectDir = $PSScriptRoot
$ResultFile = Join-Path $ProjectDir 'act-result.txt'

# Clear previous results
'' | Set-Content $ResultFile

$totalTests = 0
$passedTests = 0
$failedTests = 0

function Write-Result {
    param([string]$Message)
    $Message | Add-Content $ResultFile
    Write-Host $Message
}

function Write-TestHeader {
    param([string]$TestName)
    $separator = '=' * 70
    Write-Result $separator
    Write-Result "TEST: $TestName"
    Write-Result $separator
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    $script:totalTests++
    if ($Condition) {
        $script:passedTests++
        Write-Result "  [PASS] $Message"
        return $true
    } else {
        $script:failedTests++
        Write-Result "  [FAIL] $Message"
        return $false
    }
}

# Helper: set up a temp git repo with project files and optional fixture overrides
function New-TestRepo {
    param(
        [string]$TestName,
        [hashtable]$FixtureOverrides = @{}
    )

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "license-check-$TestName-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    # Copy project files
    Copy-Item (Join-Path $ProjectDir 'DependencyLicenseChecker.ps1') $tempDir
    Copy-Item (Join-Path $ProjectDir 'DependencyLicenseChecker.Tests.ps1') $tempDir
    Copy-Item (Join-Path $ProjectDir 'license-config.json') $tempDir
    Copy-Item (Join-Path $ProjectDir 'license-db.json') $tempDir
    Copy-Item (Join-Path $ProjectDir 'test-fixtures') $tempDir -Recurse

    # Copy workflow
    $workflowDir = Join-Path $tempDir '.github/workflows'
    New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
    Copy-Item (Join-Path $ProjectDir '.github/workflows/dependency-license-checker.yml') $workflowDir

    # Apply fixture overrides (copy files on top)
    foreach ($key in $FixtureOverrides.Keys) {
        $destPath = Join-Path $tempDir $key
        $destDir = Split-Path $destPath -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        $FixtureOverrides[$key] | Set-Content -Path $destPath
    }

    # Initialize git repo
    Push-Location $tempDir
    & git init -q 2>&1 | Out-Null
    & git checkout -b main 2>&1 | Out-Null
    & git add -A 2>&1 | Out-Null
    & git commit -q -m 'test commit' 2>&1 | Out-Null
    Pop-Location

    return $tempDir
}

# Helper: run act in a temp repo and capture output
function Invoke-ActTest {
    param(
        [string]$RepoPath
    )

    Push-Location $RepoPath
    $output = & act push --rm -P ubuntu-latest=catthehacker/ubuntu:act-latest 2>&1
    $exitCode = $LASTEXITCODE
    Pop-Location

    return @{
        Output   = ($output -join "`n")
        ExitCode = $exitCode
    }
}

# ============================================================
# WORKFLOW STRUCTURE TESTS
# ============================================================
Write-TestHeader 'Workflow Structure Validation'

# Test: YAML file exists
$workflowPath = Join-Path $ProjectDir '.github/workflows/dependency-license-checker.yml'
Assert-True (Test-Path $workflowPath) 'Workflow YAML file exists at .github/workflows/dependency-license-checker.yml'

# Test: Parse YAML and check structure
$yamlContent = Get-Content $workflowPath -Raw
Assert-True ($yamlContent -match 'name:\s*Dependency License Checker') 'Workflow has correct name: Dependency License Checker'
Assert-True ($yamlContent -match 'on:') 'Workflow has trigger section (on:)'
Assert-True ($yamlContent -match 'push:') 'Workflow triggers on push'
Assert-True ($yamlContent -match 'pull_request:') 'Workflow triggers on pull_request'
Assert-True ($yamlContent -match 'workflow_dispatch:') 'Workflow triggers on workflow_dispatch'
Assert-True ($yamlContent -match 'jobs:') 'Workflow has jobs section'
Assert-True ($yamlContent -match 'check-licenses:') 'Workflow has check-licenses job'
Assert-True ($yamlContent -match 'actions/checkout@v4') 'Workflow uses actions/checkout@v4'
Assert-True ($yamlContent -match 'permissions:') 'Workflow has permissions section'

# Test: Verify script file references exist
Assert-True ($yamlContent -match 'DependencyLicenseChecker\.ps1') 'Workflow references DependencyLicenseChecker.ps1'
Assert-True (Test-Path (Join-Path $ProjectDir 'DependencyLicenseChecker.ps1')) 'DependencyLicenseChecker.ps1 exists'
Assert-True ($yamlContent -match 'DependencyLicenseChecker\.Tests\.ps1') 'Workflow references DependencyLicenseChecker.Tests.ps1'
Assert-True (Test-Path (Join-Path $ProjectDir 'DependencyLicenseChecker.Tests.ps1')) 'DependencyLicenseChecker.Tests.ps1 exists'
Assert-True ($yamlContent -match 'license-config\.json') 'Workflow references license-config.json'
Assert-True (Test-Path (Join-Path $ProjectDir 'license-config.json')) 'license-config.json exists'
Assert-True ($yamlContent -match 'license-db\.json') 'Workflow references license-db.json'
Assert-True (Test-Path (Join-Path $ProjectDir 'license-db.json')) 'license-db.json exists'

# Test: actionlint passes
Write-Result ''
Write-Result 'Running actionlint...'
$actionlintOutput = & actionlint $workflowPath 2>&1
$actionlintExit = $LASTEXITCODE
Assert-True ($actionlintExit -eq 0) 'actionlint passes with exit code 0'
if ($actionlintExit -ne 0) {
    Write-Result "  actionlint errors: $($actionlintOutput -join '; ')"
}

# ============================================================
# ACT TEST CASE 1: Mixed licenses (package.json)
# ============================================================
Write-Result ''
Write-TestHeader 'ACT Test Case 1: Mixed Licenses (package.json)'

$repo1 = New-TestRepo -TestName 'mixed'
$result1 = Invoke-ActTest -RepoPath $repo1

Write-Result ''
Write-Result '--- act output (last 60 lines) ---'
$lines1 = $result1.Output -split "`n"
$tail1 = if ($lines1.Count -gt 60) { $lines1[-60..-1] } else { $lines1 }
$tail1 | ForEach-Object { Write-Result "  $_" }
Write-Result '--- end act output ---'
Write-Result ''

# Assert exit code
Assert-True ($result1.ExitCode -eq 0) 'act exited with code 0'

# Assert Job succeeded
Assert-True ($result1.Output -match 'Job succeeded') 'Job shows "Job succeeded"'

# Assert Pester tests ran and passed
Assert-True ($result1.Output -match 'Tests Passed: 37') 'All 37 Pester tests passed'
Assert-True ($result1.Output -match 'Failed: 0') 'Zero Pester test failures'

# Assert exact report values for mixed-package.json
Assert-True ($result1.Output -match '\[APPROVED\] express@4\.18\.2 - MIT') 'express@4.18.2 is APPROVED with MIT license'
Assert-True ($result1.Output -match '\[APPROVED\] lodash@4\.17\.21 - MIT') 'lodash@4.17.21 is APPROVED with MIT license'
Assert-True ($result1.Output -match '\[DENIED\] gpl-pkg@1\.0\.0 - GPL-3\.0') 'gpl-pkg@1.0.0 is DENIED with GPL-3.0 license'
Assert-True ($result1.Output -match '\[UNKNOWN\] mystery-pkg@0\.1\.0 - Unknown') 'mystery-pkg@0.1.0 is UNKNOWN'
Assert-True ($result1.Output -match 'Summary: 2 approved, 1 denied, 1 unknown') 'Mixed report summary: 2 approved, 1 denied, 1 unknown'
Assert-True ($result1.Output -match 'Overall Status: FAIL') 'Mixed report overall status: FAIL'
Assert-True ($result1.Output -match 'Total Dependencies: 4') 'Mixed report total dependencies: 4'
Assert-True ($result1.Output -match 'Manifest: mixed-package\.json') 'Mixed report manifest: mixed-package.json'

# Assert all-approved report values
Assert-True ($result1.Output -match '\[APPROVED\] requests@2\.31\.0 - Apache-2\.0') 'requests@2.31.0 is APPROVED with Apache-2.0'
Assert-True ($result1.Output -match '\[APPROVED\] flask@3\.0\.0 - BSD-3-Clause') 'flask@3.0.0 is APPROVED with BSD-3-Clause'
Assert-True ($result1.Output -match 'Summary: 2 approved, 0 denied, 0 unknown') 'Approved report summary: 2 approved, 0 denied, 0 unknown'
Assert-True ($result1.Output -match 'Overall Status: PASS') 'Approved report overall status: PASS'

# Assert denied report values
Assert-True ($result1.Output -match '\[DENIED\] agpl-pkg@2\.0\.0 - AGPL-3\.0') 'agpl-pkg@2.0.0 is DENIED with AGPL-3.0'
Assert-True ($result1.Output -match 'Summary: 0 approved, 2 denied, 0 unknown') 'Denied report summary: 0 approved, 2 denied, 0 unknown'

# Clean up
Remove-Item $repo1 -Recurse -Force -ErrorAction SilentlyContinue

# ============================================================
# ACT TEST CASE 2: Custom config - stricter deny list
# ============================================================
Write-Result ''
Write-TestHeader 'ACT Test Case 2: Stricter Config (BSD denied)'

# Create a custom config that denies BSD-3-Clause
$strictConfig = @'
{
  "allowedLicenses": ["MIT"],
  "deniedLicenses": ["GPL-3.0", "AGPL-3.0", "BSD-3-Clause"]
}
'@

# Create a manifest with a BSD-3-Clause dependency
$strictManifest = @'
{
  "name": "test-strict",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.2",
    "left-pad": "^1.3.0"
  }
}
'@

# Custom workflow that uses the strict config and custom manifest
$strictWorkflow = @"
name: Dependency License Checker

on:
  push:
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  check-licenses:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install PowerShell
        run: |
          if command -v pwsh &>/dev/null; then
            echo "PowerShell already installed"
          else
            apt-get update -qq
            apt-get install -y -qq wget libicu74 >/dev/null 2>&1
            wget -q "https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/powershell-7.4.6-linux-x64.tar.gz" -O /tmp/powershell.tar.gz
            mkdir -p /opt/microsoft/powershell/7
            tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7
            chmod +x /opt/microsoft/powershell/7/pwsh
            ln -sf /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh
          fi

      - name: Install Pester
        shell: pwsh
        run: |
          Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser

      - name: Run Pester Tests
        shell: pwsh
        run: |
          `$results = Invoke-Pester -Path ./DependencyLicenseChecker.Tests.ps1 -Output Detailed -PassThru
          Write-Host "Tests Passed: `$(`$results.PassedCount), Failed: `$(`$results.FailedCount)"
          if (`$results.FailedCount -gt 0) { exit 1 }

      - name: Run License Check - Strict
        shell: pwsh
        run: |
          . ./DependencyLicenseChecker.ps1
          `$report = New-ComplianceReport ``
            -ManifestPath ./strict-manifest.json ``
            -ConfigPath ./strict-config.json ``
            -LicenseDbPath ./license-db.json
          Write-Host `$report
"@

$repo2 = New-TestRepo -TestName 'strict' -FixtureOverrides @{
    'strict-config.json'   = $strictConfig
    'strict-manifest.json' = $strictManifest
    '.github/workflows/dependency-license-checker.yml' = $strictWorkflow
}

$result2 = Invoke-ActTest -RepoPath $repo2

Write-Result ''
Write-Result '--- act output (last 40 lines) ---'
$lines2 = $result2.Output -split "`n"
$tail2 = if ($lines2.Count -gt 40) { $lines2[-40..-1] } else { $lines2 }
$tail2 | ForEach-Object { Write-Result "  $_" }
Write-Result '--- end act output ---'
Write-Result ''

Assert-True ($result2.ExitCode -eq 0) 'act exited with code 0'
Assert-True ($result2.Output -match 'Job succeeded') 'Job shows "Job succeeded"'

# express is MIT -> approved, left-pad is BSD-3-Clause -> denied under strict config
Assert-True ($result2.Output -match '\[APPROVED\] express@4\.18\.2 - MIT') 'express@4.18.2 is APPROVED (MIT in strict config)'
Assert-True ($result2.Output -match '\[DENIED\] left-pad@1\.3\.0 - BSD-3-Clause') 'left-pad@1.3.0 is DENIED (BSD-3-Clause denied in strict config)'
Assert-True ($result2.Output -match 'Summary: 1 approved, 1 denied, 0 unknown') 'Strict report summary: 1 approved, 1 denied, 0 unknown'
Assert-True ($result2.Output -match 'Overall Status: FAIL') 'Strict report overall status: FAIL'
Assert-True ($result2.Output -match 'Total Dependencies: 2') 'Strict report total dependencies: 2'

Remove-Item $repo2 -Recurse -Force -ErrorAction SilentlyContinue

# ============================================================
# ACT TEST CASE 3: Requirements.txt only - all pass
# ============================================================
Write-Result ''
Write-TestHeader 'ACT Test Case 3: Requirements.txt Only - All Pass'

$pyManifest = @'
requests==2.31.0
flask==3.0.0
numpy==1.26.0
'@

$pyWorkflow = @"
name: Dependency License Checker

on:
  push:
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  check-licenses:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install PowerShell
        run: |
          if command -v pwsh &>/dev/null; then
            echo "PowerShell already installed"
          else
            apt-get update -qq
            apt-get install -y -qq wget libicu74 >/dev/null 2>&1
            wget -q "https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/powershell-7.4.6-linux-x64.tar.gz" -O /tmp/powershell.tar.gz
            mkdir -p /opt/microsoft/powershell/7
            tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7
            chmod +x /opt/microsoft/powershell/7/pwsh
            ln -sf /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh
          fi

      - name: Install Pester
        shell: pwsh
        run: |
          Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser

      - name: Run Pester Tests
        shell: pwsh
        run: |
          `$results = Invoke-Pester -Path ./DependencyLicenseChecker.Tests.ps1 -Output Detailed -PassThru
          Write-Host "Tests Passed: `$(`$results.PassedCount), Failed: `$(`$results.FailedCount)"
          if (`$results.FailedCount -gt 0) { exit 1 }

      - name: Run License Check - Python
        shell: pwsh
        run: |
          . ./DependencyLicenseChecker.ps1
          `$report = New-ComplianceReport ``
            -ManifestPath ./py-requirements.txt ``
            -ConfigPath ./license-config.json ``
            -LicenseDbPath ./license-db.json
          Write-Host `$report
"@

$repo3 = New-TestRepo -TestName 'python' -FixtureOverrides @{
    'py-requirements.txt' = $pyManifest
    '.github/workflows/dependency-license-checker.yml' = $pyWorkflow
}

$result3 = Invoke-ActTest -RepoPath $repo3

Write-Result ''
Write-Result '--- act output (last 40 lines) ---'
$lines3 = $result3.Output -split "`n"
$tail3 = if ($lines3.Count -gt 40) { $lines3[-40..-1] } else { $lines3 }
$tail3 | ForEach-Object { Write-Result "  $_" }
Write-Result '--- end act output ---'
Write-Result ''

Assert-True ($result3.ExitCode -eq 0) 'act exited with code 0'
Assert-True ($result3.Output -match 'Job succeeded') 'Job shows "Job succeeded"'

# requests=Apache-2.0, flask=BSD-3-Clause, numpy=BSD-3-Clause -> all approved
Assert-True ($result3.Output -match '\[APPROVED\] requests@2\.31\.0 - Apache-2\.0') 'requests@2.31.0 is APPROVED with Apache-2.0'
Assert-True ($result3.Output -match '\[APPROVED\] flask@3\.0\.0 - BSD-3-Clause') 'flask@3.0.0 is APPROVED with BSD-3-Clause'
Assert-True ($result3.Output -match '\[APPROVED\] numpy@1\.26\.0 - BSD-3-Clause') 'numpy@1.26.0 is APPROVED with BSD-3-Clause'
Assert-True ($result3.Output -match 'Summary: 3 approved, 0 denied, 0 unknown') 'Python report summary: 3 approved, 0 denied, 0 unknown'
Assert-True ($result3.Output -match 'Overall Status: PASS') 'Python report overall status: PASS'
Assert-True ($result3.Output -match 'Total Dependencies: 3') 'Python report total dependencies: 3'
Assert-True ($result3.Output -match 'Manifest: py-requirements\.txt') 'Python report manifest: py-requirements.txt'

Remove-Item $repo3 -Recurse -Force -ErrorAction SilentlyContinue

# ============================================================
# SUMMARY
# ============================================================
Write-Result ''
Write-Result ('=' * 70)
Write-Result 'TEST SUMMARY'
Write-Result ('=' * 70)
Write-Result "Total assertions: $totalTests"
Write-Result "Passed: $passedTests"
Write-Result "Failed: $failedTests"
Write-Result ''

if ($failedTests -gt 0) {
    Write-Result 'RESULT: SOME TESTS FAILED'
    exit 1
} else {
    Write-Result 'RESULT: ALL TESTS PASSED'
    exit 0
}
