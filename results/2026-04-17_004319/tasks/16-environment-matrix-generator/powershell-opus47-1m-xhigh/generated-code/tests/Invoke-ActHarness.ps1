#!/usr/bin/env pwsh
<#
.SYNOPSIS
Run the environment-matrix-generator workflow through `act` and assert every
fixture produces its expected output.

.DESCRIPTION
This harness is the full integration test. It does not test the generator
directly — all assertions are made against output captured from a real
GitHub Actions workflow run inside act/Docker.

Flow:
  1. Prepare a fresh temp git repo containing a copy of the project files.
     (act requires .git to discover the current SHA; copying avoids polluting
     the working tree.)
  2. Run `act push --rm` ONCE. The workflow iterates every fixture in
     fixtures/ and emits delimited blocks per fixture.
  3. Append the full act output to act-result.txt in the repo root.
  4. Parse per-fixture blocks and assert EXACT expected values:
       - HTTP: size, max-parallel, fail-fast, include entries
       - error cases: exact error message
  5. Assert every job shows "Job succeeded".
  6. Assert act exited with code 0.

Exit 0 on success, 1 on any assertion failure.
#>

param(
    # Leave set by default so developers can inspect the temp workdir after a
    # failure. CI/automation should pass -Cleanup.
    [switch] $Cleanup
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# --- Paths and constants ------------------------------------------------

$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:ResultFile  = Join-Path $script:ProjectRoot 'act-result.txt'

# --- Expected outcomes per fixture --------------------------------------
#
# Each entry names a fixture (without .json) and the concrete values the
# harness expects the workflow to emit. This is the "known-good result" side
# of the contract: if the generator ever changes output, these must change
# too and the change shows up in diffs.

$script:Expected = @(
    @{
        Name   = '01-basic'
        Status = 'ok'
        Size   = 4
        MaxParallel = 4
        FailFast = $true
        IncludeEntries = @(
            @{ os = 'ubuntu-latest';  node = '18' }
            @{ os = 'ubuntu-latest';  node = '20' }
            @{ os = 'windows-latest'; node = '18' }
            @{ os = 'windows-latest'; node = '20' }
        )
    }
    @{
        Name   = '02-exclude'
        Status = 'ok'
        Size   = 7
        MaxParallel = 6
        FailFast = $false
        # 3x3 = 9 combinations, minus 2 excludes = 7.
        AbsentEntries = @(
            @{ os = 'windows-latest'; node = '18' }
            @{ os = 'macos-latest';   node = '22' }
        )
    }
    @{
        Name   = '03-include'
        Status = 'ok'
        Size   = 3
        FailFast = $true
        MaxParallelAbsent = $true
        IncludeEntries = @(
            @{ os = 'ubuntu-latest';  node = '20' }
            @{ os = 'macos-latest';   node = '20'; experimental = $true }
            @{ os = 'windows-latest'; node = '22'; experimental = $true }
        )
    }
    @{
        Name   = '04-features'
        Status = 'ok'
        Size   = 4
        MaxParallel = 3
        FailFast = $false
    }
    @{
        Name   = '05-oversize-error'
        Status = 'error'
        ErrorSubstring = 'Matrix size 12 exceeds maximum size 6'
    }
)

# --- Temp workdir setup -------------------------------------------------

function New-TempWorkdir {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "act-harness-$(New-Guid)"
    New-Item -ItemType Directory -Path $tmp | Out-Null

    # Copy project files except .git, node_modules, act-result.txt, and any
    # previous harness scratch dirs.
    $excludePatterns = @('.git', 'act-result.txt', '.vscode', 'node_modules')
    Get-ChildItem -LiteralPath $script:ProjectRoot -Force |
        Where-Object { $excludePatterns -notcontains $_.Name } |
        ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $tmp -Recurse -Force
        }

    # act requires a git repo; create a fresh one with one commit.
    Push-Location $tmp
    try {
        git init -q -b main
        git config user.email 'harness@example.com'
        git config user.name  'harness'
        git add -A
        git commit -q -m 'harness: initial commit'
    } finally {
        Pop-Location
    }

    return $tmp
}

function Remove-TempWorkdir {
    param([string] $Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- Output parsing -----------------------------------------------------

function Get-FixtureBlock {
    <#
    Extracts the per-fixture block between ==BEGIN-FIXTURE==<name> and
    ==END-FIXTURE==<name>, and pulls out the status and the output body.

    Returns @{ Status = 'ok'|'error'; Output = '<body>'; Found = $true|$false }
    #>
    param(
        [Parameter(Mandatory)][string] $ActLog,
        [Parameter(Mandatory)][string] $FixtureName
    )

    # act prefixes every forwarded stdout line with '|' + whitespace. We
    # normalize those prefixes before regex-matching so our anchors line up.
    $stripped = ($ActLog -split "`n" | ForEach-Object {
        # Match lines like '[Job Name]   |   content' produced by act.
        if ($_ -match '^\[.+?\]\s*\|\s?(.*)$') { $Matches[1] } else { $_ }
    }) -join "`n"

    $pattern = "==BEGIN-FIXTURE==$([regex]::Escape($FixtureName))\s*\n(?<body>.*?)\n==END-FIXTURE==$([regex]::Escape($FixtureName))"
    $m = [regex]::Match($stripped, $pattern, 'Singleline')
    if (-not $m.Success) {
        return @{ Found = $false; Status = $null; Output = '' }
    }

    $body = $m.Groups['body'].Value

    $status = 'unknown'
    if ($body -match 'STATUS=(\w+)') { $status = $Matches[1] }

    $outputBody = ''
    $outMatch = [regex]::Match($body, '---OUTPUT---\s*\n(?<o>.*?)\n---OUTPUT-END---', 'Singleline')
    if ($outMatch.Success) { $outputBody = $outMatch.Groups['o'].Value }

    return @{ Found = $true; Status = $status; Output = $outputBody }
}

# --- Assertions ---------------------------------------------------------

$script:Failures = [System.Collections.Generic.List[string]]::new()

function Assert-Equal {
    param($Actual, $Expected, [string] $Message)
    if ($Actual -ne $Expected) {
        $script:Failures.Add("ASSERT FAIL: $Message (expected=$Expected, actual=$Actual)") | Out-Null
    }
}

function Assert-Contains {
    param([string] $Haystack, [string] $Needle, [string] $Message)
    if ($Haystack -notlike "*$Needle*") {
        $script:Failures.Add("ASSERT FAIL: $Message (missing '$Needle')") | Out-Null
    }
}

function Test-FixtureOk {
    param($Block, $Expected)

    Assert-Equal $Block.Status 'ok' "$($Expected.Name): STATUS=ok"

    # Parse the emitted JSON and run structural assertions on it.
    $parsed = $null
    try { $parsed = $Block.Output | ConvertFrom-Json -AsHashtable } catch {
        $script:Failures.Add("$($Expected.Name): JSON parse failed: $($_.Exception.Message)") | Out-Null
        return
    }

    Assert-Equal $parsed.size $Expected.Size "$($Expected.Name): size"

    if ($Expected.ContainsKey('MaxParallel')) {
        Assert-Equal $parsed.'max-parallel' $Expected.MaxParallel "$($Expected.Name): max-parallel"
    }
    if ($Expected.ContainsKey('MaxParallelAbsent') -and $Expected.MaxParallelAbsent) {
        if ($parsed.Contains('max-parallel')) {
            $script:Failures.Add("$($Expected.Name): expected max-parallel to be omitted") | Out-Null
        }
    }
    if ($Expected.ContainsKey('FailFast')) {
        Assert-Equal $parsed.'fail-fast' $Expected.FailFast "$($Expected.Name): fail-fast"
    }

    if ($Expected.ContainsKey('IncludeEntries')) {
        $includes = @($parsed.matrix.include)
        foreach ($expected in $Expected.IncludeEntries) {
            $matches = $includes | Where-Object {
                $row = $_
                $ok = $true
                foreach ($k in $expected.Keys) {
                    if (-not $row.Contains($k)) { $ok = $false; break }
                    if ($row[$k] -ne $expected[$k]) { $ok = $false; break }
                }
                $ok
            }
            $matchCount = @($matches).Count
            if ($matchCount -ne 1) {
                $desc = ($expected.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
                $script:Failures.Add("$($Expected.Name): expected exactly 1 include entry with $desc, found $matchCount") | Out-Null
            }
        }
    }

    if ($Expected.ContainsKey('AbsentEntries')) {
        $includes = @($parsed.matrix.include)
        foreach ($absent in $Expected.AbsentEntries) {
            $matches = $includes | Where-Object {
                $row = $_
                $ok = $true
                foreach ($k in $absent.Keys) {
                    if (-not $row.Contains($k)) { $ok = $false; break }
                    if ($row[$k] -ne $absent[$k]) { $ok = $false; break }
                }
                $ok
            }
            if (@($matches).Count -ne 0) {
                $desc = ($absent.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
                $script:Failures.Add("$($Expected.Name): unexpected include entry present ($desc)") | Out-Null
            }
        }
    }
}

function Test-FixtureError {
    param($Block, $Expected)
    Assert-Equal $Block.Status 'error' "$($Expected.Name): STATUS=error"
    Assert-Contains $Block.Output $Expected.ErrorSubstring "$($Expected.Name): error message"
}

# --- Main ---------------------------------------------------------------

Write-Host '=== Invoke-ActHarness starting ==='

# Sanity: act and docker available.
foreach ($cmd in @('act', 'docker', 'git')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "Required command not found on PATH: $cmd"
    }
}

$workdir = New-TempWorkdir
Write-Host "Workdir: $workdir"

$actLog = $null
$actExit = -1

try {
    Push-Location $workdir
    try {
        # Run once. All fixtures are iterated inside the workflow step.
        # --pull=false forces act to use the locally-built act-ubuntu-pwsh
        # image (declared via .actrc) rather than trying to fetch it from a
        # registry that doesn't exist.
        Write-Host 'Running: act push --rm --pull=false'
        $actLog = & act push --rm --pull=false 2>&1 | Out-String
        $actExit = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    # Persist the act output as the required artifact.
    $delim = ('=' * 72)
    $header = @(
        $delim
        "act-harness run at $(Get-Date -Format o)"
        "workflow: environment-matrix-generator.yml"
        "act exit code: $actExit"
        $delim
    ) -join "`n"
    Add-Content -LiteralPath $script:ResultFile -Value ($header + "`n" + $actLog + "`n")
    Write-Host "Appended act output to $script:ResultFile"
}
finally {
    if ($Cleanup) { Remove-TempWorkdir -Path $workdir }
}

# Assert act exit code.
Assert-Equal $actExit 0 'act process exit code'

# Assert every job reports success (act echoes `✔ Job succeeded` for the
# default emoji formatter; fall back to plain text if emoji formatting is
# disabled).
$jobSuccessCount = ([regex]::Matches($actLog, 'Job succeeded')).Count
if ($jobSuccessCount -lt 2) {
    $script:Failures.Add("Expected at least 2 'Job succeeded' markers (test + generate), found $jobSuccessCount") | Out-Null
}

# Per-fixture assertions.
foreach ($exp in $script:Expected) {
    $block = Get-FixtureBlock -ActLog $actLog -FixtureName $exp.Name
    if (-not $block.Found) {
        $script:Failures.Add("$($exp.Name): fixture block not found in act output") | Out-Null
        continue
    }
    if ($exp.Status -eq 'ok') {
        Test-FixtureOk -Block $block -Expected $exp
    } else {
        Test-FixtureError -Block $block -Expected $exp
    }
}

if ($script:Failures.Count -gt 0) {
    Write-Host ''
    Write-Host '=== FAILURES ==='
    foreach ($f in $script:Failures) { Write-Host "  - $f" }
    Write-Host "Workdir retained at: $workdir"
    exit 1
}

Write-Host ''
Write-Host '=== SUCCESS: all fixture assertions passed ==='
exit 0
