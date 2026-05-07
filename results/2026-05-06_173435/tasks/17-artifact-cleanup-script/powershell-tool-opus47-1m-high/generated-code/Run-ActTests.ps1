# Run-ActTests.ps1
#
# End-to-end test harness. For each test case under tests/cases/, copies the
# project into a fresh temp dir, drops the case's input.json/config.json into
# fixtures/, runs `act push --rm`, captures everything into act-result.txt,
# and asserts the workflow's SUMMARY: line matches the case's expected.json.
#
# All test execution flows through act, per the benchmark requirement. The
# unit-tests job in the workflow re-runs Pester inside the container so each
# act invocation also re-validates the planner logic itself.

[CmdletBinding()]
param(
    [string[]] $OnlyCase
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$resultFile = Join-Path $repoRoot 'act-result.txt'
$casesRoot  = Join-Path $repoRoot 'tests' 'cases'

# Files copied into each per-case temp repo. Anything under tests/cases/ is
# explicitly excluded -- the case being run is staged into fixtures/ instead.
$projectFiles = @(
    'ArtifactCleanup.ps1',
    'Run-Cleanup.ps1',
    '.actrc'
)
$projectDirs = @(
    '.github',
    'tests'
)

function Copy-ProjectInto {
    param([string] $TargetDir)
    foreach ($f in $projectFiles) {
        $src = Join-Path $repoRoot $f
        if (Test-Path $src) {
            Copy-Item -LiteralPath $src -Destination (Join-Path $TargetDir $f) -Force
        }
    }
    foreach ($d in $projectDirs) {
        $src = Join-Path $repoRoot $d
        if (Test-Path $src) {
            Copy-Item -LiteralPath $src -Destination (Join-Path $TargetDir $d) -Recurse -Force
        }
    }
    # Drop the per-case fixture set; tests/cases is removed from the temp repo
    # to avoid confusion -- the workflow only ever reads fixtures/.
    Remove-Item (Join-Path $TargetDir 'tests' 'cases') -Recurse -Force -ErrorAction SilentlyContinue
}

function Initialize-GitRepo {
    param([string] $Dir)
    Push-Location $Dir
    try {
        git init -q
        git config user.email 'test@example.com'
        git config user.name  'Test Harness'
        git add -A | Out-Null
        git commit -q -m 'fixture commit' | Out-Null
    } finally {
        Pop-Location
    }
}

function Append-Result {
    param([string] $Header, [string] $Body)
    $delim = '=' * 80
    $payload = @(
        $delim,
        $Header,
        $delim,
        $Body,
        ''
    ) -join "`n"
    Add-Content -LiteralPath $resultFile -Value $payload
}

# Reset the result file at the start of each harness run so stale output from
# previous attempts doesn't leak in.
Set-Content -LiteralPath $resultFile -Value "act-result.txt - generated $((Get-Date).ToString('o'))" -Encoding UTF8

# Discover cases on disk (sorted for deterministic order).
$cases = Get-ChildItem -LiteralPath $casesRoot -Directory | Sort-Object Name
if ($OnlyCase) {
    $cases = $cases | Where-Object { $OnlyCase -contains $_.Name }
}

$allPass = $true
$results = @()

foreach ($case in $cases) {
    $caseName = $case.Name
    $expectedPath = Join-Path $case.FullName 'expected.json'
    $inputPath    = Join-Path $case.FullName 'input.json'
    $configPath   = Join-Path $case.FullName 'config.json'
    foreach ($p in @($expectedPath, $inputPath, $configPath)) {
        if (-not (Test-Path $p)) { throw "Case '$caseName' missing required file: $p" }
    }
    $expected = Get-Content $expectedPath -Raw | ConvertFrom-Json

    Write-Host "" -ForegroundColor White
    Write-Host "----- CASE: $caseName -----" -ForegroundColor Cyan
    Write-Host ("Expected: deleted={0} retained={1} reclaimed_bytes={2} dry_run={3}" -f `
        $expected.deleted, $expected.retained, $expected.reclaimed_bytes, $expected.dry_run)

    # Build an isolated temp repo per case so act sees a clean state and
    # nothing cross-contaminates.
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("artifact-cleanup-$caseName-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        Copy-ProjectInto -TargetDir $tmp
        New-Item -ItemType Directory -Path (Join-Path $tmp 'fixtures') -Force | Out-Null
        Copy-Item $inputPath  (Join-Path $tmp 'fixtures' 'input.json')  -Force
        Copy-Item $configPath (Join-Path $tmp 'fixtures' 'config.json') -Force
        Initialize-GitRepo -Dir $tmp

        # Run act in the temp repo. --rm removes the container afterward; the
        # custom act-ubuntu-pwsh image is referenced via the .actrc copied in.
        Push-Location $tmp
        try {
            $output = act push --rm 2>&1 | Out-String
            $exit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        Append-Result -Header "CASE: $caseName  exit=$exit" -Body $output

        # Assertions:
        #   1. act exited 0
        #   2. each job in the workflow logged 'Job succeeded'
        #   3. SUMMARY: marker matches the case's expected values exactly
        $caseFailures = @()
        if ($exit -ne 0) { $caseFailures += "act exit code was $exit (expected 0)" }

        $jobSucceededCount = ([regex]::Matches($output, 'Job succeeded')).Count
        if ($jobSucceededCount -lt 2) {
            $caseFailures += "expected 2+ 'Job succeeded' lines, found $jobSucceededCount"
        }

        $expectedSummary = ('SUMMARY: deleted={0} retained={1} reclaimed_bytes={2} dry_run={3}' -f `
            $expected.deleted, $expected.retained, $expected.reclaimed_bytes, $expected.dry_run)
        if ($output -notmatch [regex]::Escape($expectedSummary)) {
            $caseFailures += "missing exact SUMMARY line: $expectedSummary"
        }

        # Also assert PLAN_SUMMARY (from the second job, parsed from plan.json)
        # to confirm the JSON output and the stdout summary agree.
        $expectedPlanSummary = ('PLAN_SUMMARY: deleted={0} retained={1} reclaimed_bytes={2} dry_run={3}' -f `
            $expected.deleted, $expected.retained, $expected.reclaimed_bytes, $expected.dry_run)
        if ($output -notmatch [regex]::Escape($expectedPlanSummary)) {
            $caseFailures += "missing exact PLAN_SUMMARY line: $expectedPlanSummary"
        }

        if ($caseFailures.Count -eq 0) {
            Write-Host "PASS: $caseName" -ForegroundColor Green
            $results += [pscustomobject]@{ Case = $caseName; Status = 'PASS'; Notes = '' }
        } else {
            Write-Host "FAIL: $caseName" -ForegroundColor Red
            foreach ($f in $caseFailures) { Write-Host "  - $f" -ForegroundColor Red }
            $allPass = $false
            $results += [pscustomobject]@{ Case = $caseName; Status = 'FAIL'; Notes = ($caseFailures -join '; ') }
        }
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "===== Harness summary =====" -ForegroundColor White
$results | Format-Table -AutoSize | Out-String | Write-Host

if (-not $allPass) {
    throw 'one or more act test cases failed'
}
Write-Host "All cases passed." -ForegroundColor Green
