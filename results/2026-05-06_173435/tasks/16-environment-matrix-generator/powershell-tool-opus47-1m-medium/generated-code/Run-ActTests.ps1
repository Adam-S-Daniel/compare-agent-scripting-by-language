# Run-ActTests.ps1
#
# Test harness that runs every test case end-to-end through the GitHub Actions
# workflow via `act`. Per requirements, no test executes the script directly;
# they all flow through the pipeline.
#
# For each test case:
#   1. Stage a temp git repo containing the project + the case's fixture.
#   2. Run `act push --rm` against the workflow.
#   3. Append the output (clearly delimited) to ./act-result.txt.
#   4. Assert exit code == 0 (or, for the overcap case, != 0).
#   5. Parse the strategy JSON between BEGIN_STRATEGY/END_STRATEGY markers
#      and assert exact expected values (size, fail-fast, max-parallel).
#   6. Assert each job shows "Job succeeded".
#
# Limit: at most 3 `act push` invocations.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root      = $PSScriptRoot
$resultLog = Join-Path $root 'act-result.txt'
if (Test-Path $resultLog) { Remove-Item $resultLog -Force }
$null = New-Item -ItemType File -Path $resultLog

function Invoke-ActCase {
    param(
        [string]$Name,
        [string]$FixturePath,    # path relative to repo root
        [hashtable]$Expect,      # expected fields parsed from strategy JSON
        [bool]$ExpectSuccess = $true
    )

    Write-Host "`n=== Running act case: $Name ===" -ForegroundColor Cyan

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("act-$Name-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        # Copy project files into the temp repo (workflow + script + fixtures + tests).
        Copy-Item -Recurse -Path (Join-Path $root '.github')           -Destination $tmp
        Copy-Item            -Path (Join-Path $root 'New-BuildMatrix.ps1')       -Destination $tmp
        Copy-Item            -Path (Join-Path $root 'New-BuildMatrix.Tests.ps1') -Destination $tmp
        Copy-Item -Recurse -Path (Join-Path $root 'fixtures')          -Destination $tmp

        # Initialise an isolated git repo (act expects one).
        Push-Location $tmp
        try {
            git init -q
            git config user.email harness@example.com
            git config user.name  harness
            git add -A
            git commit -qm "harness commit for $Name" | Out-Null

            # Run act with the fixture path injected through env.
            $actArgs = @(
                'push',
                '--rm',
                '--env', "MATRIX_FIXTURE=$FixturePath",
                '-W',   '.github/workflows/environment-matrix-generator.yml'
            )
            $output = & act @actArgs 2>&1 | Out-String
            $exit   = $LASTEXITCODE
        }
        finally { Pop-Location }

        # Append delimited output to the global log.
        $delim = "=" * 70
        Add-Content $resultLog "`n$delim`nCASE: $Name"
        Add-Content $resultLog "FIXTURE: $FixturePath"
        Add-Content $resultLog "EXIT: $exit"
        Add-Content $resultLog "$delim"
        Add-Content $resultLog $output

        # Assertions
        $errors = @()
        if ($ExpectSuccess) {
            if ($exit -ne 0) { $errors += "expected exit 0, got $exit" }

            # Every job must report "Job succeeded".
            $jobSucceeded = ([regex]::Matches($output, 'Job succeeded')).Count
            if ($jobSucceeded -lt 2) {
                $errors += "expected >=2 'Job succeeded' lines, got $jobSucceeded"
            }

            # Extract strategy JSON between markers and verify exact expected values.
            $m = [regex]::Match($output, 'BEGIN_STRATEGY\s+\|\s*(\{.*?\})\s+\|?\s*END_STRATEGY', 'Singleline')
            if (-not $m.Success) {
                # Try without the leading "| " act prefix on each line.
                $m = [regex]::Match($output, 'BEGIN_STRATEGY\s*(.*?)\s*END_STRATEGY', 'Singleline')
            }
            if (-not $m.Success) {
                $errors += "could not locate strategy JSON in act output"
            } else {
                # act prefixes each captured stdout line with "[job] | ". Strip aggressively.
                $jsonRaw = $m.Groups[1].Value
                $jsonRaw = $jsonRaw -replace '(?m)^\s*\[[^\]]+\]\s*\|?\s*', ''
                $jsonRaw = $jsonRaw -replace '(?m)^\s*\|\s*', ''
                $jsonRaw = ($jsonRaw -split "`n" | Where-Object { $_.Trim() -ne '' -and $_.Trim() -ne '|' }) -join ''
                $jsonRaw = $jsonRaw.Trim()
                try {
                    $parsed = $jsonRaw | ConvertFrom-Json
                } catch {
                    $errors += "failed to parse strategy JSON: $($_.Exception.Message); raw=<<<$jsonRaw>>>"
                    $parsed = $null
                }
                if ($parsed) {
                    foreach ($k in $Expect.Keys) {
                        $actual   = $parsed.$k
                        $expected = $Expect[$k]
                        if ("$actual" -ne "$expected") {
                            $errors += "$k mismatch: expected '$expected', got '$actual'"
                        }
                    }
                }
            }
        } else {
            if ($exit -eq 0) { $errors += "expected non-zero exit, got 0" }
            if ($output -notmatch 'exceeds maximum') {
                $errors += "expected 'exceeds maximum' diagnostic in failure output"
            }
        }

        if ($errors.Count -gt 0) {
            Write-Host "FAIL: $Name" -ForegroundColor Red
            $errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
            return $false
        } else {
            Write-Host "PASS: $Name" -ForegroundColor Green
            return $true
        }
    }
    finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}

# Workflow-structure tests (fast, run before any act invocation).
Write-Host "`n=== Workflow structure tests ===" -ForegroundColor Cyan
$structureFailures = @()

# 1) actionlint must pass.
& actionlint (Join-Path $root '.github/workflows/environment-matrix-generator.yml')
if ($LASTEXITCODE -ne 0) { $structureFailures += "actionlint failed" }
else { Write-Host "PASS: actionlint clean" -ForegroundColor Green }

# 2) Parse YAML and check expected structure.
Import-Module -Name powershell-yaml -ErrorAction SilentlyContinue
$yamlText = Get-Content (Join-Path $root '.github/workflows/environment-matrix-generator.yml') -Raw

# Quick string-level structural sanity (no extra modules required).
$mustContain = @(
    'on:'                               # triggers block
    'workflow_dispatch:'
    'pull_request:'
    'schedule:'
    'jobs:'
    'pester:'
    'generate:'
    'actions/checkout@v4'
    'New-BuildMatrix.ps1'
    'New-BuildMatrix.Tests.ps1'
    'shell: pwsh'
)
foreach ($needle in $mustContain) {
    if ($yamlText -notmatch [regex]::Escape($needle)) {
        $structureFailures += "workflow missing '$needle'"
    }
}

# 3) Referenced files must exist.
foreach ($f in @('New-BuildMatrix.ps1','New-BuildMatrix.Tests.ps1','fixtures/basic.json')) {
    if (-not (Test-Path (Join-Path $root $f))) { $structureFailures += "missing referenced file: $f" }
}

if ($structureFailures.Count -eq 0) {
    Write-Host "PASS: workflow structure" -ForegroundColor Green
} else {
    Write-Host "FAIL: workflow structure" -ForegroundColor Red
    $structureFailures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}

# Now run the act cases — 3 max per requirements.
$cases = @(
    @{
        Name        = 'basic'
        Fixture     = 'fixtures/basic.json'
        Success     = $true
        Expect      = @{ size = 4; 'fail-fast' = 'True';  'max-parallel' = 4 }
    },
    @{
        Name        = 'include-exclude'
        Fixture     = 'fixtures/with-include-exclude.json'
        Success     = $true
        Expect      = @{ size = 8; 'fail-fast' = 'False'; 'max-parallel' = 6 }
    },
    @{
        Name        = 'overcap'
        Fixture     = 'fixtures/overcap.json'
        Success     = $false
        Expect      = @{}
    }
)

$caseFailures = @()
foreach ($c in $cases) {
    $ok = Invoke-ActCase -Name $c.Name -FixturePath $c.Fixture `
                         -Expect $c.Expect -ExpectSuccess:$c.Success
    if (-not $ok) { $caseFailures += $c.Name }
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$totalFailures = $structureFailures.Count + $caseFailures.Count
if ($totalFailures -gt 0) {
    Write-Host "FAILED ($totalFailures)" -ForegroundColor Red
    exit 1
}
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
exit 0
