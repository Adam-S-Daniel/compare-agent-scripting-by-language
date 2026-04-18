#requires -Version 7.0
<#
.SYNOPSIS
  Test harness: runs each fixture case through `act push --rm` and writes the
  per-case log files the Pester tests in tests/Workflow.Tests.ps1 assert on.

.DESCRIPTION
  For each case:
    1. Creates an isolated temp git repo
    2. Copies the project files into it
    3. git init + git add + git commit
    4. Runs `act push --rm --env FIXTURE=... --env CONFIG=...`
    5. Captures full stdout+stderr; appends ACT_EXIT_CODE=<n>
    6. Writes per-case file act-output-<name>.txt
    7. Appends the per-case content to act-result.txt (aggregate required artifact)

  On completion, invokes Pester with RUN_ACT=1 to execute the workflow tests
  that consume the staged log files.
#>
[CmdletBinding()]
param(
    [string] $RepoRoot = $PSScriptRoot
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$cases = @(
    @{ Name = 'docs-only';   Fixture = 'fixtures/case-docs-only.json'   }
    @{ Name = 'api-backend'; Fixture = 'fixtures/case-api-backend.json' }
    @{ Name = 'mixed';       Fixture = 'fixtures/case-mixed.json'       }
)

$aggregate = Join-Path $RepoRoot 'act-result.txt'
if (Test-Path -LiteralPath $aggregate) { Remove-Item -LiteralPath $aggregate -Force }

# Files/dirs to copy into each isolated temp repo.
$projectItems = @(
    'src',
    'tests',
    'fixtures',
    '.github',
    '.actrc',
    'Invoke-PRLabeler.ps1'
)

foreach ($case in $cases) {
    Write-Host "`n=== Running case: $($case.Name) ===" -ForegroundColor Cyan

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("pr-label-" + $case.Name + "-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null

    try {
        foreach ($item in $projectItems) {
            $src = Join-Path $RepoRoot $item
            if (-not (Test-Path -LiteralPath $src)) {
                throw "Project item not found: $src"
            }
            Copy-Item -LiteralPath $src -Destination $tmp -Recurse -Force
        }

        Push-Location $tmp
        try {
            & git init --quiet --initial-branch=main 2>&1 | Out-Null
            & git -c user.email=ci@example.com -c user.name=ci add --all   2>&1 | Out-Null
            & git -c user.email=ci@example.com -c user.name=ci commit --quiet -m "seed" 2>&1 | Out-Null

            Write-Host "Running: act push --rm --pull=false --env FIXTURE=$($case.Fixture)"
            # --pull=false: the act-ubuntu-pwsh:latest image is built locally, not on a registry.
            # Combine stdout+stderr; some act diagnostics print to stderr.
            $output = & act push --rm --pull=false `
                --env FIXTURE=$($case.Fixture) `
                --env CONFIG=fixtures/config.json 2>&1 |
                ForEach-Object { $_.ToString() }
            $exitCode = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }

        $caseLog = Join-Path $RepoRoot ("act-output-" + $case.Name + ".txt")
        $header = @(
            "##### CASE: $($case.Name) #####"
            "FIXTURE: $($case.Fixture)"
            "TIMESTAMP: $(Get-Date -Format o)"
            ""
        ) -join [Environment]::NewLine
        $footer = "`nACT_EXIT_CODE=$exitCode`n"

        $body = ($output -join [Environment]::NewLine)
        $record = $header + $body + $footer

        Set-Content -LiteralPath $caseLog -Value $record -Encoding utf8
        Add-Content -LiteralPath $aggregate -Value $record -Encoding utf8

        Write-Host "Case $($case.Name) exit=$exitCode; log: $caseLog"
        if ($exitCode -ne 0) {
            Write-Warning "Case $($case.Name) failed (exit $exitCode). See $caseLog"
        }
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`n=== Act runs complete. Aggregate log: $aggregate ===" -ForegroundColor Green
Write-Host "Running Pester workflow tests against captured logs..." -ForegroundColor Cyan

$env:RUN_ACT = '1'
$result = Invoke-Pester -Path (Join-Path $RepoRoot 'tests') -Output Detailed -PassThru
$env:RUN_ACT = $null

if ($result.FailedCount -gt 0) {
    throw "Pester reported $($result.FailedCount) failed test(s)."
}

Write-Host "`nAll workflow tests passed." -ForegroundColor Green
