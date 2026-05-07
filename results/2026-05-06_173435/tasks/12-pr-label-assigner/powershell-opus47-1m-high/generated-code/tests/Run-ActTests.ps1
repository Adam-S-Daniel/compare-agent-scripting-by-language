#requires -Version 7.2
<#
.SYNOPSIS
    Runs the GitHub Actions workflow under nektos/act for each fixture
    case and asserts EXACT expected labels.

.DESCRIPTION
    The harness:
      1. Computes (per case) the expected label list.
      2. Stages a temp git repo containing the project + that case's fixture
         data (and only that case's data), so the workflow's $FIXTURE_DIR is
         unambiguous.
      3. Runs `act push --rm` once per case using FIXTURE_DIR as an env var.
      4. Appends every act invocation's stdout/stderr to act-result.txt
         (delimited per case).
      5. Parses the act output, finds the LABELS-JSON block emitted by the
         workflow, and asserts equality against the expected list.
      6. Asserts that act exited 0 and that every job logged
         "Job succeeded".

    Cap at 3 act invocations per the task constraints.
#>

[CmdletBinding()]
param(
    [string] $RepoRoot   = (Split-Path -Parent $PSScriptRoot),
    [string] $ResultFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'act-result.txt')
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Reset the result file so each harness run starts clean.
Set-Content -LiteralPath $ResultFile -Value "act test harness run @ $(Get-Date -AsUTC -Format o)`n" -Encoding utf8

$cases = @(
    @{
        Name             = 'case-basic'
        ExpectedLabels   = @('api', 'tests', 'documentation')
        ExpectedExitCode = 0
    },
    @{
        Name             = 'case-no-match'
        ExpectedLabels   = @()
        ExpectedExitCode = 0
    },
    @{
        Name             = 'case-priority-conflict'
        ExpectedLabels   = @('area:api', 'area:src')
        ExpectedExitCode = 0
    }
)

function Invoke-Case {
    param(
        [hashtable] $Case,
        [string]    $RepoRoot,
        [string]    $ResultFile
    )

    Write-Host "=== Running case: $($Case.Name) ==="

    # Stage an isolated git workspace with only this fixture present, so the
    # workflow's resolution is deterministic regardless of which other
    # fixtures live in the repo.
    $workdir = Join-Path ([System.IO.Path]::GetTempPath()) ("acttest_" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $workdir | Out-Null

    try {
        # Copy project files (workflow + script + tests + just this fixture).
        Copy-Item -Path (Join-Path $RepoRoot '.github')  -Destination $workdir -Recurse -Force
        Copy-Item -Path (Join-Path $RepoRoot 'src')      -Destination $workdir -Recurse -Force
        Copy-Item -Path (Join-Path $RepoRoot 'tests')    -Destination $workdir -Recurse -Force

        $fxDest = Join-Path $workdir 'fixtures'
        New-Item -ItemType Directory -Path $fxDest | Out-Null
        Copy-Item `
            -Path (Join-Path $RepoRoot "fixtures/$($Case.Name)") `
            -Destination $fxDest `
            -Recurse -Force

        # Copy .actrc so we use the prebaked image with pwsh + Pester.
        $actrcSrc = Join-Path $RepoRoot '.actrc'
        if (Test-Path -LiteralPath $actrcSrc) {
            Copy-Item -Path $actrcSrc -Destination $workdir -Force
        }

        # Initialise the git repo so act has something to checkout.
        Push-Location $workdir
        try {
            git init -q -b main | Out-Null
            git config user.email 'harness@example.com' | Out-Null
            git config user.name  'Harness'             | Out-Null
            git add -A | Out-Null
            git commit -q -m 'fixture' | Out-Null

            # Run act. Capture combined stdout+stderr.
            $actLog = Join-Path $workdir 'act.log'
            $env:FIXTURE_DIR = $Case.Name
            # --pull=false: the runner image is built locally and not on a
            #   registry, so act's default force-pull would fail.
            # --rm: clean up containers after the run.
            $proc = Start-Process -FilePath 'act' `
                -ArgumentList @('push', '--rm', '--pull=false', '--env', "FIXTURE_DIR=$($Case.Name)") `
                -RedirectStandardOutput $actLog `
                -RedirectStandardError  "$actLog.err" `
                -NoNewWindow `
                -PassThru `
                -Wait
            $exit = $proc.ExitCode

            $stdout = if (Test-Path $actLog)        { Get-Content -Raw -LiteralPath $actLog } else { '' }
            $stderr = if (Test-Path "$actLog.err")  { Get-Content -Raw -LiteralPath "$actLog.err" } else { '' }
            $combined = $stdout + "`n" + $stderr

            # Append to the global result file with delimiters.
            Add-Content -LiteralPath $ResultFile -Value "`n========= CASE: $($Case.Name) (exit=$exit) ========="
            Add-Content -LiteralPath $ResultFile -Value $combined
            Add-Content -LiteralPath $ResultFile -Value "========= END CASE: $($Case.Name) ========="

            return [pscustomobject]@{
                Name     = $Case.Name
                Exit     = $exit
                Output   = $combined
                Expected = $Case.ExpectedLabels
                ExpectedExit = $Case.ExpectedExitCode
            }
        } finally {
            Pop-Location
        }
    } finally {
        if (Test-Path -LiteralPath $workdir) {
            Remove-Item -Recurse -Force $workdir
        }
    }
}

function Get-LabelsFromActOutput {
    param([string] $Output)

    # The workflow prints:
    #   ---LABELS-JSON-BEGIN---
    #   ["foo","bar"]
    #   ---LABELS-JSON-END---
    # act prefixes every workflow log line with its own "[..]" wrapper, so we
    # cannot match the lines as exact equality. Instead, scan for the begin
    # sentinel and grab the JSON from the next line.
    $lines  = $Output -split "`r?`n"
    $beginIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'LABELS-JSON-BEGIN') {
            $beginIdx = $i
            break
        }
    }
    if ($beginIdx -lt 0) { return $null }

    for ($j = $beginIdx + 1; $j -lt $lines.Count; $j++) {
        # act log line shape is roughly: "[Workflow/Job] | <content>"
        # The JSON we want is the rightmost segment after the last " | ".
        if ($lines[$j] -match 'LABELS-JSON-END') { break }
        $line = $lines[$j]
        $cut  = $line.LastIndexOf(' | ')
        $payload = if ($cut -ge 0) { $line.Substring($cut + 3).Trim() } else { $line.Trim() }
        if ($payload.StartsWith('[')) {
            try {
                $arr = $payload | ConvertFrom-Json
                # Use the comma operator so an empty array is returned as a
                # zero-element [object[]], not unrolled to $null. The latter
                # would make us indistinguishable from "no JSON found".
                if ($null -eq $arr) { return ,@() }
                return ,@($arr)
            } catch {
                # Not JSON on this line, keep scanning.
            }
        }
    }
    return $null
}

$results = @()
foreach ($case in $cases) {
    $results += (Invoke-Case -Case $case -RepoRoot $RepoRoot -ResultFile $ResultFile)
}

# ---- Assertions ----
$failed = @()

foreach ($r in $results) {
    Write-Host "--- Asserting $($r.Name) ---"

    if ($r.Exit -ne $r.ExpectedExit) {
        $failed += "$($r.Name): exit code $($r.Exit), expected $($r.ExpectedExit)"
        continue
    }

    # Every job in the workflow should report 'Job succeeded'.
    $succeeded = ([regex]::Matches($r.Output, 'Job succeeded')).Count
    if ($succeeded -lt 2) {
        $failed += "$($r.Name): expected at least 2 'Job succeeded' (one per job), saw $succeeded"
        continue
    }

    $labels = Get-LabelsFromActOutput -Output $r.Output
    if ($null -eq $labels) {
        $failed += "$($r.Name): could not locate labels JSON in act output"
        continue
    }

    # Compare as ordered arrays — the script guarantees ordering.
    # Empty arrays piped through ConvertTo-Json yield $null (not "[]"), so
    # short-circuit that case explicitly. Non-empty arrays are piped (the
    # -InputObject form double-wraps them).
    $labelsJson   = if ($labels.Count   -eq 0) { '[]' } else { ($labels   | ConvertTo-Json -Compress -AsArray) }
    $expectedJson = if ($r.Expected.Count -eq 0) { '[]' } else { ($r.Expected | ConvertTo-Json -Compress -AsArray) }
    if ($labelsJson -ne $expectedJson) {
        $failed += "$($r.Name): labels mismatch. expected=$expectedJson actual=$labelsJson"
        continue
    }

    Write-Host "  OK  exit=$($r.Exit) labels=$labelsJson"
}

if ($failed.Count -gt 0) {
    Write-Host ''
    Write-Host 'FAILED CASES:'
    $failed | ForEach-Object { Write-Host "  - $_" }
    throw "Act-based test harness failed: $($failed.Count) case(s) did not match expectations."
}

Write-Host ''
Write-Host "All $($results.Count) act cases passed. Combined output saved to: $ResultFile"
