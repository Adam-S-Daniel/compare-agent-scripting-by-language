#!/usr/bin/env pwsh
# Run-ActTests.ps1
#
# Drives the GitHub Actions workflow through `act` against multiple test
# fixtures, asserting on EXACT expected output for each case. This is the
# integration harness required by the task brief.
#
# Approach:
#  1. Static checks first (cheap, no Docker): verify file layout,
#     parse the YAML for expected structure, run actionlint.
#  2. For each test case, prepare a tmp git repo containing:
#       - all project files (script, module, tests, workflow, .actrc)
#       - ci-fixtures/{manifest.json, license-config.json, license-data.json}
#         populated with the case's data
#     Run `act push --rm` once per case. Append every byte of act output
#     to act-result.txt with a clear delimiter so the file is the audit
#     trail for the whole harness run.
#  3. Assert exit code 0 from act, "Job succeeded" markers for both jobs,
#     and that the captured stdout contains the EXACT expected report
#     lines for that case (e.g. "Approved : 3", a specific
#     "name@version | license=X | status=Y" line, etc).
#
# Limit: at most 3 `act push` runs total, per the task brief.

[CmdletBinding()]
param(
    [switch] $SkipAct,
    [switch] $SkipUnitTests
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$ProjectRoot   = $PSScriptRoot
$WorkflowPath  = Join-Path $ProjectRoot '.github/workflows/dependency-license-checker.yml'
$ResultFile    = Join-Path $ProjectRoot 'act-result.txt'
$TestSummary   = [System.Collections.Generic.List[pscustomobject]]::new()

function Add-Result {
    param([string] $Name, [string] $Status, [string] $Detail = '')
    $TestSummary.Add([pscustomobject]@{ Test = $Name; Status = $Status; Detail = $Detail })
    $color = if ($Status -eq 'PASS') { 'Green' } else { 'Red' }
    Write-Host ("  [{0}] {1}{2}" -f $Status, $Name, $(if ($Detail) { " - $Detail" } else { '' })) -ForegroundColor $color
}

function Assert-True {
    param([string] $Name, [bool] $Condition, [string] $Detail = '')
    if ($Condition) { Add-Result -Name $Name -Status 'PASS' }
    else            { Add-Result -Name $Name -Status 'FAIL' -Detail $Detail }
}

# ---------------------------------------------------------------------------
# 1. Static workflow / file-layout assertions
# ---------------------------------------------------------------------------
Write-Host "`n=== Workflow structure tests ===" -ForegroundColor Cyan

Assert-True 'workflow file exists' (Test-Path -LiteralPath $WorkflowPath)
Assert-True 'script file exists'   (Test-Path -LiteralPath (Join-Path $ProjectRoot 'Check-Licenses.ps1'))
Assert-True 'module file exists'   (Test-Path -LiteralPath (Join-Path $ProjectRoot 'src/LicenseChecker.psm1'))
Assert-True 'tests directory exists' (Test-Path -LiteralPath (Join-Path $ProjectRoot 'tests'))
Assert-True 'fixtures directory exists' (Test-Path -LiteralPath (Join-Path $ProjectRoot 'fixtures'))

# Parse YAML manually (no external deps) - basic structural checks only.
$yamlText = Get-Content -LiteralPath $WorkflowPath -Raw
Assert-True 'workflow has push trigger'             ($yamlText -match '(?m)^\s*push:')
Assert-True 'workflow has pull_request trigger'     ($yamlText -match '(?m)^\s*pull_request:')
Assert-True 'workflow has schedule trigger'         ($yamlText -match '(?m)^\s*schedule:')
Assert-True 'workflow has workflow_dispatch trigger' ($yamlText -match 'workflow_dispatch:')
Assert-True 'workflow has unit-tests job'           ($yamlText -match '(?m)^\s*unit-tests:')
Assert-True 'workflow has license-scan job'         ($yamlText -match '(?m)^\s*license-scan:')
Assert-True 'license-scan needs unit-tests'         ($yamlText -match 'needs:\s*unit-tests')
Assert-True 'workflow uses actions/checkout@v4'     ($yamlText -match 'actions/checkout@v4')
Assert-True 'workflow has read permission'          ($yamlText -match 'contents:\s*read')
Assert-True 'workflow references Check-Licenses.ps1' ($yamlText -match 'Check-Licenses\.ps1')
Assert-True 'workflow uses pwsh shell'              ($yamlText -match 'shell:\s*pwsh')

# actionlint must pass cleanly.
$null = & actionlint $WorkflowPath 2>&1
Assert-True 'actionlint exits 0' ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"

# ---------------------------------------------------------------------------
# 2. Pester unit tests (sanity - mirrors what CI will run)
# ---------------------------------------------------------------------------
if (-not $SkipUnitTests) {
    Write-Host "`n=== Local Pester unit tests ===" -ForegroundColor Cyan
    $pesterCfg = New-PesterConfiguration
    $pesterCfg.Run.Path = (Join-Path $ProjectRoot 'tests')
    $pesterCfg.Output.Verbosity = 'None'
    $pesterCfg.Run.PassThru = $true
    $pesterResult = Invoke-Pester -Configuration $pesterCfg
    Assert-True 'pester unit tests pass' ($pesterResult.FailedCount -eq 0) `
        ("passed=$($pesterResult.PassedCount), failed=$($pesterResult.FailedCount)")
}

if ($SkipAct) {
    Write-Host "`nSkipping act runs (-SkipAct)." -ForegroundColor Yellow
    $TestSummary | Format-Table -AutoSize
    if ($TestSummary | Where-Object Status -EQ 'FAIL') { exit 1 } else { exit 0 }
}

# ---------------------------------------------------------------------------
# 3. act-driven integration tests
# ---------------------------------------------------------------------------

# Test cases. Each has its own fixture data and exact expected substrings
# in the report output captured by act. We assert on "exact expected
# values" - e.g. precise "Approved : 3" counts, specific
# "<name>@<version> | license=<lic> | status=<status>" report lines, and
# the final COMPLIANT/NON-COMPLIANT verdict.
$cases = @(
    [pscustomobject]@{
        Name     = 'all-approved'
        Manifest = @{
            name             = 'demo-all-good'
            version          = '0.1.0'
            dependencies     = @{ lodash = '^4.17.21'; axios = '~1.6.0' }
            devDependencies  = @{ jest   = '~29.7.0' }
        } | ConvertTo-Json -Depth 5
        Config   = @{
            allow = @('MIT', 'Apache-2.0', 'BSD-3-Clause', 'ISC')
            deny  = @('GPL-3.0', 'AGPL-3.0', 'WTFPL')
        } | ConvertTo-Json -Depth 5
        Data     = @{
            'lodash@4.17.21' = 'MIT'
            'axios@1.6.0'    = 'MIT'
            'jest@29.7.0'    = 'MIT'
        } | ConvertTo-Json
        Expect = @(
            'Total dependencies : 3'
            'Approved           : 3'
            'Denied             : 0'
            'Unknown            : 0'
            'Status             : COMPLIANT'
            'lodash@4.17.21 | license=MIT | status=approved'
            'axios@1.6.0 | license=MIT | status=approved'
            'jest@29.7.0 | license=MIT | status=approved'
        )
    },

    [pscustomobject]@{
        Name     = 'mixed-compliance'
        Manifest = @{
            name         = 'demo-mixed'
            version      = '0.1.0'
            dependencies = @{
                lodash    = '4.17.21'
                'left-pad' = '1.3.0'
                obscure   = '0.0.1'
            }
        } | ConvertTo-Json -Depth 5
        Config = @{
            allow = @('MIT', 'Apache-2.0')
            deny  = @('GPL-3.0', 'WTFPL')
        } | ConvertTo-Json -Depth 5
        Data = @{
            'lodash@4.17.21'   = 'MIT'
            'left-pad@1.3.0'   = 'WTFPL'
            # 'obscure' is intentionally absent => unknown
        } | ConvertTo-Json
        Expect = @(
            'Total dependencies : 3'
            'Approved           : 1'
            'Denied             : 1'
            'Unknown            : 1'
            'Status             : NON-COMPLIANT'
            'lodash@4.17.21 | license=MIT | status=approved'
            'left-pad@1.3.0 | license=WTFPL | status=denied'
            'obscure@0.0.1 | license=<none> | status=unknown'
        )
    },

    [pscustomobject]@{
        Name     = 'requirements-txt'
        ManifestFileName = 'manifest.txt'
        Manifest = (@(
            '# CI fixture for python-style manifest'
            'requests==2.31.0'
            'urllib3==2.0.7'
            'flask==3.0.0'
        ) -join "`n")
        Config = @{
            allow = @('Apache-2.0', 'BSD-3-Clause')
            deny  = @('GPL-3.0')
        } | ConvertTo-Json -Depth 5
        Data = @{
            'requests@2.31.0' = 'Apache-2.0'
            'urllib3@2.0.7'   = 'GPL-3.0'
            'flask@3.0.0'     = 'BSD-3-Clause'
        } | ConvertTo-Json
        Expect = @(
            'Total dependencies : 3'
            'Approved           : 2'
            'Denied             : 1'
            'Unknown            : 0'
            'Status             : NON-COMPLIANT'
            'requests@2.31.0 | license=Apache-2.0 | status=approved'
            'urllib3@2.0.7 | license=GPL-3.0 | status=denied'
            'flask@3.0.0 | license=BSD-3-Clause | status=approved'
        )
    }
)

# Reset act-result.txt for this run.
"# act-result.txt - generated $(Get-Date -Format o)" | Set-Content -LiteralPath $ResultFile -Encoding utf8

foreach ($case in $cases) {
    Write-Host "`n=== act case: $($case.Name) ===" -ForegroundColor Cyan
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("license-checker-act-{0}-{1}" -f $case.Name, [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        # Copy project files into the temp repo. We avoid copying the
        # generated act-result.txt or any prior tmp output.
        $copyPaths = @(
            'Check-Licenses.ps1', 'src', 'tests', 'fixtures',
            '.github', '.actrc'
        )
        foreach ($p in $copyPaths) {
            $src = Join-Path $ProjectRoot $p
            if (Test-Path -LiteralPath $src) {
                Copy-Item -LiteralPath $src -Destination $tmp -Recurse -Force
            }
        }

        # Drop case-specific CI fixtures into ci-fixtures/.
        $ciFixDir = Join-Path $tmp 'ci-fixtures'
        New-Item -ItemType Directory -Path $ciFixDir -Force | Out-Null

        $manifestName = if ($case.PSObject.Properties.Name -contains 'ManifestFileName') {
            $case.ManifestFileName
        } else { 'manifest.json' }
        $case.Manifest | Set-Content -LiteralPath (Join-Path $ciFixDir $manifestName) -Encoding utf8
        $case.Config   | Set-Content -LiteralPath (Join-Path $ciFixDir 'license-config.json') -Encoding utf8
        $case.Data     | Set-Content -LiteralPath (Join-Path $ciFixDir 'license-data.json')   -Encoding utf8

        # If the manifest filename isn't manifest.json, override the
        # workflow's default by patching the YAML.
        if ($manifestName -ne 'manifest.json') {
            $wfPath = Join-Path $tmp '.github/workflows/dependency-license-checker.yml'
            (Get-Content -LiteralPath $wfPath -Raw) `
                -replace "ci-fixtures/manifest\.json", "ci-fixtures/$manifestName" `
                | Set-Content -LiteralPath $wfPath -Encoding utf8
        }

        # Init git repo - act requires one for the push event.
        Push-Location $tmp
        try {
            & git init -q
            & git config user.email 'act@example.com'
            & git config user.name  'act'
            & git checkout -q -b main 2>$null
            & git add -A
            & git commit -q -m "case: $($case.Name)" | Out-Null

            # Run act. We DO NOT use --container-architecture; act picks
            # the right one from .actrc (-P ubuntu-latest=act-ubuntu-pwsh:latest).
            $actLog = Join-Path $tmp "act.log"
            # --pull=false: image is already built locally
            # (act-ubuntu-pwsh:latest); without this, act tries to pull
            # from Docker Hub and fails on the first image lookup.
            & act push --rm --pull=false --workflows .github/workflows/dependency-license-checker.yml 2>&1 |
                Tee-Object -FilePath $actLog | Out-Null
            $actExit = $LASTEXITCODE
        }
        finally { Pop-Location }

        # Append captured output to the audit trail.
        $delim = "==================== act case: $($case.Name) (exit=$actExit) ===================="
        Add-Content -LiteralPath $ResultFile -Value $delim
        Add-Content -LiteralPath $ResultFile -Value (Get-Content -LiteralPath $actLog -Raw)
        Add-Content -LiteralPath $ResultFile -Value ""

        $output = Get-Content -LiteralPath $actLog -Raw

        # ---- assertions ----
        Assert-True "[$($case.Name)] act exited 0" ($actExit -eq 0) "exit=$actExit"

        # Both jobs must succeed. act prints "Job succeeded" per job.
        $succeededCount = ([regex]::Matches($output, 'Job succeeded')).Count
        Assert-True "[$($case.Name)] both jobs succeeded" ($succeededCount -ge 2) `
            "found=$succeededCount"

        foreach ($needle in $case.Expect) {
            # Use Contains for exact-substring match, not regex.
            $found = $output.Contains($needle)
            Assert-True "[$($case.Name)] output contains: '$needle'" $found
        }
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# 4. Summary
# ---------------------------------------------------------------------------
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$TestSummary | Format-Table -AutoSize

$failures = @($TestSummary | Where-Object Status -EQ 'FAIL')
if ($failures.Count -gt 0) {
    Write-Host "FAILED: $($failures.Count) check(s)" -ForegroundColor Red
    exit 1
}
Write-Host "All $($TestSummary.Count) checks passed." -ForegroundColor Green
exit 0
