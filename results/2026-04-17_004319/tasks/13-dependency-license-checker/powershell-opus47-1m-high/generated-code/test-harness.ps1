# test-harness.ps1
#
# End-to-end test harness. All tests run through the GitHub Actions workflow
# via `act`. For each case we:
#   1. Copy the project into an isolated temp git repo
#   2. Overwrite the fixture files with the case's inputs
#   3. Run `act push --rm`
#   4. Parse the captured output and assert exact expected values
#
# All act output is appended (with delimiters) to ./act-result.txt so a
# reviewer can see the full trace of every case.

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$RepoRoot   = $PSScriptRoot
$ResultFile = Join-Path $RepoRoot 'act-result.txt'
if (Test-Path -LiteralPath $ResultFile) { Remove-Item -LiteralPath $ResultFile -Force }
New-Item -ItemType File -Path $ResultFile | Out-Null

function Write-Section {
    param([string]$Title)
    Add-Content -LiteralPath $ResultFile -Value ''
    Add-Content -LiteralPath $ResultFile -Value ('=' * 72)
    Add-Content -LiteralPath $ResultFile -Value "== $Title"
    Add-Content -LiteralPath $ResultFile -Value ('=' * 72)
}

function Append-Text {
    param([string]$Text)
    Add-Content -LiteralPath $ResultFile -Value $Text
}

# ---------------------------------------------------------------------------
# Structural / static validation (runs before any act invocation).
# ---------------------------------------------------------------------------

$failures = New-Object System.Collections.Generic.List[string]

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) {
        $failures.Add($Message) | Out-Null
        Write-Host "  FAIL: $Message" -ForegroundColor Red
    } else {
        Write-Host "  OK:   $Message" -ForegroundColor Green
    }
}

Write-Host ''
Write-Host 'Structural workflow tests' -ForegroundColor Cyan
Write-Section 'Structural workflow tests'

$workflowPath = Join-Path $RepoRoot '.github/workflows/dependency-license-checker.yml'
Assert-True (Test-Path -LiteralPath $workflowPath) 'workflow file exists'

# Parse workflow YAML. pwsh has no native YAML parser so we do simple regex
# checks — enough to confirm the expected structural elements are present.
$workflowText = Get-Content -Raw -LiteralPath $workflowPath
Append-Text "Workflow path: $workflowPath"

Assert-True ($workflowText -match '(?m)^on:')            'workflow has on: triggers'
Assert-True ($workflowText -match 'push:')               'workflow triggers on push'
Assert-True ($workflowText -match 'pull_request:')       'workflow triggers on pull_request'
Assert-True ($workflowText -match 'workflow_dispatch:')  'workflow supports workflow_dispatch'
Assert-True ($workflowText -match 'schedule:')           'workflow has a scheduled trigger'
Assert-True ($workflowText -match 'actions/checkout@v4') 'workflow uses actions/checkout@v4'
Assert-True ($workflowText -match 'Invoke-LicenseChecker\.ps1') 'workflow references the CLI script'
Assert-True ($workflowText -match 'Invoke-Pester')       'workflow runs Pester tests'
Assert-True ($workflowText -match 'permissions:')        'workflow declares permissions'
Assert-True ($workflowText -match 'shell: pwsh')         'workflow run steps use pwsh shell'

Assert-True (Test-Path -LiteralPath (Join-Path $RepoRoot 'Invoke-LicenseChecker.ps1')) 'CLI script file exists'
Assert-True (Test-Path -LiteralPath (Join-Path $RepoRoot 'src/LicenseChecker.psm1'))   'module file exists'
Assert-True (Test-Path -LiteralPath (Join-Path $RepoRoot 'tests/LicenseChecker.Tests.ps1')) 'test file exists'

# actionlint should pass cleanly.
Write-Host ''
Write-Host 'Running actionlint' -ForegroundColor Cyan
Write-Section 'actionlint'
$actionlintOut = & actionlint $workflowPath 2>&1 | Out-String
Append-Text $actionlintOut
$actionlintExit = $LASTEXITCODE
Assert-True ($actionlintExit -eq 0) 'actionlint exits 0'

# ---------------------------------------------------------------------------
# act end-to-end cases. Each case feeds a different fixture set, then we parse
# the workflow output for exact expected values. The workflow writes a JSON
# block delimited by "--- JSON REPORT START/END ---" that we lift out and
# assert against.
# ---------------------------------------------------------------------------

$cases = @(
    @{
        Name        = 'all-approved'
        Description = 'All dependencies have MIT licenses that are on the allow list'
        PackageJson = @{
            name = 'all-approved'; version = '1.0.0'
            dependencies = @{ 'lodash' = '4.17.21'; 'express' = '4.18.2' }
        }
        LicenseData = @{ 'lodash' = 'MIT'; 'express' = 'MIT' }
        Expected    = @{
            # Exact expected status per dependency.
            Statuses  = @{ 'lodash' = 'approved'; 'express' = 'approved' }
            # Exact expected totals.
            Approved  = 2; Denied = 0; Unknown = 0; Total = 2
        }
    },
    @{
        Name        = 'denied-gpl'
        Description = 'GPL-3.0 package is denied; MIT package remains approved'
        PackageJson = @{
            name = 'denied-gpl'; version = '1.0.0'
            dependencies = @{ 'lodash' = '4.17.21'; 'copyleft-tool' = '1.0.0' }
        }
        LicenseData = @{ 'lodash' = 'MIT'; 'copyleft-tool' = 'GPL-3.0' }
        Expected    = @{
            Statuses  = @{ 'lodash' = 'approved'; 'copyleft-tool' = 'denied' }
            Approved  = 1; Denied = 1; Unknown = 0; Total = 2
        }
    },
    @{
        Name        = 'unknown-license'
        Description = 'A package not in the mock license data resolves to unknown'
        PackageJson = @{
            name = 'unknown-license'; version = '1.0.0'
            dependencies = @{ 'lodash' = '4.17.21'; 'mystery-pkg' = '0.1.0' }
        }
        LicenseData = @{ 'lodash' = 'MIT' }
        Expected    = @{
            Statuses  = @{ 'lodash' = 'approved'; 'mystery-pkg' = 'unknown' }
            Approved  = 1; Denied = 0; Unknown = 1; Total = 2
        }
    }
)

function Copy-ProjectForCase {
    param([string]$SourceRoot, [string]$Destination)
    # Copy only the files the workflow needs — skip artifacts, caches, git dir.
    $include = @(
        '.github', 'src', 'tests', 'fixtures',
        'Invoke-LicenseChecker.ps1', '.actrc'
    )
    New-Item -ItemType Directory -Path $Destination | Out-Null
    foreach ($name in $include) {
        $srcItem = Join-Path $SourceRoot $name
        if (Test-Path -LiteralPath $srcItem) {
            Copy-Item -LiteralPath $srcItem -Destination $Destination -Recurse -Force
        }
    }
}

function Extract-JsonReport {
    param([string]$Output)
    # act prefixes each step line with "[job/step]   | ", so we find the first
    # JSON array literal between the START / END markers and pluck it out.
    $startIdx = $Output.IndexOf('--- JSON REPORT START ---')
    $endIdx   = $Output.IndexOf('--- JSON REPORT END ---')
    if ($startIdx -lt 0 -or $endIdx -lt 0) { return $null }
    $slice = $Output.Substring($startIdx, $endIdx - $startIdx)
    $m = [regex]::Match($slice, '(?s)(\[\{.*?\}\])')
    if (-not $m.Success) { return $null }
    try { return $m.Groups[1].Value | ConvertFrom-Json } catch { return $null }
}

foreach ($case in $cases) {
    Write-Host ''
    Write-Host ("Running act case: {0} — {1}" -f $case.Name, $case.Description) -ForegroundColor Cyan
    Write-Section ("act case: {0} — {1}" -f $case.Name, $case.Description)

    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("lc-case-" + $case.Name + "-" + [Guid]::NewGuid().ToString('N'))
    Copy-ProjectForCase -SourceRoot $RepoRoot -Destination $tmpDir
    Append-Text "Temp repo: $tmpDir"

    # Overwrite fixture files with the case's data.
    $case.PackageJson | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $tmpDir 'fixtures/package.json')
    $case.LicenseData | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $tmpDir 'fixtures/license-data.json')
    # license-config.json is the same for every case — already copied.

    # act requires a git repo.
    Push-Location $tmpDir
    try {
        git init -q
        git -c user.email=ci@example.com -c user.name=ci add .
        git -c user.email=ci@example.com -c user.name=ci commit -q -m 'seed'
    } finally {
        Pop-Location
    }

    # Run act from inside the temp repo so both the workflow file and the
    # project code are picked up from the same location. --rm removes the
    # container after each case so state does not leak between runs.
    Push-Location $tmpDir
    try {
        # --pull=false because act-ubuntu-pwsh:latest is a local-only image
        # (built from Dockerfile.act) that is not published to a registry.
        $actOut = & act push --rm --pull=false 2>&1 | Out-String
        $actExit = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    Append-Text $actOut
    Append-Text "act exit code: $actExit"

    Assert-True ($actExit -eq 0) ("case '{0}' act exits 0" -f $case.Name)
    Assert-True ($actOut -match 'Job succeeded') ("case '{0}' job succeeded" -f $case.Name)

    $report = Extract-JsonReport -Output $actOut
    Assert-True ($null -ne $report) ("case '{0}' JSON report parsed" -f $case.Name)

    if ($null -ne $report) {
        # Normalize to array for easier lookup.
        $rows = @($report)
        foreach ($dep in $case.Expected.Statuses.Keys) {
            $expectedStatus = $case.Expected.Statuses[$dep]
            $row = $rows | Where-Object { $_.Name -eq $dep }
            Assert-True ($null -ne $row) ("case '{0}' contains row for {1}" -f $case.Name, $dep)
            if ($null -ne $row) {
                Assert-True ($row.Status -eq $expectedStatus) ("case '{0}' {1} status is '{2}'" -f $case.Name, $dep, $expectedStatus)
            }
        }

        $approved = @($rows | Where-Object { $_.Status -eq 'approved' }).Count
        $denied   = @($rows | Where-Object { $_.Status -eq 'denied'   }).Count
        $unknown  = @($rows | Where-Object { $_.Status -eq 'unknown'  }).Count

        Assert-True ($approved -eq $case.Expected.Approved) ("case '{0}' approved count = {1}" -f $case.Name, $case.Expected.Approved)
        Assert-True ($denied   -eq $case.Expected.Denied)   ("case '{0}' denied count = {1}"   -f $case.Name, $case.Expected.Denied)
        Assert-True ($unknown  -eq $case.Expected.Unknown)  ("case '{0}' unknown count = {1}"  -f $case.Name, $case.Expected.Unknown)
        Assert-True ($rows.Count -eq $case.Expected.Total)  ("case '{0}' total dependencies = {1}" -f $case.Name, $case.Expected.Total)
    }

    # Also assert the textual report mentions each expected package + status.
    foreach ($dep in $case.Expected.Statuses.Keys) {
        $status = $case.Expected.Statuses[$dep]
        $linePattern = [regex]::Escape($dep) + '.*' + [regex]::Escape($status)
        Assert-True ($actOut -match $linePattern) ("case '{0}' text report has line for {1} -> {2}" -f $case.Name, $dep, $status)
    }

    # Clean up the temp repo.
    Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Section 'Summary'
if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host ("FAILED: {0} assertion(s)" -f $failures.Count) -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    Append-Text ("FAILED: {0} assertion(s)" -f $failures.Count)
    foreach ($f in $failures) { Append-Text "  - $f" }
    exit 1
} else {
    Write-Host ''
    Write-Host 'All assertions passed.' -ForegroundColor Green
    Append-Text 'All assertions passed.'
    exit 0
}
