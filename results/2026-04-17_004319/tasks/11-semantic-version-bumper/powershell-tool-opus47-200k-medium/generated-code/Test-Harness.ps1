# End-to-end test harness.
#
# Runs workflow structure assertions, then exercises the GitHub Actions
# workflow through `act` for each test case. Every case asserts on the
# EXACT expected new version (not just "some version appeared"), fails loudly
# on the first mismatch, and appends the full act output to act-result.txt.

[CmdletBinding()]
param(
    [string] $RepoRoot = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
Set-Location $RepoRoot

$resultFile = Join-Path $RepoRoot 'act-result.txt'
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }

$failures = @()
function Assert-True {
    param([bool] $Cond, [string] $Message)
    if (-not $Cond) {
        Write-Host "  FAIL: $Message" -ForegroundColor Red
        $script:failures += $Message
    } else {
        Write-Host "  PASS: $Message" -ForegroundColor Green
    }
}

# --------------------------------------------------------------------------
# Section 1 — workflow structure tests (no act needed).
# --------------------------------------------------------------------------
Write-Host "`n=== Workflow structure tests ===" -ForegroundColor Cyan

$wfPath = Join-Path $RepoRoot '.github/workflows/semantic-version-bumper.yml'
Assert-True (Test-Path $wfPath) "workflow file exists at $wfPath"

# Parse YAML via PowerShell-Yaml if available, otherwise a crude text check.
$wfText = Get-Content $wfPath -Raw
Assert-True ($wfText -match '(?m)^on:') 'workflow declares an "on:" trigger block'
Assert-True ($wfText -match 'push:')             'workflow triggers on push'
Assert-True ($wfText -match 'pull_request:')     'workflow triggers on pull_request'
Assert-True ($wfText -match 'workflow_dispatch:') 'workflow triggers on workflow_dispatch'
Assert-True ($wfText -match 'actions/checkout@v4') 'workflow uses actions/checkout@v4'
Assert-True ($wfText -match 'shell:\s*pwsh')      'workflow uses shell: pwsh'
Assert-True ($wfText -match 'Invoke-Bumper\.ps1') 'workflow references Invoke-Bumper.ps1'
Assert-True ($wfText -match 'SemanticVersionBumper\.Tests\.ps1') 'workflow references Pester tests'

# Referenced files must actually exist on disk.
Assert-True (Test-Path (Join-Path $RepoRoot 'Invoke-Bumper.ps1')) 'Invoke-Bumper.ps1 exists'
Assert-True (Test-Path (Join-Path $RepoRoot 'SemanticVersionBumper.ps1')) 'SemanticVersionBumper.ps1 exists'
Assert-True (Test-Path (Join-Path $RepoRoot 'SemanticVersionBumper.Tests.ps1')) 'Pester test file exists'

# actionlint must pass.
$alOutput = & actionlint $wfPath 2>&1
Assert-True ($LASTEXITCODE -eq 0) "actionlint exits 0 (output: $alOutput)"

# --------------------------------------------------------------------------
# Section 2 — end-to-end cases through `act push`.
# --------------------------------------------------------------------------
Write-Host "`n=== Act-based end-to-end tests ===" -ForegroundColor Cyan

# Each case sets FIXTURE env var that the workflow consumes. Expected values
# are computed by hand from the fixture content so we fail on silent drift.
$cases = @(
    @{ Name = 'minor'; Old = '1.1.0'; Expected = '1.2.0'; Bump = 'minor' },
    @{ Name = 'major'; Old = '1.4.9'; Expected = '2.0.0'; Bump = 'major' },
    @{ Name = 'none';  Old = '0.5.0'; Expected = '0.5.0'; Bump = 'none'  }
)

function Invoke-ActCase {
    param([hashtable] $Case)

    Write-Host "`n--- Case: $($Case.Name) (expect $($Case.Old) -> $($Case.Expected)) ---" -ForegroundColor Yellow

    # Sandbox the run in a temp dir so .git / act state does not leak.
    $sandbox = Join-Path ([IO.Path]::GetTempPath()) ("bumper-" + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $sandbox | Out-Null

    try {
        Copy-Item -Path (Join-Path $RepoRoot '*') -Destination $sandbox -Recurse -Force
        Copy-Item -Path (Join-Path $RepoRoot '.actrc') -Destination $sandbox -Force
        Copy-Item -Path (Join-Path $RepoRoot '.github') -Destination $sandbox -Recurse -Force

        Push-Location $sandbox
        try {
            & git init -q
            & git config user.email 'test@example.com'
            & git config user.name 'test'
            & git add -A
            & git commit -q -m "init-$($Case.Name)"

            $env:FIXTURE = $Case.Name
            $actOutput = & act push --rm --pull=false --env "FIXTURE=$($Case.Name)" 2>&1
            $actExit = $LASTEXITCODE
            Remove-Item Env:FIXTURE -ErrorAction SilentlyContinue
        } finally {
            Pop-Location
        }

        # Append case output to the shared result file with clear delimiters.
        $header = @(
            "",
            "================================================================",
            "CASE: $($Case.Name)   expected=$($Case.Expected)   bump=$($Case.Bump)",
            "================================================================",
            ""
        ) -join "`n"
        Add-Content -Path $resultFile -Value $header
        Add-Content -Path $resultFile -Value ($actOutput -join "`n")

        Assert-True ($actExit -eq 0) "[$($Case.Name)] act exited 0 (was $actExit)"

        $joined = $actOutput -join "`n"
        $jobSuccessCount = ([regex]::Matches($joined, 'Job succeeded')).Count
        Assert-True ($jobSuccessCount -ge 2) "[$($Case.Name)] both jobs report 'Job succeeded' (saw $jobSuccessCount)"

        Assert-True ($joined -match "BUMPER::OLD_VERSION=$([regex]::Escape($Case.Old))") `
            "[$($Case.Name)] OLD_VERSION is exactly $($Case.Old)"
        Assert-True ($joined -match "BUMPER::NEW_VERSION=$([regex]::Escape($Case.Expected))") `
            "[$($Case.Name)] NEW_VERSION is exactly $($Case.Expected)"
        Assert-True ($joined -match "BUMPER::BUMP_TYPE=$([regex]::Escape($Case.Bump))") `
            "[$($Case.Name)] BUMP_TYPE is exactly $($Case.Bump)"
        Assert-True ($joined -match "PKG::.*""version"":\s*""$([regex]::Escape($Case.Expected))""") `
            "[$($Case.Name)] package.json contains version $($Case.Expected)"
    } finally {
        Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
    }
}

foreach ($c in $cases) { Invoke-ActCase -Case $c }

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
if ($failures.Count -eq 0) {
    Write-Host "All assertions passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$($failures.Count) assertion(s) failed:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
