# run-act-tests.ps1
#
# Test harness. For each test case:
#   1. Build a temp git repo with project files + the fixture.
#   2. Point the workflow's FIXTURE_PATH at the case's fixture (in-place edit
#      of the copied workflow, not the original).
#   3. Commit & run `act push --rm`.
#   4. Append captured output to act-result.txt (clearly delimited).
#   5. Assert exit 0, "Job succeeded", and exact expected values parsed from
#      the markers the workflow prints (TOTAL=, FAIL-FAST=, MAX-PARALLEL=).
#
# Also performs workflow-structure tests (YAML parse + actionlint).
#
# Run with: pwsh ./run-act-tests.ps1

[CmdletBinding()]
param(
    [switch]$SkipAct
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

$resultFile = Join-Path $here 'act-result.txt'
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }
New-Item -ItemType File -Path $resultFile | Out-Null

function Append-Result {
    param([string]$Text)
    Add-Content -LiteralPath $resultFile -Value $Text
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
    Write-Host "  [ok] $Message"
}

# -----------------------------------------------------------------------------
# Workflow structure tests (cheap, run before act).
# -----------------------------------------------------------------------------

Write-Host ''
Write-Host '=== Workflow structure tests ==='

$workflowPath = Join-Path $here '.github/workflows/environment-matrix-generator.yml'
Assert-True (Test-Path $workflowPath) 'workflow file exists'

# Parse YAML - use ConvertFrom-Yaml if available, otherwise regex-based checks.
$workflowRaw = Get-Content -LiteralPath $workflowPath -Raw
Assert-True ($workflowRaw -match '(?m)^on:')           'workflow has on: section'
Assert-True ($workflowRaw -match '(?m)^\s*push:')      'workflow triggers on push'
Assert-True ($workflowRaw -match '(?m)^\s*pull_request:') 'workflow triggers on pull_request'
Assert-True ($workflowRaw -match '(?m)^\s*workflow_dispatch:') 'workflow has workflow_dispatch trigger'
Assert-True ($workflowRaw -match 'actions/checkout@v4') 'workflow uses actions/checkout@v4'
Assert-True ($workflowRaw -match 'Invoke-MatrixGenerator\.ps1') 'workflow invokes Invoke-MatrixGenerator.ps1'
Assert-True ($workflowRaw -match 'Invoke-Pester')      'workflow runs Pester'
Assert-True ($workflowRaw -match 'shell: pwsh')        'workflow uses pwsh shell'

$scriptPath = Join-Path $here 'src/Invoke-MatrixGenerator.ps1'
Assert-True (Test-Path $scriptPath) "script referenced by workflow exists at $scriptPath"

$testsPath = Join-Path $here 'tests'
Assert-True (Test-Path $testsPath) "tests directory referenced by workflow exists at $testsPath"

Write-Host ''
Write-Host '=== actionlint ==='
$actionlintOut = & actionlint $workflowPath 2>&1 | Out-String
$actionlintExit = $LASTEXITCODE
Write-Host $actionlintOut
Assert-True ($actionlintExit -eq 0) "actionlint passed (exit=$actionlintExit)"

if ($SkipAct) {
    Write-Host 'Skipping act runs (-SkipAct)'
    return
}

# -----------------------------------------------------------------------------
# Define test cases. Each case has exact expected values that the workflow
# will print as delimited markers (TOTAL=..., FAIL-FAST=..., MAX-PARALLEL=...).
# -----------------------------------------------------------------------------

$cases = @(
    [pscustomobject]@{
        Name             = 'case-1-basic-cartesian'
        Fixture          = 'test-fixtures/case-1-basic.json'
        ExpectedTotal    = 4      # 2 OSes x 2 Node versions
        ExpectedFailFast = 'True'
        ExpectedMaxPar   = '2'
    },
    [pscustomobject]@{
        Name             = 'case-2-exclude'
        Fixture          = 'test-fixtures/case-2-exclude.json'
        ExpectedTotal    = 4      # 3 x 2 = 6, minus 2 excluded = 4
        ExpectedFailFast = 'False'
        ExpectedMaxPar   = '3'
    },
    [pscustomobject]@{
        Name             = 'case-3-include'
        Fixture          = 'test-fixtures/case-3-include.json'
        ExpectedTotal    = 2      # 1 base combo + 1 include entry
        ExpectedFailFast = 'True'
        ExpectedMaxPar   = 'none' # max_parallel unspecified -> omitted
    }
)

$sourceFiles = @('src', 'tests', 'test-fixtures', '.github', '.actrc')

foreach ($case in $cases) {
    Write-Host ''
    Write-Host "=== Running case: $($case.Name) (fixture=$($case.Fixture)) ==="

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("matrix-act-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null

    try {
        foreach ($rel in $sourceFiles) {
            $src = Join-Path $here $rel
            if (Test-Path $src) {
                Copy-Item -Recurse -Force -Path $src -Destination $tmp
            }
        }

        # Rewrite FIXTURE_PATH in the copied workflow so this act run uses the
        # case's fixture. Keep original workflow untouched.
        $copiedWorkflow = Join-Path $tmp '.github/workflows/environment-matrix-generator.yml'
        (Get-Content -LiteralPath $copiedWorkflow -Raw) `
            -replace 'FIXTURE_PATH: test-fixtures/case-1-basic\.json', "FIXTURE_PATH: $($case.Fixture)" `
            | Set-Content -LiteralPath $copiedWorkflow -NoNewline

        Push-Location $tmp
        try {
            & git init -q -b main 2>&1 | Out-Null
            & git config user.email 'harness@local' 2>&1 | Out-Null
            & git config user.name  'harness'       2>&1 | Out-Null
            & git add -A                            2>&1 | Out-Null
            & git commit -q -m "case $($case.Name)" 2>&1 | Out-Null

            $actOut = & act push --rm 2>&1 | Out-String
            $actExit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        Append-Result "################################################################"
        Append-Result "# CASE: $($case.Name)"
        Append-Result "# Fixture: $($case.Fixture)"
        Append-Result "# Expected: total=$($case.ExpectedTotal) fail-fast=$($case.ExpectedFailFast) max-parallel=$($case.ExpectedMaxPar)"
        Append-Result "################################################################"
        Append-Result $actOut
        Append-Result "### ACT-EXIT: $actExit"
        Append-Result ""

        Assert-True ($actExit -eq 0)                      "act exited 0 for $($case.Name)"
        Assert-True ($actOut -match 'Job succeeded')       "Job succeeded appears for $($case.Name)"
        Assert-True ($actOut -match '----MATRIX-BEGIN----') 'matrix begin marker present'
        Assert-True ($actOut -match '----MATRIX-END----')   'matrix end marker present'
        Assert-True ($actOut -match [regex]::Escape("----TOTAL=$($case.ExpectedTotal)----")) `
            "exact total=$($case.ExpectedTotal) for $($case.Name)"
        Assert-True ($actOut -match [regex]::Escape("----FAIL-FAST=$($case.ExpectedFailFast)----")) `
            "exact fail-fast=$($case.ExpectedFailFast) for $($case.Name)"
        Assert-True ($actOut -match [regex]::Escape("----MAX-PARALLEL=$($case.ExpectedMaxPar)----")) `
            "exact max-parallel=$($case.ExpectedMaxPar) for $($case.Name)"
    }
    finally {
        Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host "=== All $($cases.Count) cases passed. Output written to $resultFile ==="
