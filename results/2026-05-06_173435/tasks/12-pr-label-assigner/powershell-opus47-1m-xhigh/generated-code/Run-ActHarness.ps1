<#
.SYNOPSIS
    Drive the PR Label Assigner GitHub Actions workflow through `act` for
    every test case, validate workflow structure, and assert exact expected
    output for each case.

.DESCRIPTION
    The benchmark requires that every test case execute through the
    workflow via act. For each case this script:
      1. Builds a temp git repo containing the project files (script,
         workflow, fixtures, etc.).
      2. Writes the case's PR_LABEL_RULES / PR_LABEL_FILES env vars into a
         file passed to `act push --env-file`.
      3. Runs `act push --rm`, captures stdout+stderr, appends to
         act-result.txt with a clear delimiter.
      4. Asserts that `act` exited 0, that the workflow shows
         "Job succeeded", and that the captured output contains the
         exact expected labels CSV between BEGIN_LABELS / END_LABELS.

    Workflow structure tests run before any act invocation: actionlint,
    YAML parse, expected triggers/jobs/steps, and that the script files
    referenced by the workflow exist on disk. These are cheap and surface
    misconfigurations before the slow act runs.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot   = $PSScriptRoot,
    [string]$ResultFile = (Join-Path $PSScriptRoot 'act-result.txt'),
    [string]$OnlyCase,
    [switch]$SkipAct
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Helpers ------------------------------------------------------------

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ('=' * 72) -ForegroundColor Cyan
}

function Append-Result {
    param([string]$Path, [string]$Header, [string]$Body, [int]$ExitCode)
    $delim = '#' * 72
    $entry = @"
$delim
# $Header
# act exit code: $ExitCode
$delim
$Body

"@
    Add-Content -LiteralPath $Path -Value $entry
}

# --- Test cases ---------------------------------------------------------
# Each case sets PR_LABEL_RULES and PR_LABEL_FILES and asserts the exact
# csv that the workflow's BEGIN_LABELS/END_LABELS block must contain.

$cases = @(
    [pscustomobject]@{
        Name           = 'docs_only'
        RulesPath      = 'fixtures/rules.json'
        FilesPath      = 'fixtures/case_docs_only/changed.txt'
        ExpectedLabels = 'documentation'
    },
    [pscustomobject]@{
        Name           = 'api_and_tests'
        RulesPath      = 'fixtures/rules.json'
        FilesPath      = 'fixtures/case_api_and_tests/changed.txt'
        ExpectedLabels = 'api,tests'
    },
    [pscustomobject]@{
        Name           = 'empty'
        RulesPath      = 'fixtures/rules.json'
        FilesPath      = 'fixtures/case_empty/changed.txt'
        ExpectedLabels = ''
    },
    [pscustomobject]@{
        Name           = 'complex'
        RulesPath      = 'fixtures/rules.json'
        FilesPath      = 'fixtures/case_complex/changed.txt'
        ExpectedLabels = 'api,frontend,ci,infrastructure,tests,documentation'
    }
)

# --- Test framework -----------------------------------------------------

$failures = New-Object System.Collections.Generic.List[string]

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        Write-Host "  [PASS] $Message" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $Message" -ForegroundColor Red
        $script:failures.Add($Message) | Out-Null
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    Assert-True ($Expected -eq $Actual) "$Message  (expected '$Expected', got '$Actual')"
}

# --- Workflow structure tests -------------------------------------------

Write-Section 'Workflow structure tests'

$workflowPath = Join-Path $RepoRoot '.github/workflows/pr-label-assigner.yml'
$scriptPath   = Join-Path $RepoRoot 'Invoke-PrLabelAssigner.ps1'
$testsPath    = Join-Path $RepoRoot 'Invoke-PrLabelAssigner.tests.ps1'

Assert-True (Test-Path $workflowPath) "workflow file exists at $workflowPath"
Assert-True (Test-Path $scriptPath)   "script file exists at $scriptPath"
Assert-True (Test-Path $testsPath)    "tests file exists at $testsPath"

$workflowText = Get-Content -LiteralPath $workflowPath -Raw

Assert-True ($workflowText -match '(?m)^on:')                 'workflow has `on:` triggers'
Assert-True ($workflowText -match '(?m)^\s*push:')            'workflow triggers on push'
Assert-True ($workflowText -match '(?m)^\s*pull_request:')    'workflow triggers on pull_request'
Assert-True ($workflowText -match '(?m)^\s*workflow_dispatch:')         'workflow triggers on workflow_dispatch'
Assert-True ($workflowText -match 'actions/checkout@v4')      'workflow uses actions/checkout@v4'
Assert-True ($workflowText -match 'Invoke-PrLabelAssigner\.ps1') 'workflow references Invoke-PrLabelAssigner.ps1'
Assert-True ($workflowText -match 'shell:\s*pwsh')            'workflow uses shell: pwsh'
Assert-True ($workflowText -match 'BEGIN_LABELS')             'workflow emits BEGIN_LABELS marker'
Assert-True ($workflowText -match 'END_LABELS')               'workflow emits END_LABELS marker'

# Run actionlint and assert exit code 0.
Write-Host '  Running actionlint...'
$actionlintOutput = & actionlint $workflowPath 2>&1
$actionlintExit = $LASTEXITCODE
Assert-Equal 0 $actionlintExit 'actionlint exits 0 on workflow'
if ($actionlintExit -ne 0) {
    Write-Host ($actionlintOutput | Out-String)
}

# Verify each fixture referenced by every test case exists.
foreach ($case in $cases) {
    Assert-True (Test-Path (Join-Path $RepoRoot $case.RulesPath)) "fixture exists: $($case.RulesPath)"
    Assert-True (Test-Path (Join-Path $RepoRoot $case.FilesPath)) "fixture exists: $($case.FilesPath)"
}

# --- Reset result file --------------------------------------------------

if (Test-Path -LiteralPath $ResultFile) { Remove-Item -LiteralPath $ResultFile -Force }
$now = (Get-Date).ToString('o')
Set-Content -LiteralPath $ResultFile -Value "# act-result.txt (generated $now)`n"

# --- Per-case act runs --------------------------------------------------

if ($OnlyCase) {
    $cases = @($cases | Where-Object { $_.Name -eq $OnlyCase })
    if ($cases.Count -eq 0) { throw "No case named '$OnlyCase'" }
}

if ($SkipAct) {
    Write-Section 'Skipping act runs (-SkipAct flag set)'
} else {
    Write-Section 'Running act for each test case'

    foreach ($case in $cases) {
        Write-Host ''
        Write-Host "--- case: $($case.Name) ---" -ForegroundColor Yellow
        Write-Host "    rules: $($case.RulesPath)"
        Write-Host "    files: $($case.FilesPath)"
        Write-Host "    expected labels: '$($case.ExpectedLabels)'"

        # Build an env file for act so we don't have to escape values
        # through PowerShell -> bash -> act -> docker.
        $envFile = New-TemporaryFile
        try {
            Set-Content -LiteralPath $envFile -Value @(
                "PR_LABEL_RULES=$($case.RulesPath)"
                "PR_LABEL_FILES=$($case.FilesPath)"
            )

            Push-Location $RepoRoot
            try {
                $actArgs = @(
                    'push'
                    '--rm'
                    '--pull=false'
                    '--env-file', $envFile.FullName
                    '--container-architecture', 'linux/amd64'
                )
                Write-Host "    -> act $($actArgs -join ' ')"
                $actOutput = (& act @actArgs 2>&1) | Out-String
                $actExit = $LASTEXITCODE
            } finally {
                Pop-Location
            }
        } finally {
            Remove-Item -LiteralPath $envFile -Force -ErrorAction SilentlyContinue
        }

        Append-Result -Path $ResultFile `
            -Header "case=$($case.Name) expected='$($case.ExpectedLabels)'" `
            -Body $actOutput `
            -ExitCode $actExit

        Assert-Equal 0 $actExit "act exit code is 0 for case '$($case.Name)'"
        Assert-True ($actOutput -match 'Job succeeded') "case '$($case.Name)' shows 'Job succeeded'"

        # Extract the label CSV printed between BEGIN_LABELS and END_LABELS.
        # act formats step output lines as:
        #   [Workflow/Job]   | <line content>
        # We scan line-by-line, find BEGIN_LABELS, and read the next line's
        # post-pipe content. This is more robust than a multiline regex
        # because each line carries its own act prefix.
        $extracted = $null
        $inBlock = $false
        foreach ($line in ($actOutput -split "`r?`n")) {
            if ($inBlock) {
                if ($line -match '\bEND_LABELS\b') { break }
                $extracted = ($line -replace '^\[[^\]]+\]\s*\|\s*', '').Trim()
                break
            }
            if ($line -match '\bBEGIN_LABELS\b') { $inBlock = $true }
        }
        if ($null -eq $extracted) {
            Assert-True $false "case '$($case.Name)' contains BEGIN_LABELS/END_LABELS block"
        } else {
            Assert-Equal $case.ExpectedLabels $extracted "case '$($case.Name)' label CSV matches"
        }
    }
}

# --- Summary ------------------------------------------------------------

Write-Section 'Summary'

if ($failures.Count -eq 0) {
    Write-Host "All structure + act assertions passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$($failures.Count) failure(s):" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
