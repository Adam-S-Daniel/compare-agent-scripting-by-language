# Workflow + act-based integration tests.
#
# This suite verifies three things:
#   1. The workflow YAML is structurally correct (referenced files exist,
#      expected jobs/triggers are present).
#   2. actionlint reports zero issues.
#   3. Three real `act push` runs succeed and produce the exact expected
#      cleanup plan output for three different fixtures.
#
# The act runs are slow (~30-90s each), so they share a single staged copy of
# the repo per run. Output from every act invocation is appended to
# act-result.txt in the workspace root for review.

BeforeAll {
    $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:WorkflowPath = Join-Path $Root '.github/workflows/artifact-cleanup-script.yml'
    $script:ResultFile   = Join-Path $Root 'act-result.txt'

    if (Test-Path -LiteralPath $script:ResultFile) {
        Remove-Item -LiteralPath $script:ResultFile -Force
    }

    function script:Invoke-ActPush {
        # Stage the project into a fresh temp dir, init a git repo so act has
        # something to check out, and run a single `act push` invocation.
        # Captures combined stdout+stderr and appends it to act-result.txt
        # delimited by a banner identifying the case.
        param(
            [string] $CaseName,
            [hashtable] $EnvOverrides = @{}
        )

        $stage = Join-Path ([System.IO.Path]::GetTempPath()) ("act-stage-$([guid]::NewGuid().ToString('N'))")
        New-Item -ItemType Directory -Path $stage | Out-Null
        try {
            # Mirror project files into the stage. We exclude .git so we can
            # init a clean repo there.
            Copy-Item -Path (Join-Path $script:Root '*') -Destination $stage -Recurse -Force
            Copy-Item -Path (Join-Path $script:Root '.github') -Destination $stage -Recurse -Force

            Push-Location $stage
            try {
                git init -q -b main 2>&1 | Out-Null
                git config user.email 'test@example.com' 2>&1 | Out-Null
                git config user.name  'test' 2>&1 | Out-Null
                git add -A 2>&1 | Out-Null
                git commit -q -m 'staged' 2>&1 | Out-Null

                # Build env-file so act injects FIXTURE/APPLY without us
                # having to escape shell args.
                $envFile = Join-Path $stage '.act.env'
                $envLines = $EnvOverrides.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
                Set-Content -LiteralPath $envFile -Value ($envLines -join "`n")

                # `act push --rm` runs the push event end-to-end and tears
                # down the container afterwards. The custom container image
                # (act-ubuntu-pwsh) ships with pwsh + Pester preinstalled --
                # we pass --pull=false because the image is local-only and
                # act would otherwise attempt (and fail) to pull from a
                # registry. -P pins ubuntu-latest to the local image.
                $banner = "==== CASE: $CaseName ====`n"
                Add-Content -LiteralPath $script:ResultFile -Value $banner

                $output = & act push --rm --pull=false `
                    -P ubuntu-latest=act-ubuntu-pwsh:latest `
                    --env-file $envFile 2>&1 | Out-String
                Add-Content -LiteralPath $script:ResultFile -Value $output

                return [pscustomobject]@{
                    ExitCode = $LASTEXITCODE
                    Output   = $output
                }
            }
            finally {
                Pop-Location
            }
        }
        finally {
            Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Workflow structure' {

    It 'workflow file exists' {
        Test-Path -LiteralPath $script:WorkflowPath | Should -BeTrue
    }

    It 'references files that actually exist' {
        $yaml = Get-Content -LiteralPath $script:WorkflowPath -Raw
        $yaml | Should -Match 'src/Invoke-Cleanup.ps1'
        Test-Path -LiteralPath (Join-Path $script:Root 'src/Invoke-Cleanup.ps1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:Root 'src/ArtifactCleanup.psm1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:Root 'fixtures/case-combined.json') | Should -BeTrue
    }

    It 'declares the expected triggers, jobs, and uses checkout@v4' {
        $yaml = Get-Content -LiteralPath $script:WorkflowPath -Raw
        $yaml | Should -Match '(?ms)on:\s*\r?\n\s*push:'
        $yaml | Should -Match 'pull_request:'
        $yaml | Should -Match 'workflow_dispatch:'
        $yaml | Should -Match 'schedule:'
        $yaml | Should -Match 'jobs:\s*\r?\n\s*test:'
        $yaml | Should -Match 'cleanup:'
        $yaml | Should -Match 'needs:\s*test'
        $yaml | Should -Match 'actions/checkout@v4'
    }

    It 'passes actionlint' {
        $out = & actionlint $script:WorkflowPath 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output:`n$out"
    }
}

Describe 'act push end-to-end' {

    It 'runs case-max-age and outputs the expected plan' {
        $r = Invoke-ActPush -CaseName 'max-age' -EnvOverrides @{ FIXTURE = 'case-max-age.json' }

        $r.ExitCode | Should -Be 0
        # Every job in this workflow must succeed.
        ([regex]::Matches($r.Output, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2

        # Exact plan numerics for case-max-age:
        # 3 artifacts; cutoff at 30 days; build-old + build-older are deleted
        # (1024 + 4096 = 5120 reclaimed); build-fresh is retained (2048).
        $r.Output | Should -Match 'Total artifacts:\s+3'
        $r.Output | Should -Match 'Delete:\s+2'
        $r.Output | Should -Match 'Retain:\s+1'
        $r.Output | Should -Match 'Bytes reclaimed:\s+5120'
        $r.Output | Should -Match 'Bytes retained:\s+2048'
        $r.Output | Should -Match 'DELETE build-old \(1024 bytes\) reason=max-age'
        $r.Output | Should -Match 'DELETE build-older \(4096 bytes\) reason=max-age'
        $r.Output | Should -Match 'RETAIN build-fresh \(2048 bytes\)'
        $r.Output | Should -Match 'MODE: DRY-RUN'
    }

    It 'runs case-keep-latest and outputs the expected plan' {
        $r = Invoke-ActPush -CaseName 'keep-latest' -EnvOverrides @{ FIXTURE = 'case-keep-latest.json' }

        $r.ExitCode | Should -Be 0
        ([regex]::Matches($r.Output, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2

        # 4 artifacts; keep latest 1 per workflow.
        # wfA: keep k1 (newest), delete k2 (200) + k3 (300) -> 500 reclaimed.
        # wfB: keep k4 (only one in wfB).
        # Retained sizes: 100 + 400 = 500.
        $r.Output | Should -Match 'Total artifacts:\s+4'
        $r.Output | Should -Match 'Delete:\s+2'
        $r.Output | Should -Match 'Retain:\s+2'
        $r.Output | Should -Match 'Bytes reclaimed:\s+500'
        $r.Output | Should -Match 'Bytes retained:\s+500'
        $r.Output | Should -Match 'reason=keep-latest-per-workflow'
    }

    It 'runs case-combined and outputs the expected plan' {
        $r = Invoke-ActPush -CaseName 'combined' -EnvOverrides @{ FIXTURE = 'case-combined.json'; APPLY = 'true' }

        $r.ExitCode | Should -Be 0
        ([regex]::Matches($r.Output, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2

        # 6 artifacts. Policies: maxAgeDays=30, keepLatestPerWorkflow=2,
        # maxTotalSizeBytes=5000.
        # c1 ancient (9999) -> max-age delete.
        # c4 w1-third      -> keep-latest delete.
        # Remaining 4 artifacts sum to exactly 5000 (within budget) so no
        # max-total-size eviction. Reclaimed = 9999 + 1000 = 10999.
        $r.Output | Should -Match 'Total artifacts:\s+6'
        $r.Output | Should -Match 'Delete:\s+2'
        $r.Output | Should -Match 'Retain:\s+4'
        $r.Output | Should -Match 'Bytes reclaimed:\s+10999'
        $r.Output | Should -Match 'Bytes retained:\s+5000'
        $r.Output | Should -Match 'DELETE ancient \(9999 bytes\) reason=max-age'
        $r.Output | Should -Match 'DELETE w1-third \(1000 bytes\) reason=keep-latest-per-workflow'
        # APPLY mode invokes the mock deleter, which logs each removal.
        $r.Output | Should -Match '\[delete-mock\] removed artifact id=c1'
        $r.Output | Should -Match '\[delete-mock\] removed artifact id=c4'
        $r.Output | Should -Match 'MODE: APPLY'
    }
}
