#Requires -Version 7.0
<#
.SYNOPSIS
    Drive Bump-Version.ps1 entirely through the GitHub Actions pipeline by
    invoking `act` for each fixture.

.DESCRIPTION
    For every fixture under ./fixtures/<case>/:
      1. Copies the project files + that case's version.txt and commits.txt into
         a fresh temp git repo.
      2. Runs `act push --rm` from inside that repo.
      3. Captures combined stdout/stderr and appends it to act-result.txt
         (which is overwritten at the start of the run).
      4. Asserts:
           - act exit code is 0
           - "Job succeeded" appears for both 'test' and 'bump' jobs
           - The bumper printed the case's expected version
           - Pester suite reports 24 passing tests, 0 failing
    Also:
      - Asserts actionlint reports zero issues against the workflow.
      - Validates the workflow YAML structure (triggers / jobs / steps).
#>

[CmdletBinding()]
param(
    [string] $ProjectDir = $PSScriptRoot,
    [string] $ResultFile = (Join-Path $PSScriptRoot 'act-result.txt')
)

$ErrorActionPreference = 'Stop'

$failures = [System.Collections.Generic.List[string]]::new()
function Assert-Condition {
    param([bool] $Condition, [string] $Message)
    if ($Condition) {
        Write-Host "  PASS: $Message" -ForegroundColor Green
    } else {
        Write-Host "  FAIL: $Message" -ForegroundColor Red
        $script:failures.Add($Message)
    }
}

# Reset result file once. Each act run appends to it.
"== act-result.txt generated $(Get-Date -Format o) ==`n" | Set-Content -LiteralPath $ResultFile

# ---------------------------------------------------------------------------
# 1. Workflow structure tests (no Docker needed).
# ---------------------------------------------------------------------------
Write-Host "`n--- Workflow structure tests ---" -ForegroundColor Cyan

$workflowPath = Join-Path $ProjectDir '.github/workflows/semantic-version-bumper.yml'
Assert-Condition (Test-Path $workflowPath) "Workflow file exists at $workflowPath"

$workflowText = Get-Content $workflowPath -Raw
Assert-Condition ($workflowText -match '(?m)^on:') 'Workflow declares an "on" trigger block'
Assert-Condition ($workflowText -match '(?m)^\s*push:') 'Workflow triggers on push'
Assert-Condition ($workflowText -match '(?m)^\s*pull_request:') 'Workflow triggers on pull_request'
Assert-Condition ($workflowText -match '(?m)^\s*workflow_dispatch:') 'Workflow supports workflow_dispatch'
Assert-Condition ($workflowText -match 'actions/checkout@v4') 'Workflow uses actions/checkout@v4'
Assert-Condition ($workflowText -match 'shell:\s*pwsh') 'Workflow run steps use shell: pwsh'
Assert-Condition ($workflowText -match 'Bump-Version\.ps1') 'Workflow references Bump-Version.ps1'
Assert-Condition ($workflowText -match 'Bump-Version\.Tests\.ps1') 'Workflow references Bump-Version.Tests.ps1'
Assert-Condition ($workflowText -match 'jobs:\s') 'Workflow declares jobs'
Assert-Condition ($workflowText -match '(?m)^\s+test:') 'Workflow declares the "test" job'
Assert-Condition ($workflowText -match '(?m)^\s+bump:') 'Workflow declares the "bump" job'
Assert-Condition ($workflowText -match 'needs:\s*test') 'Bump job depends on test job'

# Try a YAML parse via PowerShell to confirm structure (best effort — will only
# run if PowerShell-Yaml or ConvertFrom-Yaml is available; safe to skip otherwise).
try {
    if (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue) {
        $parsed = $workflowText | ConvertFrom-Yaml
        Assert-Condition ($parsed.jobs.Count -ge 2) 'YAML parses with at least two jobs'
    }
} catch {
    Write-Host "  (skipped YAML deep-parse: $($_.Exception.Message))" -ForegroundColor DarkGray
}

# Verify referenced project files exist on disk.
foreach ($f in @('Bump-Version.ps1', 'Bump-Version.Tests.ps1')) {
    Assert-Condition (Test-Path (Join-Path $ProjectDir $f)) "Project file $f exists"
}

# ---------------------------------------------------------------------------
# 2. actionlint must report zero issues.
# ---------------------------------------------------------------------------
Write-Host "`n--- actionlint ---" -ForegroundColor Cyan
$alOutput = & actionlint $workflowPath 2>&1
$alExit = $LASTEXITCODE
Assert-Condition ($alExit -eq 0) "actionlint exits 0 (output: $alOutput)"

# ---------------------------------------------------------------------------
# 3. Run the workflow once per fixture through act.
# ---------------------------------------------------------------------------
$cases = @(
    @{ Name = 'feat-minor';     Expected = '1.3.0' }
    @{ Name = 'fix-patch';      Expected = '1.2.4' }
    @{ Name = 'breaking-major'; Expected = '2.0.0' }
)

# Files to copy from the source project into each ephemeral repo.
$projectFiles = @(
    'Bump-Version.ps1'
    'Bump-Version.Tests.ps1'
    'fixtures'
    '.github'
)

# Honour the project's .actrc (custom container image with pwsh + Pester pre-installed).
$actrcSource = Join-Path $ProjectDir '.actrc'

foreach ($case in $cases) {
    Write-Host "`n--- act run: $($case.Name) (expects $($case.Expected)) ---" -ForegroundColor Cyan

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("bump-act-{0}-{1}" -f $case.Name, ([guid]::NewGuid()))
    New-Item -ItemType Directory -Path $tmp | Out-Null

    try {
        # Copy project files into the ephemeral repo.
        foreach ($f in $projectFiles) {
            $src = Join-Path $ProjectDir $f
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination $tmp -Recurse -Force
            }
        }
        if (Test-Path $actrcSource) {
            Copy-Item -Path $actrcSource -Destination (Join-Path $tmp '.actrc') -Force
        }

        # Place this case's fixture inputs at the repo root where the workflow expects them.
        Copy-Item -Path (Join-Path $ProjectDir "fixtures/$($case.Name)/version.txt") -Destination (Join-Path $tmp 'version.txt') -Force
        Copy-Item -Path (Join-Path $ProjectDir "fixtures/$($case.Name)/commits.txt") -Destination (Join-Path $tmp 'commits.txt') -Force

        # act needs an actual git repo to identify the workflow context.
        Push-Location $tmp
        try {
            git init --quiet
            git config user.email act@example.com
            git config user.name 'act runner'
            git add -A | Out-Null
            git commit --quiet -m "fixture: $($case.Name)" | Out-Null

            $delim = "`n========================================================================`n" +
                     "CASE: $($case.Name)  expected=$($case.Expected)`n" +
                     "========================================================================`n"
            Add-Content -LiteralPath $ResultFile -Value $delim

            # Capture stdout + stderr together so failure diagnostics survive in act-result.txt.
            $tmpOut = New-TemporaryFile
            # --pull=false: the custom act-ubuntu-pwsh image is local-only;
            # without this flag act tries to docker-pull it and fails.
            $proc = Start-Process -FilePath 'act' `
                -ArgumentList @('push', '--rm', '--pull=false') `
                -RedirectStandardOutput $tmpOut.FullName `
                -RedirectStandardError "$($tmpOut.FullName).err" `
                -NoNewWindow -PassThru -Wait
            $stdout = Get-Content $tmpOut.FullName -Raw
            $stderr = Get-Content "$($tmpOut.FullName).err" -Raw
            Remove-Item $tmpOut.FullName, "$($tmpOut.FullName).err" -Force -ErrorAction SilentlyContinue

            $combined = "$stdout`n$stderr"
            Add-Content -LiteralPath $ResultFile -Value $combined

            Assert-Condition ($proc.ExitCode -eq 0) "act exited 0 for $($case.Name) (was $($proc.ExitCode))"

            $jobSucceededCount = ([regex]::Matches($combined, 'Job succeeded')).Count
            Assert-Condition ($jobSucceededCount -ge 2) "Both jobs reported 'Job succeeded' (found $jobSucceededCount) for $($case.Name)"

            Assert-Condition ($combined -match [regex]::Escape("BUMPED_VERSION=$($case.Expected)")) `
                "Bumper printed BUMPED_VERSION=$($case.Expected) for $($case.Name)"

            Assert-Condition ($combined -match 'Tests Passed: 24') `
                "Pester reported 24 passing tests for $($case.Name)"
            Assert-Condition ($combined -match 'Failed: 0') `
                "Pester reported 0 failing tests for $($case.Name)"
        } finally {
            Pop-Location
        }
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`n--- Summary ---" -ForegroundColor Cyan
if ($failures.Count -eq 0) {
    Write-Host "All harness assertions passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$($failures.Count) assertion(s) failed:" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
