# Run-ActHarness.ps1
#
# End-to-end CI harness that runs every test case through the GitHub Actions
# workflow via `act`, saves combined output to act-result.txt, and asserts on
# exact expected values parsed from each run's output.
#
# Approach:
#   - Each test case has a fixture file + an expected-values hashtable.
#   - For each case we copy the project (script + workflow + module + fixture)
#     into a fresh temp dir, init it as a git repo, then run `act push --rm`
#     with -W pointing at the workflow file and --env FIXTURE_FILE to pick
#     the case's fixture.
#   - Output of every act run is appended to act-result.txt (delimited).
#   - Assertions: exit code 0, "Job succeeded" for both jobs, plus the EXACT
#     summary lines emitted by the workflow ("axis:os=count:2", "fail-fast=true",
#     etc.) match the expected values for that fixture.
#
# Limited to 3 act push runs per the benchmark instructions.

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
$ResultFile  = Join-Path $ProjectRoot 'act-result.txt'

# Fresh result file each run.
if (Test-Path $ResultFile) { Remove-Item -Force $ResultFile }
New-Item -ItemType File -Path $ResultFile | Out-Null

# Test cases. Each "expected" entry is a regex that MUST appear in the act output
# for the case to pass. The values come from running Generate-Matrix locally
# against the same fixture (see results in the README of this exercise).
$cases = @(
    @{
        Name    = 'simple'
        Fixture = 'simple.json'
        Expected = @(
            'axis:os=count:2',
            'axis:node=count:2',
            'include-count=0',
            'exclude-count=0',
            'fail-fast=true',
            'max-parallel=4'
        )
    },
    @{
        Name    = 'with-rules'
        Fixture = 'with-rules.json'
        Expected = @(
            'axis:os=count:3',
            'axis:node=count:3',
            'axis:feature=count:2',
            'include-count=1',
            'exclude-count=2',
            'fail-fast=false',
            'max-parallel=6'
        )
    }
)

function Invoke-ActCase {
    param([hashtable]$Case)

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("act-mtx-{0}-{1}" -f $Case.Name, ([guid]::NewGuid().ToString('N').Substring(0,8)))
    Write-Host "[$($Case.Name)] staging into $tmp"
    New-Item -ItemType Directory -Path $tmp | Out-Null

    # Copy the project files we need into the temp dir.
    $items = @(
        'MatrixGenerator.psm1',
        'MatrixGenerator.Tests.ps1',
        'Generate-Matrix.ps1',
        '.actrc',
        '.github',
        'fixtures'
    )
    foreach ($i in $items) {
        Copy-Item -Recurse -Force (Join-Path $ProjectRoot $i) (Join-Path $tmp $i)
    }

    # Init as a git repo so act has a workspace to mount.
    Push-Location $tmp
    try {
        git init -q -b main
        git config user.email 'harness@example.com'
        git config user.name  'Harness'
        git add . | Out-Null
        git commit -q -m 'harness fixture' | Out-Null

        # Run act. -W targets just our workflow; --env overrides FIXTURE_FILE for this case.
        $logFile = Join-Path $tmp 'act.log'
        Write-Host "[$($Case.Name)] running act push (fixture=$($Case.Fixture))"
        # --pull=false avoids hitting Docker Hub for the locally built act-ubuntu-pwsh image.
        & act push -W .github/workflows/environment-matrix-generator.yml --env "FIXTURE_FILE=$($Case.Fixture)" --pull=false --rm *>&1 | Tee-Object -FilePath $logFile | Out-Null
        $exit = $LASTEXITCODE
        $output = Get-Content $logFile -Raw

        # Append delimited output to the master act-result.txt.
        Add-Content -Path $ResultFile -Value "===== CASE: $($Case.Name) (fixture=$($Case.Fixture)) ====="
        Add-Content -Path $ResultFile -Value "EXIT_CODE=$exit"
        Add-Content -Path $ResultFile -Value $output
        Add-Content -Path $ResultFile -Value "===== END CASE: $($Case.Name) ====="
        Add-Content -Path $ResultFile -Value ""

        return [pscustomobject]@{
            Case   = $Case
            Exit   = $exit
            Output = $output
        }
    }
    finally {
        Pop-Location
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}

$failures = New-Object System.Collections.Generic.List[string]

foreach ($case in $cases) {
    $r = Invoke-ActCase -Case $case

    # Assert exit 0.
    if ($r.Exit -ne 0) {
        $failures.Add("[$($case.Name)] act exit code was $($r.Exit), expected 0")
        continue
    }
    # Assert both jobs succeeded. act prints "Job succeeded" once per job.
    $succeeded = ([regex]::Matches($r.Output, 'Job succeeded')).Count
    if ($succeeded -lt 2) {
        $failures.Add("[$($case.Name)] expected 2 'Job succeeded' lines, got $succeeded")
    }
    # Assert each expected pattern appears in the output.
    foreach ($pat in $case.Expected) {
        if ($r.Output -notmatch [regex]::Escape($pat)) {
            $failures.Add("[$($case.Name)] expected output to contain '$pat'")
        }
    }
}

Write-Host ""
Write-Host "===== ACT HARNESS SUMMARY ====="
Write-Host "Cases: $($cases.Count)"
Write-Host "Failures: $($failures.Count)"
if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Host "  - $f" }
    exit 1
}
Write-Host "All cases passed. Output saved to $ResultFile"
exit 0
