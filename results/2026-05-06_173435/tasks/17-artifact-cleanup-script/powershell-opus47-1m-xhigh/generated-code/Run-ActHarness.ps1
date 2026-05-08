<#
.SYNOPSIS
    Test harness that runs the artifact-cleanup workflow through act for each
    fixture case, asserts on exact expected output, and emits act-result.txt.

.DESCRIPTION
    For each case in $cases:
      1. Create a fresh temp git repo containing every project file plus
         that case's fixture data committed as fixtures/active.json.
      2. Run `act push --rm` from that repo and capture stdout+stderr.
      3. Append the captured output to act-result.txt with delimiters.
      4. Assert exit code 0, every job 'Job succeeded', and exact expected
         values for TotalArtifacts / KeptCount / DeletedCount /
         TotalReclaimedBytes / DryRun parsed out of the summary.

    Per the task brief we limit ourselves to one act push per fixture case
    (3 total).
#>
[CmdletBinding()]
param(
    [string] $RepoRoot = (Split-Path -Parent $PSCommandPath),
    [string] $ResultPath = (Join-Path (Split-Path -Parent $PSCommandPath) 'act-result.txt')
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Each case names the fixture to load and the values that MUST appear verbatim
# in the cleanup-summary block emitted by the workflow's last step.
$cases = @(
    [pscustomobject]@{
        Name             = 'age-only'
        Fixture          = 'fixtures/case-age.json'
        ExpectedSummary  = @{
            TotalArtifacts      = 5
            KeptCount           = 3
            DeletedCount        = 2
            TotalReclaimedBytes = 3000
            DryRun              = 'True'
        }
        ExpectedDeletes  = @('feb-snapshot', 'winter-build')
        ExpectedKeeps    = @('april-build', 'recent-test', 'today-build')
    }
    [pscustomobject]@{
        Name             = 'count-only'
        Fixture          = 'fixtures/case-count.json'
        ExpectedSummary  = @{
            TotalArtifacts      = 6
            KeptCount           = 4
            DeletedCount        = 2
            TotalReclaimedBytes = 500
            DryRun              = 'True'
        }
        ExpectedDeletes  = @('wf1-old', 'wf2-old')
        ExpectedKeeps    = @('wf1-mid', 'wf1-new', 'wf2-mid', 'wf2-new')
    }
    [pscustomobject]@{
        Name             = 'combined-policies'
        Fixture          = 'fixtures/case-combined.json'
        ExpectedSummary  = @{
            TotalArtifacts      = 4
            KeptCount           = 2
            DeletedCount        = 2
            TotalReclaimedBytes = 1600
            DryRun              = 'True'
        }
        ExpectedDeletes  = @('ancient', 'april-1')
        ExpectedKeeps    = @('april-20', 'wf2-only')
    }
)

function Write-ResultBanner {
    param([string]$Path, [string]$Banner)
    Add-Content -LiteralPath $Path -Value ''
    Add-Content -LiteralPath $Path -Value '================================================================='
    Add-Content -LiteralPath $Path -Value $Banner
    Add-Content -LiteralPath $Path -Value '================================================================='
    Add-Content -LiteralPath $Path -Value ''
}

function New-CaseRepo {
    <# Build a temporary git repo with the project files + active.json fixture. #>
    param([string]$Source, [string]$FixtureRel)
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("act-case-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    # Copy all project content except local .git, the harness output, and any
    # leftover act state. This keeps the repo deterministic.
    Get-ChildItem -LiteralPath $Source -Force | Where-Object {
        $_.Name -notin @('.git', '.gitignore', 'act-result.txt')
    } | ForEach-Object {
        $dest = Join-Path $tmp $_.Name
        Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force
    }
    # Make the case's fixture the workflow input.
    Copy-Item -LiteralPath (Join-Path $Source $FixtureRel) -Destination (Join-Path $tmp 'fixtures/active.json') -Force

    Push-Location $tmp
    try {
        git init -q -b main 2>&1 | Out-Null
        git config user.email 'harness@example.com'
        git config user.name  'act-harness'
        # actions/checkout@v4 inside act prefers a real-looking remote URL.
        # Pointing it at the local repo path keeps the action quiet without
        # requiring any network access.
        git remote add origin "file://$tmp" 2>&1 | Out-Null
        git add -A 2>&1 | Out-Null
        git commit -q -m 'initial' 2>&1 | Out-Null
    } finally {
        Pop-Location
    }
    return $tmp
}

function Invoke-ActOnRepo {
    param([string]$RepoDir)
    Push-Location $RepoDir
    try {
        # Use the wider PATH that has act + docker. Capture both streams.
        $output = & act push --rm 2>&1 | Out-String
        $code   = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    return @{ Output = $output; ExitCode = $code }
}

function Assert-CaseOutput {
    param(
        [pscustomobject]$Case,
        [string]$Output,
        [int]$ExitCode
    )
    $errors = [System.Collections.Generic.List[string]]::new()

    if ($ExitCode -ne 0) {
        $errors.Add("act exited with code $ExitCode (expected 0)")
    }

    # Every job in the workflow must report success.
    if ($Output -notmatch 'Job succeeded') {
        $errors.Add("Output did not contain 'Job succeeded'")
    }
    # Defensive: if act reports a failure anywhere, surface it.
    if ($Output -match 'Job failed') {
        $errors.Add("Output contains 'Job failed'")
    }

    foreach ($key in $Case.ExpectedSummary.Keys) {
        $expected = $Case.ExpectedSummary[$key]
        $pattern  = [regex]::Escape("$key=$expected")
        if ($Output -notmatch $pattern) {
            $errors.Add("Missing expected '$key=$expected' in summary output")
        }
    }

    foreach ($name in $Case.ExpectedDeletes) {
        if ($Output -notmatch ("DELETE name=" + [regex]::Escape($name) + "\s")) {
            $errors.Add("Missing expected DELETE for '$name'")
        }
    }
    foreach ($name in $Case.ExpectedKeeps) {
        if ($Output -notmatch ("KEEP name=" + [regex]::Escape($name) + "\s")) {
            $errors.Add("Missing expected KEEP for '$name'")
        }
    }

    return ,$errors
}

# Reset the result file and write a header.
Set-Content -LiteralPath $ResultPath -Value "act-result.txt - generated $(Get-Date -Format o)`n"

$failures = 0

foreach ($case in $cases) {
    Write-Host "==> Running act for case '$($case.Name)' with fixture $($case.Fixture)"
    Write-ResultBanner -Path $ResultPath -Banner "CASE: $($case.Name)  fixture=$($case.Fixture)"

    $tmp = New-CaseRepo -Source $RepoRoot -FixtureRel $case.Fixture
    try {
        $result = Invoke-ActOnRepo -RepoDir $tmp
        Add-Content -LiteralPath $ResultPath -Value "EXIT_CODE=$($result.ExitCode)"
        Add-Content -LiteralPath $ResultPath -Value "----- act output begin -----"
        Add-Content -LiteralPath $ResultPath -Value $result.Output
        Add-Content -LiteralPath $ResultPath -Value "----- act output end -----"

        $errs = Assert-CaseOutput -Case $case -Output $result.Output -ExitCode $result.ExitCode
        if ($errs.Count -gt 0) {
            $failures++
            Write-Host "  FAIL ($($errs.Count) issue(s))"
            foreach ($e in $errs) {
                Write-Host "    - $e"
                Add-Content -LiteralPath $ResultPath -Value "ASSERTION-FAIL: $e"
            }
        } else {
            Write-Host "  PASS"
            Add-Content -LiteralPath $ResultPath -Value "ASSERTION-PASS: all expectations met"
        }
    } finally {
        if (Test-Path -LiteralPath $tmp) {
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ''
if ($failures -gt 0) {
    Write-Host "$failures case(s) failed. See act-result.txt." -ForegroundColor Red
    exit 1
}
Write-Host "All $($cases.Count) cases passed. Output at $ResultPath" -ForegroundColor Green
exit 0
