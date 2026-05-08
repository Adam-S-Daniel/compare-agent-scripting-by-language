<#
.SYNOPSIS
    End-to-end test harness: drives the GitHub Actions workflow through
    `act` for each test case and asserts on exact expected output.

.DESCRIPTION
    For each test case the harness:
      1. Creates a temp dir, copies the project files (script, tests,
         workflow, .actrc) into it, and writes the case's fixture files.
      2. `git init`s the temp dir (act expects a real git repo).
      3. Runs `act push --rm`, captures stdout+stderr.
      4. Appends the output to ./act-result.txt (delimited per case).
      5. Asserts: exit 0, "Job succeeded" appears for each job, and the
         workflow log contains the exact expected NEW_VERSION / BUMP_TYPE
         / OLD_VERSION for that input.

    Total of three `act push` invocations (one per case) which is the
    self-imposed budget for the project.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot   = $PSScriptRoot
$resultFile = Join-Path $repoRoot 'act-result.txt'

# Lightweight assertion helper - throws on failure so the script aborts.
$script:failures = New-Object System.Collections.Generic.List[string]
function Assert-True {
    param([Parameter(Mandatory)]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) {
        $script:failures.Add($Message) | Out-Null
        Write-Host "  FAIL: $Message" -ForegroundColor Red
    } else {
        Write-Host "  PASS: $Message" -ForegroundColor Green
    }
}

# ---------------- 1) Workflow structure assertions ----------------------
Write-Host '--- Workflow structure tests ---' -ForegroundColor Cyan
$wf = Join-Path $repoRoot '.github/workflows/semantic-version-bumper.yml'
Assert-True (Test-Path $wf) "workflow file exists at $wf"
$wfRaw = Get-Content $wf -Raw
Assert-True ($wfRaw -match '(?m)^on:')                  'workflow has "on:" triggers'
Assert-True ($wfRaw -match '(?m)^jobs:')                'workflow has "jobs:" section'
Assert-True ($wfRaw -match 'actions/checkout@v4')       'workflow uses actions/checkout@v4'
Assert-True ($wfRaw -match 'Bump-Version\.ps1')         'workflow references Bump-Version.ps1'
Assert-True ($wfRaw -match 'Bump-Version\.Tests\.ps1')  'workflow references Bump-Version.Tests.ps1'
Assert-True ($wfRaw -match 'shell:\s+pwsh')             'workflow uses shell: pwsh'
Assert-True ($wfRaw -match 'workflow_dispatch')         'workflow supports manual dispatch'

Assert-True (Test-Path (Join-Path $repoRoot 'Bump-Version.ps1'))       'Bump-Version.ps1 exists'
Assert-True (Test-Path (Join-Path $repoRoot 'Bump-Version.Tests.ps1')) 'Bump-Version.Tests.ps1 exists'

$null = & actionlint $wf
Assert-True ($LASTEXITCODE -eq 0) 'actionlint exits 0'

# ---------------- 2) act execution per fixture case ----------------------
$cases = @(
    @{ Name='minor-feat';     StartVersion='1.1.0'; Commits="feat: add new login flag`n---`nchore: tidy up";          ExpectedNew='1.2.0'; ExpectedBump='minor' }
    @{ Name='patch-fix';      StartVersion='2.3.4'; Commits="fix: handle null user`n---`nfix(api): correct status";    ExpectedNew='2.3.5'; ExpectedBump='patch' }
    @{ Name='major-breaking'; StartVersion='1.0.0'; Commits="feat!: redesign public API`n---`nfix: misc cleanups";     ExpectedNew='2.0.0'; ExpectedBump='major' }
)

# Truncate the consolidated result log up front (always created).
'' | Set-Content -LiteralPath $resultFile

foreach ($case in $cases) {
    Write-Host ''
    Write-Host "--- act case: $($case.Name) ($($case.StartVersion) -> $($case.ExpectedNew)) ---" -ForegroundColor Cyan

    $tmp = Join-Path ([IO.Path]::GetTempPath()) "act-$($case.Name)-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        # Copy project files needed by the workflow.
        Copy-Item -Path (Join-Path $repoRoot '.github')                -Destination $tmp -Recurse
        Copy-Item -Path (Join-Path $repoRoot '.actrc')                 -Destination $tmp
        Copy-Item -Path (Join-Path $repoRoot 'Bump-Version.ps1')       -Destination $tmp
        Copy-Item -Path (Join-Path $repoRoot 'Bump-Version.Tests.ps1') -Destination $tmp

        # Write per-case fixtures.
        $fixDir = Join-Path $tmp 'fixture'
        New-Item -ItemType Directory -Path $fixDir | Out-Null
        Set-Content -LiteralPath (Join-Path $fixDir 'package.json') `
            -Value ('{"name":"demo","version":"' + $case.StartVersion + '"}')
        Set-Content -LiteralPath (Join-Path $fixDir 'commits.txt') -Value $case.Commits

        Push-Location $tmp
        try {
            & git init -q -b main 2>&1 | Out-Null
            & git config user.email 'test@test.test' | Out-Null
            & git config user.name  'test'           | Out-Null
            & git add . | Out-Null
            & git commit -q -m 'init' | Out-Null

            # Single `act push --rm` per case (3 total).
            $output = & act push --rm 2>&1 | Out-String
            $exit   = $LASTEXITCODE
        }
        finally { Pop-Location }

        # Append the output (always - even on failure - so we have artifacts).
        Add-Content -LiteralPath $resultFile -Value ("===== CASE: $($case.Name) (exit=$exit) =====")
        Add-Content -LiteralPath $resultFile -Value $output
        Add-Content -LiteralPath $resultFile -Value ''

        # Assertions.
        Assert-True ($exit -eq 0) "[$($case.Name)] act exited 0 (got $exit)"
        $jobSucceededCount = ([regex]::Matches($output, 'Job succeeded')).Count
        Assert-True ($jobSucceededCount -ge 2) "[$($case.Name)] both jobs report 'Job succeeded' (got $jobSucceededCount)"
        Assert-True ($output -match ('NEW_VERSION=' + [regex]::Escape($case.ExpectedNew))) `
            "[$($case.Name)] output contains NEW_VERSION=$($case.ExpectedNew)"
        Assert-True ($output -match ('BUMP_TYPE=' + [regex]::Escape($case.ExpectedBump))) `
            "[$($case.Name)] output contains BUMP_TYPE=$($case.ExpectedBump)"
        Assert-True ($output -match ('OLD_VERSION=' + [regex]::Escape($case.StartVersion))) `
            "[$($case.Name)] output contains OLD_VERSION=$($case.StartVersion)"
    }
    finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
Write-Host '--- Summary ---' -ForegroundColor Cyan
if ($script:failures.Count -gt 0) {
    Write-Host "FAILED: $($script:failures.Count) assertion(s)" -ForegroundColor Red
    $script:failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host "ALL ASSERTIONS PASSED" -ForegroundColor Green
Write-Host "act-result.txt written to $resultFile"
exit 0
