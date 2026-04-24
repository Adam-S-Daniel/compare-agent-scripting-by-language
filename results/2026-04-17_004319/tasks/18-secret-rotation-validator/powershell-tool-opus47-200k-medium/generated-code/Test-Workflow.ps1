# Test harness for the Secret Rotation Validator workflow.
#
# For each test case we:
#   1. Set up a fresh temp git repo containing the project files and the case's
#      fixture as `fixtures/secrets.json`.
#   2. Write a .env file with the case's WARNING_DAYS / REPORT_FORMAT / NOW_OVERRIDE.
#   3. Run `act push --rm --env-file .env`.
#   4. Capture output into act-result.txt and assert on exact expected strings.
#
# Total `act push` runs: 3 (one per case — within the harness limit).

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here      = $PSScriptRoot
$actResult = Join-Path $here 'act-result.txt'
Remove-Item $actResult -ErrorAction SilentlyContinue

# ---------- Structure / static checks ----------
$workflow = Join-Path $here '.github/workflows/secret-rotation-validator.yml'
if (-not (Test-Path $workflow)) { throw "Workflow file missing: $workflow" }

Write-Host "[structure] checking workflow..."
$wfText = Get-Content $workflow -Raw
foreach ($needle in @(
    'actions/checkout@v4',
    'shell: pwsh',
    'Invoke-Pester',
    'Invoke-Validator.ps1',
    'workflow_dispatch',
    'schedule',
    'permissions:'
)) {
    if ($wfText -notmatch [regex]::Escape($needle)) {
        throw "Workflow missing expected token: $needle"
    }
}
foreach ($referenced in @(
    'SecretRotationValidator.ps1',
    'SecretRotationValidator.Tests.ps1',
    'Invoke-Validator.ps1'
)) {
    if (-not (Test-Path (Join-Path $here $referenced))) {
        throw "Workflow references missing file: $referenced"
    }
}
Write-Host "[structure] OK"

Write-Host "[actionlint] running..."
& actionlint $workflow
if ($LASTEXITCODE -ne 0) { throw "actionlint failed with exit $LASTEXITCODE" }
Write-Host "[actionlint] OK"

# ---------- Test cases ----------
$cases = @(
    [pscustomobject]@{
        Name        = 'all-expired'
        WarningDays = 7
        Now         = '2026-04-20'
        Format      = 'markdown'
        Secrets     = @(
            @{ name='old-db';  lastRotated='2024-01-01'; rotationDays=90; requiredBy=@('api') },
            @{ name='old-key'; lastRotated='2024-06-01'; rotationDays=30; requiredBy=@('svc') }
        )
        MustContain = @('## Expired','old-db','old-key','- Expired: 2','- Warning: 0','- OK: 0')
    },
    [pscustomobject]@{
        Name        = 'mixed'
        WarningDays = 7
        Now         = '2026-04-20'
        Format      = 'markdown'
        Secrets     = @(
            @{ name='expired-a'; lastRotated='2025-01-01'; rotationDays=90; requiredBy=@('api') },
            @{ name='warn-b';    lastRotated='2026-01-25'; rotationDays=90; requiredBy=@('web') },
            @{ name='ok-c';      lastRotated='2026-04-19'; rotationDays=90; requiredBy=@('auth') }
        )
        MustContain = @('- Expired: 1','- Warning: 1','- OK: 1','expired-a','warn-b','ok-c')
    },
    [pscustomobject]@{
        Name        = 'json-output'
        WarningDays = 14
        Now         = '2026-04-20'
        Format      = 'json'
        Secrets     = @(
            @{ name='s1'; lastRotated='2025-01-01'; rotationDays=90; requiredBy=@('api') }
        )
        MustContain = @('"expired"','"s1"','"daysUntilExpiry"')
    }
)

$projectFiles = @(
    'SecretRotationValidator.ps1',
    'SecretRotationValidator.Tests.ps1',
    'Invoke-Validator.ps1'
)

$allPassed = $true
foreach ($case in $cases) {
    Write-Host "`n========== case: $($case.Name) =========="
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("srv-" + $case.Name + "-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        # Copy project files
        foreach ($f in $projectFiles) {
            Copy-Item (Join-Path $here $f) (Join-Path $tmp $f)
        }
        New-Item -ItemType Directory -Path (Join-Path $tmp '.github/workflows') -Force | Out-Null
        Copy-Item $workflow (Join-Path $tmp '.github/workflows/secret-rotation-validator.yml')
        New-Item -ItemType Directory -Path (Join-Path $tmp 'fixtures') -Force | Out-Null

        # Write this case's fixture
        @{ secrets = $case.Secrets } | ConvertTo-Json -Depth 6 |
            Set-Content -Path (Join-Path $tmp 'fixtures/secrets.json')

        # Env overrides consumed by the workflow env: block defaults
        @(
            "CONFIG_PATH=fixtures/secrets.json",
            "WARNING_DAYS=$($case.WarningDays)",
            "REPORT_FORMAT=$($case.Format)",
            "NOW_OVERRIDE=$($case.Now)"
        ) -join "`n" | Set-Content -Path (Join-Path $tmp '.env')

        # .actrc from parent (to use our pwsh image)
        if (Test-Path (Join-Path $here '.actrc')) {
            Copy-Item (Join-Path $here '.actrc') (Join-Path $tmp '.actrc')
        }

        # Init a git repo so `act push` works
        Push-Location $tmp
        try {
            & git init -q
            & git config user.email 'test@example.com'
            & git config user.name  'test'
            & git add . > $null
            & git commit -q -m 'case fixture' > $null

            Write-Host "[case:$($case.Name)] running act push --rm"
            $out = & act push --rm --pull=false --env-file .env 2>&1 | Out-String
            $exit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        Add-Content -Path $actResult -Value "`n===== CASE: $($case.Name) (exit=$exit) =====`n"
        Add-Content -Path $actResult -Value $out

        if ($exit -ne 0) {
            Write-Warning "[case:$($case.Name)] act exit=$exit"
            $allPassed = $false
            continue
        }

        $jobSuccess = ([regex]::Matches($out,'Job succeeded')).Count
        if ($jobSuccess -lt 2) {
            Write-Warning "[case:$($case.Name)] expected >=2 'Job succeeded', got $jobSuccess"
            $allPassed = $false
        } else {
            Write-Host "[case:$($case.Name)] Job succeeded x$jobSuccess"
        }

        foreach ($needle in $case.MustContain) {
            if ($out -notmatch [regex]::Escape($needle)) {
                Write-Warning "[case:$($case.Name)] missing expected output: $needle"
                $allPassed = $false
            } else {
                Write-Host "[case:$($case.Name)]   ok -> $needle"
            }
        }
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (-not $allPassed) {
    throw "One or more workflow cases failed. See $actResult"
}
Write-Host "`nAll workflow cases passed. act output at $actResult"
