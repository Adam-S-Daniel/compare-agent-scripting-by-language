# act-driven integration harness.
#
# Each case copies the repo into a fresh temp dir, swaps in the case's fixture,
# initializes git, runs `act push --rm`, and asserts on exact expected values
# parsed from the workflow output. All output is appended (delimited) to
# act-result.txt in the repo root.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$resultFile = Join-Path $repo 'act-result.txt'
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }

# Three test cases. Each "expected" block lists substrings that MUST appear in
# the act output for that case (the markdown summary line is the most precise
# signal — exact counts).
$cases = @(
    @{
        Name    = 'mixed'
        Fixture = @{
            secrets = @(
                @{ name = 'api-key';  lastRotated = '2026-05-01'; rotationPolicyDays = 30; requiredBy = @('api') }
                @{ name = 'db-pass';  lastRotated = '2026-04-12'; rotationPolicyDays = 30; requiredBy = @('db','worker') }
                @{ name = 'old-cert'; lastRotated = '2026-01-01'; rotationPolicyDays = 30; requiredBy = @('gw') }
            )
        }
        Expected = @(
            '**Summary:** expired=1 warning=1 ok=1'
            '| old-cert | expired | -96 | gw |'
            '| db-pass | warning | 5 | db, worker |'
            '| api-key | ok | 24 | api |'
        )
    },
    @{
        Name    = 'all-ok'
        Fixture = @{
            secrets = @(
                @{ name = 'fresh-1'; lastRotated = '2026-05-05'; rotationPolicyDays = 90; requiredBy = @('svc') }
                @{ name = 'fresh-2'; lastRotated = '2026-04-30'; rotationPolicyDays = 60; requiredBy = @('web') }
            )
        }
        Expected = @(
            '**Summary:** expired=0 warning=0 ok=2'
        )
    },
    @{
        Name    = 'all-expired'
        Fixture = @{
            secrets = @(
                @{ name = 'rotted-1'; lastRotated = '2025-12-01'; rotationPolicyDays = 30; requiredBy = @('a') }
                @{ name = 'rotted-2'; lastRotated = '2026-01-15'; rotationPolicyDays = 30; requiredBy = @('b') }
            )
        }
        Expected = @(
            '**Summary:** expired=2 warning=0 ok=0'
            '| rotted-1 | expired |'
            '| rotted-2 | expired |'
        )
    }
)

function Initialize-CaseDir {
    param([string]$Name, $Fixture)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("srv-act-$Name-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $dir | Out-Null

    # Copy project files (excluding .git and act-result.txt and the temp dir itself)
    Copy-Item -Path (Join-Path $repo '.github')    -Destination $dir -Recurse
    Copy-Item -Path (Join-Path $repo 'fixtures')   -Destination $dir -Recurse
    Copy-Item -Path (Join-Path $repo 'SecretRotationValidator.ps1')      -Destination $dir
    Copy-Item -Path (Join-Path $repo 'SecretRotationValidator.Tests.ps1') -Destination $dir
    Copy-Item -Path (Join-Path $repo 'Invoke-Validator.ps1')             -Destination $dir
    Copy-Item -Path (Join-Path $repo '.actrc')                           -Destination $dir

    # Override fixture for this case
    $Fixture | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $dir 'fixtures/secrets.json')

    # Git init (act needs a git repo)
    Push-Location $dir
    try {
        git init -q -b main
        git config user.email 'ci@example.com'
        git config user.name 'ci'
        git add -A
        git commit -q -m 'test fixture'
    } finally { Pop-Location }
    return $dir
}

$failures = @()
foreach ($case in $cases) {
    Write-Host "=== Running case: $($case.Name) ==="
    $caseDir = Initialize-CaseDir -Name $case.Name -Fixture $case.Fixture
    try {
        Push-Location $caseDir
        $output = act push --rm 2>&1 | Out-String
        $exit = $LASTEXITCODE
        Pop-Location

        Add-Content -Path $resultFile -Value "===== CASE: $($case.Name) (exit=$exit) ====="
        Add-Content -Path $resultFile -Value $output
        Add-Content -Path $resultFile -Value "===== END CASE: $($case.Name) ====="

        if ($exit -ne 0) {
            $failures += "[$($case.Name)] act exited with code $exit"
            continue
        }
        if ($output -notmatch 'Job succeeded') {
            $failures += "[$($case.Name)] no 'Job succeeded' line in output"
        }
        # Pester tests should run inside the workflow.
        if ($output -notmatch 'Tests Passed: 12') {
            $failures += "[$($case.Name)] expected 'Tests Passed: 12' in pester output"
        }
        foreach ($expected in $case.Expected) {
            if ($output -notlike "*$expected*") {
                $failures += "[$($case.Name)] missing expected substring: $expected"
            }
        }
    } finally {
        Remove-Item -Recurse -Force $caseDir -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    Write-Host "`nFAILURES:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host "`nAll act cases passed." -ForegroundColor Green
exit 0
