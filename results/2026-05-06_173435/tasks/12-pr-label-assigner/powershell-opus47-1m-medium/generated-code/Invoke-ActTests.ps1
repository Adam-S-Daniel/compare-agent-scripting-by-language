# act-driven test harness.
#
# For each test case: stage the project + fixture data into a temp git repo,
# run `act push --rm` there, capture output to act-result.txt, then assert:
#   - act exit code 0
#   - "Job succeeded" appears
#   - workflow's LABELS_JSON line matches the case's expected label set exactly.
#
# Limited to <= 3 act runs total per task constraints.

[CmdletBinding()]
param(
    [string]$ResultFile = (Join-Path $PSScriptRoot 'act-result.txt')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Reset the result file up front so we always emit a fresh artifact.
Set-Content -LiteralPath $ResultFile -Value "act test run @ $(Get-Date -Format o)`n"

# Files that make up the project, copied into each scratch repo.
$projectFiles = @(
    '.github/workflows/pr-label-assigner.yml',
    'PrLabelAssigner.ps1',
    'PrLabelAssigner.Tests.ps1',
    'Run-Assigner.ps1',
    'fixtures/rules.json'
)

$cases = @(
    @{
        Name     = 'docs-only'
        Files    = @('docs/readme.md')
        # Only docs/** matches docs/readme.md.
        Expected = @('documentation')
    }
    @{
        Name     = 'mixed'
        Files    = @('src/api/users.ps1', 'docs/x.md', 'src/api/users.test.ps1')
        # api(10) + documentation(5) + powershell(3) + tests(1), ordered by priority desc.
        Expected = @('api','documentation','powershell','tests')
    }
    @{
        Name     = 'no-match'
        Files    = @('LICENSE', 'README.md')
        # Nothing matches the default rule set.
        Expected = @()
    }
)

function Write-Section($Title) {
    $line = ('=' * 70)
    Add-Content -LiteralPath $ResultFile -Value "`n$line`n$Title`n$line"
}

$failures = 0

foreach ($case in $cases) {
    Write-Host "=== act case: $($case.Name) ==="
    $work = Join-Path ([System.IO.Path]::GetTempPath()) ("pr-label-act-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    try {
        # Stage project files into the scratch repo.
        foreach ($rel in $projectFiles) {
            $src = Join-Path $PSScriptRoot $rel
            $dst = Join-Path $work $rel
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
            Copy-Item -LiteralPath $src -Destination $dst
        }
        # Stage this case's fixture file list.
        $caseFiles = Join-Path $work 'fixtures/files.json'
        ($case.Files | ConvertTo-Json) | Set-Content -LiteralPath $caseFiles
        # .actrc tells act which image to use; copy it too.
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot '.actrc') -Destination (Join-Path $work '.actrc')

        # act needs a git repo to run push events.
        Push-Location $work
        try {
            git init -q
            git -c user.email=t@t -c user.name=t add -A
            git -c user.email=t@t -c user.name=t commit -q -m init

            # --pull=false: the act-ubuntu-pwsh image is built locally and not in any registry.
            $output = & act push --rm --pull=false 2>&1 | Out-String
            $exit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        Write-Section "CASE: $($case.Name)  (exit=$exit)"
        Add-Content -LiteralPath $ResultFile -Value $output

        # ---- Assertions ------------------------------------------------------
        $caseFailed = $false
        if ($exit -ne 0) {
            Write-Host "  FAIL: act exit=$exit"
            $caseFailed = $true
        }
        if ($output -notmatch 'Job succeeded') {
            Write-Host "  FAIL: 'Job succeeded' not found"
            $caseFailed = $true
        }
        # Pull the LABELS_JSON line emitted by Run-Assigner.ps1.
        $labelLine = ($output -split "`n") | Where-Object { $_ -match 'LABELS_JSON=' } | Select-Object -Last 1
        if (-not $labelLine) {
            Write-Host "  FAIL: no LABELS_JSON line in output"
            $caseFailed = $true
        } else {
            $jsonText = ($labelLine -replace '.*LABELS_JSON=', '').Trim()
            $parsed   = @($jsonText | ConvertFrom-Json)
            $expected = @($case.Expected)
            $match = ($parsed.Count -eq $expected.Count) -and
                     (-not (Compare-Object $parsed $expected -SyncWindow 0))
            if (-not $match) {
                Write-Host "  FAIL: labels mismatch. expected=$($expected -join ',') got=$($parsed -join ',')"
                $caseFailed = $true
            } else {
                Write-Host "  OK: labels=[$($parsed -join ',')]"
            }
        }
        Add-Content -LiteralPath $ResultFile -Value (
            "ASSERT case=$($case.Name) result=$([bool](-not $caseFailed)) expected=$(($case.Expected | ConvertTo-Json -Compress))"
        )
        if ($caseFailed) { $failures++ }
    }
    finally {
        Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
    }
}

Write-Section "SUMMARY: failures=$failures of $($cases.Count)"
if ($failures -gt 0) {
    throw "act test harness: $failures of $($cases.Count) cases failed"
}
Write-Host "All $($cases.Count) act cases passed."
