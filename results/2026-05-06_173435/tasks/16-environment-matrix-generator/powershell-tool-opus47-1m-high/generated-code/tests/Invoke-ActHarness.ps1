#requires -Version 7.0
<#
    Invoke-ActHarness
    -----------------
    Runs the environment-matrix-generator workflow through `act` for a small set
    of test fixtures and asserts on EXACT expected output values.

    Per task constraints we keep act runs to a minimum (<= 3 total). Each run:
      1. Sets up an isolated temp git repo with all project files PLUS the case's
         fixture file copied to the workflow's expected default path.
      2. Runs `act push --rm` and captures stdout+stderr.
      3. Appends the run's output to <project-root>/act-result.txt with a clear
         delimiter header so the file is readable as a single artifact.
      4. Asserts that act exited 0 and that every job line shows "Job succeeded".
      5. Parses the matrix JSON from the captured output and asserts EXACT
         equality with the expected JSON for that fixture.

    The harness throws on first failure so CI surfaces the problem immediately.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ResultPath  = (Join-Path (Split-Path -Parent $PSScriptRoot) 'act-result.txt')
)

$ErrorActionPreference = 'Stop'

# Reset / create the act-result.txt artifact.
"act harness run started: $(Get-Date -AsUTC -Format o)" | Set-Content -LiteralPath $ResultPath -Encoding utf8

# ---------------------------------------------------------------------------
# Test cases. Each case names a fixture file that is already part of the repo.
# The "expected" property is the parsed object we compare the generated matrix
# against using deep-equality. Keeping expectations as objects (not strings)
# means we don't depend on key ordering or whitespace from ConvertTo-Json.
# ---------------------------------------------------------------------------
$cases = @(
    [pscustomobject]@{
        Name        = 'basic'
        FixturePath = 'fixtures/basic.json'
        Expected    = [pscustomobject]@{
            'fail-fast'    = $false
            'max-parallel' = 2
            'size'         = 4
            'matrix'       = [pscustomobject]@{
                'include' = @(
                    [pscustomobject]@{ os = 'ubuntu-latest';  node = 18 }
                    [pscustomobject]@{ os = 'ubuntu-latest';  node = 20 }
                    [pscustomobject]@{ os = 'windows-latest'; node = 18 }
                    [pscustomobject]@{ os = 'windows-latest'; node = 20 }
                )
            }
        }
    }
    [pscustomobject]@{
        Name        = 'include-exclude'
        FixturePath = 'fixtures/include-exclude.json'
        Expected    = [pscustomobject]@{
            'fail-fast'    = $true
            'max-parallel' = 4
            'size'         = 5
            'matrix'       = [pscustomobject]@{
                'include' = @(
                    [pscustomobject]@{ os = 'ubuntu-latest';  node = 18 }
                    [pscustomobject]@{ os = 'ubuntu-latest';  node = 20; experimental = $true }
                    [pscustomobject]@{ os = 'windows-latest'; node = 20 }
                    [pscustomobject]@{ os = 'macos-latest';   node = 20 }
                    [pscustomobject]@{ os = 'ubuntu-latest';  node = 22 }
                )
            }
        }
    }
)

function Compare-DeepEqual {
    <#
        Recursive structural-equality test for the JSON-shaped objects we expect
        from ConvertFrom-Json. We treat arrays element-wise (order-sensitive) and
        objects by full key set + deep-equal of every value. Scalars compare via
        string coercion so that PowerShell's JSON int/long subtleties don't trip us.
    #>
    param([Parameter(Mandatory)]$Expected, [Parameter(Mandatory)]$Actual, [string]$Path = '$')

    if ($null -eq $Expected -and $null -eq $Actual) { return $true }
    if ($null -eq $Expected -xor $null -eq $Actual) {
        Write-Host "DIFF at $Path : null mismatch (expected=$Expected, actual=$Actual)"
        return $false
    }

    if ($Expected -is [System.Collections.IEnumerable] -and $Expected -isnot [string]) {
        $expArr = @($Expected); $actArr = @($Actual)
        if ($expArr.Count -ne $actArr.Count) {
            Write-Host "DIFF at $Path : array length expected=$($expArr.Count), actual=$($actArr.Count)"
            return $false
        }
        for ($i = 0; $i -lt $expArr.Count; $i++) {
            if (-not (Compare-DeepEqual -Expected $expArr[$i] -Actual $actArr[$i] -Path "$Path[$i]")) { return $false }
        }
        return $true
    }

    if ($Expected -is [pscustomobject]) {
        $expProps = $Expected.PSObject.Properties.Name | Sort-Object
        $actProps = $Actual.PSObject.Properties.Name   | Sort-Object
        if (($expProps -join ',') -ne ($actProps -join ',')) {
            Write-Host "DIFF at $Path : key set expected=[$($expProps -join ',')] actual=[$($actProps -join ',')]"
            return $false
        }
        foreach ($p in $expProps) {
            if (-not (Compare-DeepEqual -Expected $Expected.$p -Actual $Actual.$p -Path "$Path.$p")) { return $false }
        }
        return $true
    }

    # Scalar
    if ("$Expected" -ne "$Actual") {
        Write-Host "DIFF at $Path : expected='$Expected' actual='$Actual'"
        return $false
    }
    return $true
}

function Invoke-ActOnce {
    <#
        Sets up a fresh temp git repo containing the project files + the case's
        fixture mounted at fixtures/basic.json (the workflow's default), then
        runs `act push --rm` once, capturing combined stdout+stderr.
    #>
    param([Parameter(Mandatory)]$Case)

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("act-mxgen-" + [guid]::NewGuid().ToString('N'))
    Write-Host "[$($Case.Name)] Building temp repo at $tempDir"
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    # Copy project files except .git/.actrc cruft we'll set up explicitly.
    $copyItems = @('src', 'tests', 'fixtures', '.github', '.actrc')
    foreach ($item in $copyItems) {
        $src = Join-Path $ProjectRoot $item
        if (Test-Path -LiteralPath $src) {
            Copy-Item -Recurse -Force -LiteralPath $src -Destination (Join-Path $tempDir $item)
        }
    }

    # Replace fixtures/basic.json (the workflow's default fixture) with this case's content.
    Copy-Item -Force -LiteralPath (Join-Path $ProjectRoot $Case.FixturePath) -Destination (Join-Path $tempDir 'fixtures/basic.json')

    # Initialize git repo (act expects a git context).
    Push-Location $tempDir
    try {
        git init -q -b master
        git -c user.email=harness@local -c user.name=harness add -A
        git -c user.email=harness@local -c user.name=harness commit -q -m "fixture: $($Case.Name)"

        Write-Host "[$($Case.Name)] Running: act push --rm --pull=false"
        # --pull=false: the act image is built locally (act-ubuntu-pwsh:latest) and not
        # available in any registry; act's default forcePull would error trying to fetch it.
        # Use combined output so we capture step logs and final job status together.
        $output = & act push --rm --pull=false 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
        Remove-Item -Recurse -Force -LiteralPath $tempDir -ErrorAction SilentlyContinue
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = ($output -join "`n")
    }
}

function Read-MatrixFromOutput {
    <#
        Pulls the matrix JSON from the captured act output. The workflow emits
        the matrix between BEGIN/END MATRIX delimiters via Invoke-MatrixGenerator,
        and also re-prints the GitHub-Actions output JSON in the summary job.
        We extract the first BEGIN MATRIX block.
    #>
    param([Parameter(Mandatory)][string]$Output)

    $lines = $Output -split "`r?`n"
    $start = -1; $end = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($start -lt 0 -and $lines[$i] -match 'BEGIN MATRIX') { $start = $i; continue }
        if ($start -ge 0 -and $lines[$i] -match 'END MATRIX')   { $end   = $i; break }
    }
    if ($start -lt 0 -or $end -le $start) {
        throw "Could not find BEGIN/END MATRIX block in act output."
    }
    # Strip act's "[Workflow/Job] | " prefix from each line if present.
    $body = $lines[($start + 1)..($end - 1)] | ForEach-Object {
        $_ -replace '^\[[^\]]+\]\s*\|\s*', ''
    }
    return ($body -join "`n").Trim()
}

# ---------------------------------------------------------------------------
# Drive the test cases.
# ---------------------------------------------------------------------------
$failures = @()

foreach ($case in $cases) {
    Write-Host ""
    Write-Host "==========  CASE: $($case.Name)  =========="
    "`n========================================" | Add-Content -LiteralPath $ResultPath
    "CASE: $($case.Name) ($($case.FixturePath))" | Add-Content -LiteralPath $ResultPath
    "========================================" | Add-Content -LiteralPath $ResultPath

    $run = Invoke-ActOnce -Case $case
    $run.Output | Add-Content -LiteralPath $ResultPath
    "[exit=$($run.ExitCode)]" | Add-Content -LiteralPath $ResultPath

    if ($run.ExitCode -ne 0) {
        $failures += "Case $($case.Name): act exited with $($run.ExitCode)"
        continue
    }

    # All jobs must report "Job succeeded".
    $jobSucceededCount = ([regex]::Matches($run.Output, 'Job succeeded')).Count
    if ($jobSucceededCount -lt 3) {
        $failures += "Case $($case.Name): expected >=3 'Job succeeded' lines, found $jobSucceededCount"
        continue
    }

    # Extract and structurally compare matrix JSON.
    try {
        $matrixJson = Read-MatrixFromOutput -Output $run.Output
    } catch {
        $failures += "Case $($case.Name): $_"; continue
    }
    $actual = $matrixJson | ConvertFrom-Json
    if (-not (Compare-DeepEqual -Expected $case.Expected -Actual $actual)) {
        $failures += "Case $($case.Name): matrix did not match expected"
        Write-Host "Actual JSON: $matrixJson"
        continue
    }
    Write-Host "[$($case.Name)] OK — exit=0, jobs succeeded=$jobSucceededCount, matrix matches expected"
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILURES:"
    $failures | ForEach-Object { Write-Host "  - $_" }
    "`nFAILURES:`n$($failures -join "`n")" | Add-Content -LiteralPath $ResultPath
    exit 1
}

Write-Host ""
Write-Host "All $($cases.Count) act-driven test cases passed."
"`nAll $($cases.Count) act-driven test cases passed." | Add-Content -LiteralPath $ResultPath
exit 0
