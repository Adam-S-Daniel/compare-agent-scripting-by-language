# End-to-end test harness: runs the GitHub Actions workflow via `act` for several
# fixture cases, asserts exit codes and exact label output, and writes the full
# act log to act-result.txt.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$actResult = Join-Path $root 'act-result.txt'
Remove-Item -LiteralPath $actResult -ErrorAction SilentlyContinue
New-Item -ItemType File -Path $actResult | Out-Null

function Invoke-ActCase {
    param(
        [Parameter(Mandatory)][string]$CaseName,
        [Parameter(Mandatory)][string]$FilesFixture,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ExpectedLabels
    )

    Write-Host "=== Running case: $CaseName ==="

    # Set up a temp git repo containing project files + the case's fixture as
    # the canonical changed-files.txt.
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("prlabel-act-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        Copy-Item -Path (Join-Path $root 'Assign-PrLabels.ps1')       -Destination $tmp
        Copy-Item -Path (Join-Path $root 'Assign-PrLabels.Tests.ps1') -Destination $tmp
        Copy-Item -Path (Join-Path $root '.github')                   -Destination $tmp -Recurse
        Copy-Item -Path (Join-Path $root '.actrc')                    -Destination $tmp
        Copy-Item -Path (Join-Path $root 'fixtures')                  -Destination $tmp -Recurse

        # Overwrite changed-files.txt with this case's fixture.
        Copy-Item -Path (Join-Path $root "fixtures/$FilesFixture") `
                  -Destination (Join-Path $tmp 'fixtures/changed-files.txt') -Force

        Push-Location $tmp
        try {
            git init --quiet
            git -c user.name=test -c user.email=t@t config commit.gpgsign false
            git add -A
            git -c user.name=test -c user.email=t@t commit -q -m "case $CaseName"

            $out = & act push --rm --pull=false 2>&1
            $exit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        $header  = "===== CASE: $CaseName (files=$FilesFixture, exit=$exit) ====="
        $footer  = "===== END CASE: $CaseName ====="
        Add-Content -LiteralPath $actResult -Value $header
        Add-Content -LiteralPath $actResult -Value ($out -join [Environment]::NewLine)
        Add-Content -LiteralPath $actResult -Value $footer

        if ($exit -ne 0) { throw "act exited with $exit for case $CaseName" }

        $text = ($out -join "`n")

        if ($text -notmatch 'Job succeeded' -or
            ($text | Select-String -Pattern 'Job succeeded' -AllMatches).Matches.Count -lt 2) {
            throw "Expected both jobs to show 'Job succeeded' for case $CaseName"
        }

        # Extract the labels block emitted by the workflow between markers.
        $startIdx = $text.IndexOf('LABELS_START')
        $endIdx   = $text.IndexOf('LABELS_END')
        if ($startIdx -lt 0 -or $endIdx -lt 0) {
            throw "Could not find LABELS_START/LABELS_END markers for case $CaseName"
        }
        $block = $text.Substring($startIdx + 'LABELS_START'.Length, $endIdx - $startIdx - 'LABELS_START'.Length)

        # act prefixes log lines with "[workflow name/job]"; strip the prefix.
        $labels = $block -split "`n" |
            ForEach-Object {
                ($_ -replace '^\[[^\]]*\]\s*', '').Trim()
            } |
            Where-Object { $_ -and $_ -ne '| ' -and $_ -notmatch '^\|\s*$' } |
            ForEach-Object { $_ -replace '^\|\s*', '' } |
            Where-Object { $_ -ne '' }

        $labelsStr   = ($labels          | ForEach-Object { $_ }) -join ','
        $expectedStr = ($ExpectedLabels  | ForEach-Object { $_ }) -join ','
        if ($labelsStr -ne $expectedStr) {
            throw ("Case {0}: expected labels [{1}] got [{2}]" -f $CaseName, $expectedStr, $labelsStr)
        }

        Write-Host "  PASS: labels = [$labelsStr]"
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Workflow structure tests (run before act to fail fast).
Write-Host "=== Workflow structure tests ==="
$wfPath = Join-Path $root '.github/workflows/pr-label-assigner.yml'
if (-not (Test-Path $wfPath)) { throw 'Workflow file missing' }

& actionlint $wfPath
if ($LASTEXITCODE -ne 0) { throw "actionlint failed with $LASTEXITCODE" }
Write-Host '  actionlint: OK'

$wfText = Get-Content -LiteralPath $wfPath -Raw
foreach ($needle in @('actions/checkout@v4','Assign-PrLabels.ps1','Assign-PrLabels.Tests.ps1','workflow_dispatch','jobs:','needs: test')) {
    if ($wfText -notmatch [regex]::Escape($needle)) { throw "Workflow missing expected content: $needle" }
}
Write-Host '  structure: OK'

foreach ($f in @('Assign-PrLabels.ps1','Assign-PrLabels.Tests.ps1','fixtures/rules.json','fixtures/changed-files.txt')) {
    if (-not (Test-Path (Join-Path $root $f))) { throw "Missing referenced file: $f" }
}
Write-Host '  referenced files exist: OK'

# Run the three act cases.
Invoke-ActCase -CaseName 'full'      -FilesFixture 'case-full.txt' `
    -ExpectedLabels @('tests','api','backend','frontend','documentation')

Invoke-ActCase -CaseName 'docs-only' -FilesFixture 'case-docs-only.txt' `
    -ExpectedLabels @('documentation')

Invoke-ActCase -CaseName 'no-match'  -FilesFixture 'case-no-match.txt' `
    -ExpectedLabels ([string[]]@())

Write-Host ''
Write-Host 'All act-based cases passed.'
Write-Host "Full act log: $actResult"
