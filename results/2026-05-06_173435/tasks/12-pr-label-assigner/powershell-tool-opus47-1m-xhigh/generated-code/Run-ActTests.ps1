<#
.SYNOPSIS
  Drives every test case through the GitHub Actions workflow via `act`.

.DESCRIPTION
  For each test case below the harness:

    1. Creates a fresh temp directory and copies the project files into it.
    2. Writes the case's fixture (the simulated changed-file list) to
       fixtures/changed-files.txt and the expected labels (in order) to
       fixtures/expected-labels.txt.
    3. Initializes a throwaway git repo, commits, and runs `act push --rm`.
    4. Appends the full act stdout/stderr to act-result.txt with a clearly
       delimited header.
    5. Asserts:
         - act exited with code 0
         - every job in the run shows "Job succeeded"
         - the LABELS_BEGIN/LABELS_END frame in the output matches the
           case's expected labels exactly (in order)
         - the assert step inside the workflow printed
           ASSERTION_PASSED (i.e. the in-workflow assertion also fired)

  In addition the harness performs WORKFLOW STRUCTURE TESTS that don't
  require running act:

    - actionlint exits 0 on the workflow file
    - the workflow's referenced script files all exist
    - the parsed YAML has the expected triggers, jobs, steps shape

  Limit: the harness aims for one act invocation per test case. The task
  budget cap of "<=3 act push runs" applies to one-off debugging runs;
  the act-result.txt artifact is the canonical test output and contains
  one section per case.
#>

[CmdletBinding()]
param(
    # Path to act-result.txt (will be overwritten/created).
    [string]$ResultFile = (Join-Path $PSScriptRoot 'act-result.txt'),

    # If supplied, only run the named test cases (matches by Name).
    [string[]]$Only,

    # Stop on the first failure instead of running all cases.
    [switch]$FailFast
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------
# Test cases
# --------------------------------------------------------------------------
# Every case lists the simulated changed-file paths and the EXACT labels we
# expect (in priority/order). The workflow asserts this in-pipeline; the
# harness re-asserts on the captured output as a defense-in-depth check.
$cases = @(
    @{
        Name           = 'docs-only'
        ChangedFiles   = @('docs/intro.md', 'docs/sub/page.md')
        ExpectedLabels = @('documentation')
    },
    @{
        Name           = 'api-and-tests'
        ChangedFiles   = @(
            'src/api/UserController.cs',
            'src/api/UserController.test.cs',
            'src/api/Helpers.cs'
        )
        # api/backend (priority 50) -> tests (30) -> csharp (20).
        # api appears before backend because src/api/** lists them in that order.
        ExpectedLabels = @('api', 'backend', 'tests', 'csharp')
    },
    @{
        Name           = 'frontend-only'
        ChangedFiles   = @('src/web/index.html', 'src/web/app.js')
        ExpectedLabels = @('frontend')
    },
    @{
        Name           = 'workflow-and-script-changes'
        ChangedFiles   = @(
            '.github/workflows/ci.yml',
            'tools/build.ps1',
            'lib/Helpers.psm1'
        )
        # ci (60) -> powershell (20). README/docs/api/web all unmatched here.
        ExpectedLabels = @('ci', 'powershell')
    },
    @{
        Name           = 'no-matches'
        ChangedFiles   = @('LICENSE', 'CHANGELOG')
        ExpectedLabels = @()
    },
    @{
        Name           = 'mixed-readme-and-docs'
        ChangedFiles   = @('README.md', 'docs/intro.md', 'src/web/app.js')
        # documentation (10), frontend (40). frontend has higher priority
        # so it must appear first.
        ExpectedLabels = @('frontend', 'documentation')
    }
)

if ($Only) {
    $cases = $cases | Where-Object { $_.Name -in $Only }
    if (-not $cases -or $cases.Count -eq 0) {
        throw "No test cases matched -Only $($Only -join ',')"
    }
}

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

function Initialize-WorkRepo {
    param(
        [Parameter(Mandatory)] [string]$Source,
        [Parameter(Mandatory)] [string]$Dest,
        [Parameter(Mandatory)] [string[]]$Fixture,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]]$Expected
    )

    # Copy the curated set of project files into a clean temp repo. We
    # deliberately do not copy ourselves (Run-ActTests.ps1) or the result
    # file - those are not consumed by the workflow.
    $items = @(
        'Get-PrLabels.psm1',
        'Get-PrLabels.Tests.ps1',
        'Invoke-PrLabelAssigner.ps1',
        'labels.json',
        '.actrc',
        '.github',
        'fixtures'
    )
    foreach ($item in $items) {
        $src = Join-Path $Source $item
        if (Test-Path -LiteralPath $src) {
            Copy-Item -LiteralPath $src -Destination $Dest -Recurse -Force
        }
    }

    # Overwrite the fixture and write the expected-labels assertion file.
    $fixturePath  = Join-Path $Dest 'fixtures/changed-files.txt'
    $expectedPath = Join-Path $Dest 'fixtures/expected-labels.txt'

    Set-Content -LiteralPath $fixturePath -Value ($Fixture -join "`n")
    if ($Expected.Count -eq 0) {
        # Empty file (no header) - the workflow treats absent or empty as
        # "no expected labels", so we do still write it with a comment so
        # the assertion fires and confirms the empty result.
        Set-Content -LiteralPath $expectedPath -Value "# no labels expected`n"
    }
    else {
        Set-Content -LiteralPath $expectedPath -Value ($Expected -join "`n")
    }

    # Initialize a one-commit git history so `act push` has something to
    # diff against. We disable signing/hooks because the temp repo has no
    # config and may run inside CI sandboxes.
    Push-Location $Dest
    try {
        git init -q 2>&1 | Out-Null
        git config user.email 'harness@example.com' | Out-Null
        git config user.name  'PR Label Harness'    | Out-Null
        git config commit.gpgsign false             | Out-Null
        git checkout -q -b main 2>&1 | Out-Null
        git add -A 2>&1 | Out-Null
        git commit -q -m "fixture for $($Fixture.Count) changed file(s)" 2>&1 | Out-Null
    }
    finally {
        Pop-Location
    }
}

function Invoke-Act {
    param([Parameter(Mandatory)] [string]$WorkDir)

    Push-Location $WorkDir
    try {
        # Capture stdout+stderr together so the harness sees the full picture
        # (act puts job logs on stdout but its own status on stderr in some
        # versions). Don't tee to a separate file - we hand the lines back
        # to the caller for parsing/recording.
        $output = & act push --rm --container-architecture linux/amd64 2>&1
        $exit   = $LASTEXITCODE
        return [pscustomobject]@{
            ExitCode = $exit
            Lines    = @($output)
        }
    }
    finally {
        Pop-Location
    }
}

function Get-Labels {
    # Pull the LABELS_BEGIN/LABELS_END frame out of act's output. act prefixes
    # every workflow line with '| ' (and possibly a job-name banner), so
    # we tolerate any prefix and match against the trimmed tail.
    param([Parameter(Mandatory)] [string[]]$Lines)
    $labels = [System.Collections.Generic.List[string]]::new()
    $inFrame = $false
    foreach ($raw in $Lines) {
        $tail = ($raw -replace '\[[0-9;]*m', '').TrimEnd()
        # Drop act's '[Workflow/Job]   | ' prefix. Match up to the FIRST '|'
        # (non-greedy [^|]*) so parsed content with embedded '|' is safe.
        $clean = ($tail -replace '^[^|]*\|\s?', '').TrimEnd()
        if     ($clean -ceq 'LABELS_END')   { $inFrame = $false; continue }
        elseif ($inFrame)                   { if ($clean) { $labels.Add($clean) } }
        elseif ($clean -ceq 'LABELS_BEGIN') { $inFrame = $true }
    }
    return $labels.ToArray()
}

function Get-JobSucceededCount {
    param([Parameter(Mandatory)] [string[]]$Lines)
    # act ends each successful job with a line containing "Job succeeded".
    return @($Lines | Where-Object { $_ -match 'Job succeeded' }).Count
}

# --------------------------------------------------------------------------
# Workflow structure tests (do not require act)
# --------------------------------------------------------------------------

function Invoke-StructureTests {
    Write-Host '== Workflow structure tests =='
    $errors = @()

    # actionlint passes
    $alOut  = (& actionlint './.github/workflows/pr-label-assigner.yml' 2>&1)
    $alExit = $LASTEXITCODE
    if ($alExit -ne 0) {
        $errors += "actionlint failed (exit $alExit): $alOut"
    } else {
        Write-Host '  actionlint: OK'
    }

    # Referenced script files exist
    foreach ($needed in @('Get-PrLabels.psm1','Get-PrLabels.Tests.ps1','Invoke-PrLabelAssigner.ps1','labels.json','fixtures/changed-files.txt')) {
        if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $needed))) {
            $errors += "Required file missing: $needed"
        }
    }
    if ($errors.Count -eq 0) { Write-Host '  referenced files: OK' }

    # Parse YAML lightly: presence of triggers + jobs by string scan
    # (avoids a powershell-yaml dependency that may not be installed).
    $wf = Get-Content -Raw -LiteralPath './.github/workflows/pr-label-assigner.yml'
    foreach ($needle in @('on:', 'push:', 'pull_request:', 'workflow_dispatch:', 'jobs:', 'pester:', 'assign-labels:', 'actions/checkout@v4', 'shell: pwsh', 'Invoke-PrLabelAssigner.ps1', 'Get-PrLabels.Tests.ps1', 'needs: pester')) {
        if ($wf -notmatch [regex]::Escape($needle)) {
            $errors += "Workflow YAML is missing expected fragment '$needle'."
        }
    }

    if ($errors.Count -gt 0) {
        foreach ($e in $errors) { Write-Host "  STRUCTURE ERROR: $e" -ForegroundColor Red }
        throw "Structure tests failed: $($errors.Count) error(s)."
    }
    Write-Host '  YAML shape: OK'
}

# --------------------------------------------------------------------------
# Main loop
# --------------------------------------------------------------------------

# Sanity check: act and docker available.
if (-not (Get-Command act -ErrorAction SilentlyContinue)) {
    throw "act CLI not found in PATH."
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "docker CLI not found in PATH."
}
if (-not (Get-Command actionlint -ErrorAction SilentlyContinue)) {
    throw "actionlint CLI not found in PATH."
}

Push-Location $PSScriptRoot
try {
    Invoke-StructureTests

    # Reset the result file before the run.
    "PR Label Assigner act results - generated $(Get-Date -Format o)" |
        Set-Content -LiteralPath $ResultFile

    $caseFailures = @()
    foreach ($case in $cases) {
        $name = $case.Name
        Write-Host ''
        Write-Host "== Test case: $name ==" -ForegroundColor Cyan

        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("pr-label-act-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        try {
            Initialize-WorkRepo -Source $PSScriptRoot -Dest $tmp `
                -Fixture  $case.ChangedFiles `
                -Expected $case.ExpectedLabels

            $r = Invoke-Act -WorkDir $tmp

            # Append a clearly delimited section to act-result.txt.
            Add-Content -LiteralPath $ResultFile -Value @"

================================================================================
Test case: $name
ChangedFiles: $($case.ChangedFiles -join ', ')
ExpectedLabels: $(if ($case.ExpectedLabels.Count -eq 0) { '<none>' } else { ($case.ExpectedLabels -join ', ') })
act exit code: $($r.ExitCode)
================================================================================
"@
            Add-Content -LiteralPath $ResultFile -Value ($r.Lines -join "`n")

            # Defensive parsing of the captured output.
            $actualLabels   = @(Get-Labels -Lines $r.Lines)
            $jobsSucceeded  = Get-JobSucceededCount -Lines $r.Lines
            # @() wrap so strict mode is happy when no lines match.
            $sawAssertion   = @($r.Lines | Where-Object { $_ -match 'ASSERTION_PASSED' }).Count -ge 1

            $localFailures = @()
            if ($r.ExitCode -ne 0) {
                $localFailures += "act exit code was $($r.ExitCode), expected 0"
            }
            if ($jobsSucceeded -lt 2) {
                $localFailures += "expected at least 2 jobs to report 'Job succeeded' (pester + assign-labels), saw $jobsSucceeded"
            }
            $expectedJoin = ($case.ExpectedLabels -join '|')
            $actualJoin   = ($actualLabels       -join '|')
            if ($expectedJoin -ne $actualJoin) {
                $localFailures += "labels mismatch: expected=[$($case.ExpectedLabels -join ', ')] actual=[$($actualLabels -join ', ')]"
            }
            if (-not $sawAssertion) {
                $localFailures += "in-workflow assertion did not print ASSERTION_PASSED"
            }

            if ($localFailures.Count -eq 0) {
                Write-Host "  PASS  ($($actualLabels.Count) label(s): $($actualLabels -join ', '))" -ForegroundColor Green
            }
            else {
                $caseFailures += [pscustomobject]@{ Case = $name; Errors = $localFailures }
                foreach ($e in $localFailures) {
                    Write-Host "  FAIL  $e" -ForegroundColor Red
                }
                if ($FailFast) { break }
            }
        }
        finally {
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host ''
    Write-Host "== Summary ==" -ForegroundColor Cyan
    Write-Host "Cases run    : $($cases.Count)"
    Write-Host "Cases passed : $($cases.Count - $caseFailures.Count)"
    Write-Host "Cases failed : $($caseFailures.Count)"
    Write-Host "Result log   : $ResultFile"

    if ($caseFailures.Count -gt 0) {
        foreach ($f in $caseFailures) {
            Write-Host ""
            Write-Host "FAIL: $($f.Case)" -ForegroundColor Red
            foreach ($e in $f.Errors) {
                Write-Host "  - $e" -ForegroundColor Red
            }
        }
        exit 1
    }
}
finally {
    Pop-Location
}

exit 0
