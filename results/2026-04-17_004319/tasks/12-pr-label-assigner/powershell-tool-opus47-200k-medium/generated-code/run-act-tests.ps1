# Test harness: runs the PR-label-assigner workflow under nektos/act
# for each fixture case and asserts on exact expected output.
#
# All act stdout/stderr is appended to act-result.txt in the working directory.

param(
    [string] $ActResult = (Join-Path $PSScriptRoot 'act-result.txt')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectDir = $PSScriptRoot
if (Test-Path $ActResult) { Remove-Item $ActResult -Force }

# Each case: name, files (newline-separated), expected labels (in order).
$cases = @(
    [pscustomobject]@{
        Name     = 'docs-only'
        Files    = @('docs/intro.md', 'docs/setup.md')
        Expected = @('documentation')
    },
    [pscustomobject]@{
        Name     = 'api-and-tests'
        # api+backend share priority 20, tests=30. Order: tests,api,backend.
        Files    = @('src/api/users.ts', 'src/api/users.test.ts')
        Expected = @('tests', 'api', 'backend')
    },
    [pscustomobject]@{
        Name     = 'mixed'
        # tests=30, api=20, backend=20, frontend=15, documentation=10
        Files    = @('docs/x.md', 'src/api/a.ts', 'src/web/b.ts', 'src/web/b.test.js')
        Expected = @('tests', 'api', 'backend', 'frontend', 'documentation')
    }
)

# Workflow structure tests (parse YAML, basic shape checks).
$wfPath = Join-Path $projectDir '.github/workflows/pr-label-assigner.yml'
if (-not (Test-Path $wfPath)) { throw "Workflow file missing: $wfPath" }
$wfText = Get-Content $wfPath -Raw
foreach ($needle in @('actions/checkout@v4', 'PRLabelAssigner.ps1', 'PRLabelAssigner.Tests.ps1', 'shell: pwsh', 'pull_request')) {
    if ($wfText -notmatch [regex]::Escape($needle)) {
        throw "Workflow missing expected token: $needle"
    }
}
foreach ($f in @('PRLabelAssigner.ps1', 'PRLabelAssigner.Tests.ps1', 'rules.json')) {
    if (-not (Test-Path (Join-Path $projectDir $f))) { throw "Referenced file missing: $f" }
}

# actionlint must pass.
$alOut = & actionlint $wfPath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "actionlint failed:`n$alOut"
}
Write-Host "[harness] actionlint: OK" -ForegroundColor Green

function Invoke-CaseInTempRepo {
    param($Case)

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("prlabel-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null

    # Copy project files (script, rules, tests, workflow).
    Copy-Item (Join-Path $projectDir 'PRLabelAssigner.ps1')        $tmp
    Copy-Item (Join-Path $projectDir 'PRLabelAssigner.Tests.ps1')  $tmp
    Copy-Item (Join-Path $projectDir 'rules.json')                 $tmp
    Copy-Item (Join-Path $projectDir '.actrc')                     $tmp -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path (Join-Path $tmp '.github/workflows') -Force | Out-Null
    Copy-Item (Join-Path $projectDir '.github/workflows/pr-label-assigner.yml') (Join-Path $tmp '.github/workflows/pr-label-assigner.yml')

    # Fixture: changed-files.txt
    Set-Content -Path (Join-Path $tmp 'changed-files.txt') -Value ($Case.Files -join "`n") -NoNewline

    # Init git repo (act expects one).
    Push-Location $tmp
    try {
        & git init -q
        & git config user.email "test@example.com"
        & git config user.name "test"
        & git add -A
        & git commit -q -m "fixture for $($Case.Name)"

        $delim = "===== CASE: $($Case.Name) ====="
        Add-Content -Path $ActResult -Value $delim
        Write-Host "[harness] Running act for case '$($Case.Name)'" -ForegroundColor Cyan

        $actOut = & act push --rm --pull=false 2>&1 | Out-String
        Add-Content -Path $ActResult -Value $actOut
        $exit = $LASTEXITCODE
        Add-Content -Path $ActResult -Value "===== EXIT: $exit ====="

        return [pscustomobject]@{ ExitCode = $exit; Output = $actOut }
    } finally {
        Pop-Location
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}

$failures = @()
foreach ($case in $cases) {
    $res = Invoke-CaseInTempRepo -Case $case
    if ($res.ExitCode -ne 0) {
        $failures += "Case '$($case.Name)' act exited $($res.ExitCode)"
        continue
    }

    # Both jobs must succeed.
    $succeededCount = ([regex]::Matches($res.Output, 'Job succeeded')).Count
    if ($succeededCount -lt 2) {
        $failures += "Case '$($case.Name)' expected 2 'Job succeeded', got $succeededCount"
    }

    # Script outputs a single line: "LABELS: a,b,c" — assert the EXACT string.
    $expectedLine = 'LABELS: ' + ($case.Expected -join ',')
    if ($res.Output -notmatch [regex]::Escape($expectedLine)) {
        $failures += "Case '$($case.Name)' missing exact line: '$expectedLine'"
    }
}

if ($failures.Count -gt 0) {
    Write-Host "FAILURES:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "[harness] All $($cases.Count) cases passed." -ForegroundColor Green
