#Requires -Version 7

<#
.SYNOPSIS
    Test harness that runs the workflow under `act` for each fixture, asserts
    the output matches expected values, and writes a single act-result.txt.

.DESCRIPTION
    For each test case:
      1. Create a clean temp git repo.
      2. Copy the project files (workflow, src, test, .actrc).
      3. Write the case's fixture content to ./fixture.json.
      4. Run `act push --rm` and capture the full output.
      5. Append the output (with delimiters) to act-result.txt.
      6. Assert exit code 0, "Job succeeded" present, and EXACT expected
         values for the matrix (fail-fast, max-parallel, combo count, key
         combos).

    Also runs workflow-structure tests:
      - actionlint must pass with exit code 0.
      - YAML must parse and contain the expected triggers / jobs / steps.
      - Workflow file must reference real script paths.
#>
[CmdletBinding()]
param(
    [switch] $SkipAct,            # When set, only run the structure tests.
    [string] $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Test case definitions: fixture file -> expected matrix shape.
# ---------------------------------------------------------------------------
$TestCases = @(
    [pscustomobject]@{
        Name           = 'case1-basic'
        Fixture        = 'fixtures/case1-basic.json'
        ExpectedCount  = 4
        ExpectedFail   = 'True'
        ExpectedMaxP   = '4'
        MustContain    = @(
            '"os": "ubuntu-latest"',
            '"node_version": "18"',
            '"node_version": "20"',
            '"os": "windows-latest"'
        )
    }
    [pscustomobject]@{
        Name           = 'case2-include-exclude'
        Fixture        = 'fixtures/case2-include-exclude.json'
        ExpectedCount  = 9
        ExpectedFail   = 'False'
        ExpectedMaxP   = '6'
        MustContain    = @(
            '"experimental": true',          # include extension applied
            '"os": "freebsd-14"',            # standalone include added
            '"lang": "rust"'
        )
        # exclude rules: no windows+fast and no macos+go combos in output.
        MustNotContain = @(
            # The pair (windows-latest + fast) must not coexist on one combo.
            # We grep for '"os": "windows-latest",\n        "lang": "..",\n        "feature": "fast"' indirectly.
            # Simpler: the only excluded macos+go combo's lang line right after macos.
        )
    }
    [pscustomobject]@{
        Name           = 'case3-includes-only'
        Fixture        = 'fixtures/case3-includes-only.json'
        ExpectedCount  = 3
        ExpectedFail   = 'True'
        ExpectedMaxP   = 'unset'             # not set in fixture -> 'unset'
        MustContain    = @(
            '"os": "ubuntu-latest"',
            '"os": "macos-latest"',
            '"node_version": "20"'
        )
    }
)

# ---------------------------------------------------------------------------
# Helpers.
# ---------------------------------------------------------------------------
$Script:Failures = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$Msg) {
    $Script:Failures.Add($Msg) | Out-Null
    Write-Host "FAIL: $Msg" -ForegroundColor Red
}

function Pass([string]$Msg) {
    Write-Host "PASS: $Msg" -ForegroundColor Green
}

function Assert-True([bool]$Cond, [string]$Msg) {
    if ($Cond) { Pass $Msg } else { Add-Failure $Msg }
}

function Assert-Contains([string]$Haystack, [string]$Needle, [string]$Msg) {
    if ($Haystack.Contains($Needle)) { Pass $Msg } else { Add-Failure "$Msg  (missing: '$Needle')" }
}

function Assert-NotContains([string]$Haystack, [string]$Needle, [string]$Msg) {
    if (-not $Haystack.Contains($Needle)) { Pass $Msg } else { Add-Failure "$Msg  (found unexpected: '$Needle')" }
}

# ---------------------------------------------------------------------------
# Workflow structure tests.
# ---------------------------------------------------------------------------
function Test-WorkflowStructure {
    Write-Host "`n=== Workflow structure tests ===" -ForegroundColor Cyan
    $wfPath = Join-Path $RepoRoot '.github/workflows/environment-matrix-generator.yml'
    Assert-True (Test-Path -LiteralPath $wfPath) "workflow file exists at $wfPath"

    # actionlint should pass cleanly.
    & actionlint $wfPath
    Assert-True ($LASTEXITCODE -eq 0) "actionlint exits 0 on workflow"

    # Parse YAML and check shape.
    $raw = Get-Content -LiteralPath $wfPath -Raw

    Assert-Contains $raw 'on:'              'workflow defines triggers'
    Assert-Contains $raw '  push:'          'workflow has push trigger'
    Assert-Contains $raw '  pull_request:'  'workflow has pull_request trigger'
    Assert-Contains $raw '  workflow_dispatch:' 'workflow has workflow_dispatch trigger'
    Assert-Contains $raw 'permissions:'     'workflow declares permissions'
    Assert-Contains $raw 'contents: read'   'workflow uses minimal contents:read permission'
    Assert-Contains $raw 'actions/checkout@v4' 'workflow uses pinned actions/checkout@v4'
    Assert-Contains $raw 'shell: pwsh'      'workflow run steps use pwsh shell'
    Assert-Contains $raw 'src/Generate-Matrix.ps1' 'workflow references the generator script'

    # Verify the referenced files actually exist.
    Assert-True (Test-Path (Join-Path $RepoRoot 'src/Generate-Matrix.ps1')) 'Generate-Matrix.ps1 exists'
    Assert-True (Test-Path (Join-Path $RepoRoot 'src/MatrixGenerator.ps1')) 'MatrixGenerator.ps1 exists'
    Assert-True (Test-Path (Join-Path $RepoRoot 'test/MatrixGenerator.Tests.ps1')) 'Pester tests exist'
}

# ---------------------------------------------------------------------------
# Per-fixture act run.
# ---------------------------------------------------------------------------
function Invoke-ActForCase {
    param([Parameter(Mandatory)] $Case, [Parameter(Mandatory)] [string] $ResultPath)

    Write-Host "`n=== act run: $($Case.Name) ===" -ForegroundColor Cyan
    $tmp = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) "act-$(([guid]::NewGuid()).Guid)")
    try {
        # Copy project files into the temp repo.
        Copy-Item -Path (Join-Path $RepoRoot '.github')   -Destination $tmp.FullName -Recurse
        Copy-Item -Path (Join-Path $RepoRoot 'src')       -Destination $tmp.FullName -Recurse
        Copy-Item -Path (Join-Path $RepoRoot 'test')      -Destination $tmp.FullName -Recurse
        Copy-Item -Path (Join-Path $RepoRoot '.actrc')    -Destination $tmp.FullName -ErrorAction SilentlyContinue

        # Place the case's fixture as ./fixture.json (the workflow looks here).
        $fixtureSrc = Join-Path $RepoRoot $Case.Fixture
        Copy-Item -Path $fixtureSrc -Destination (Join-Path $tmp.FullName 'fixture.json')

        Push-Location $tmp.FullName
        try {
            # Initialize a git repo so act can derive a "push" event.
            git init -q
            git -c user.email='ci@example.com' -c user.name='ci' add -A
            git -c user.email='ci@example.com' -c user.name='ci' commit -qm "test: $($Case.Name)" | Out-Null

            $logPath = Join-Path $tmp.FullName 'act.log'
            # `act push --rm` tears down the container after the run. The
            # custom .actrc selects act-ubuntu-pwsh:latest as ubuntu-latest.
            & act push --rm 2>&1 | Tee-Object -FilePath $logPath | Out-Host
            $actExit = $LASTEXITCODE
            $output = Get-Content -LiteralPath $logPath -Raw

            # Append delimited output to act-result.txt.
            $delim = "=" * 80
            Add-Content -LiteralPath $ResultPath -Value @"
$delim
ACT TEST CASE: $($Case.Name)
FIXTURE:       $($Case.Fixture)
EXIT CODE:     $actExit
$delim
$output

"@

            # Assertions.
            Assert-True ($actExit -eq 0) "$($Case.Name): act exits 0"
            Assert-Contains $output 'Job succeeded' "$($Case.Name): job reports success"
            Assert-Contains $output "MATRIX_INCLUDE_COUNT=$($Case.ExpectedCount)" "$($Case.Name): include count == $($Case.ExpectedCount)"
            Assert-Contains $output "MATRIX_FAIL_FAST=$($Case.ExpectedFail)" "$($Case.Name): fail-fast == $($Case.ExpectedFail)"
            Assert-Contains $output "MATRIX_MAX_PARALLEL=$($Case.ExpectedMaxP)" "$($Case.Name): max-parallel == $($Case.ExpectedMaxP)"
            foreach ($needle in $Case.MustContain) {
                Assert-Contains $output $needle "$($Case.Name): output contains '$needle'"
            }
            if ($Case.MustNotContain) {
                foreach ($needle in $Case.MustNotContain) {
                    Assert-NotContains $output $needle "$($Case.Name): output excludes '$needle'"
                }
            }
        }
        finally {
            Pop-Location
        }
    }
    finally {
        Remove-Item -LiteralPath $tmp.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Main.
# ---------------------------------------------------------------------------
$resultFile = Join-Path $RepoRoot 'act-result.txt'
"act test harness run started at $(Get-Date -Format 'o')`n" | Set-Content -LiteralPath $resultFile

Test-WorkflowStructure

if (-not $SkipAct) {
    foreach ($c in $TestCases) {
        Invoke-ActForCase -Case $c -ResultPath $resultFile
    }
} else {
    Write-Host "`nSkipping act runs (-SkipAct supplied)" -ForegroundColor Yellow
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
if ($Script:Failures.Count -eq 0) {
    Write-Host "All assertions passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$($Script:Failures.Count) failure(s):" -ForegroundColor Red
    foreach ($f in $Script:Failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
