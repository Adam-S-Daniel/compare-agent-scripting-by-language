# Workflow-level tests:
#   1. Structure tests parse the workflow YAML and assert expected shape /
#      that the script paths it references exist.
#   2. actionlint must pass cleanly.
#   3. act runs the workflow against each fixture case and we assert on the
#      EXACT numeric output the aggregator emitted (not just "some output").
#
# The act runs append output to act-result.txt in the project root. That
# artifact is required by the benchmark harness.

BeforeDiscovery {
    $script:ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:WorkflowFile = Join-Path $script:ProjectRoot '.github/workflows/test-results-aggregator.yml'
    $script:ActResultFile = Join-Path $script:ProjectRoot 'act-result.txt'

    # Decide whether to skip act tests up front: act only runs in environments
    # with Docker available and the act binary on PATH.
    $script:CanRunAct = $false
    try {
        $actExists = (Get-Command act -ErrorAction SilentlyContinue) -ne $null
        $dockerExists = (Get-Command docker -ErrorAction SilentlyContinue) -ne $null
        if ($actExists -and $dockerExists) {
            # Ensure the docker daemon is reachable -- act will hang otherwise.
            $null = & docker info 2>&1
            if ($LASTEXITCODE -eq 0) { $script:CanRunAct = $true }
        }
    } catch { $script:CanRunAct = $false }
}

BeforeAll {
    $script:ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:WorkflowFile = Join-Path $script:ProjectRoot '.github/workflows/test-results-aggregator.yml'
    $script:ActResultFile = Join-Path $script:ProjectRoot 'act-result.txt'
}

Describe 'Workflow YAML structure' {
    BeforeAll {
        # Use ConvertFrom-Yaml if available (powershell-yaml module); otherwise
        # fall back to regex assertions, since act/actionlint already validate
        # the YAML grammar.
        $script:Yaml = Get-Content -LiteralPath $script:WorkflowFile -Raw
    }

    It 'workflow file exists' {
        Test-Path -LiteralPath $script:WorkflowFile | Should -BeTrue
    }

    It 'declares push, pull_request, schedule and workflow_dispatch triggers' {
        $script:Yaml | Should -Match '(?ms)^on:\s*$'
        $script:Yaml | Should -Match '(?m)^\s*push:'
        $script:Yaml | Should -Match '(?m)^\s*pull_request:'
        $script:Yaml | Should -Match '(?m)^\s*schedule:'
        $script:Yaml | Should -Match '(?m)^\s*workflow_dispatch:'
    }

    It 'declares both unit-tests and aggregate jobs with the expected dependency' {
        $script:Yaml | Should -Match '(?m)^\s+unit-tests:'
        $script:Yaml | Should -Match '(?m)^\s+aggregate:'
        # aggregate must depend on unit-tests so a broken aggregator never reports.
        $script:Yaml | Should -Match 'needs:\s*unit-tests'
    }

    It 'sets a contents:read permission' {
        $script:Yaml | Should -Match 'permissions:\s*[\r\n]+\s*contents:\s*read'
    }

    It 'uses actions/checkout@v4 (pinned major)' {
        $script:Yaml | Should -Match 'uses:\s*actions/checkout@v4'
    }

    It 'every run: step uses shell: pwsh (avoids bash/pwsh quoting traps)' {
        # No `run:` block should be missing the explicit pwsh shell.
        $runs = ([regex]::Matches($script:Yaml, '(?m)^\s+- name:.*\n(?:\s+id:.*\n)?\s+shell:\s*(\S+)')).Count
        $bareRuns = ([regex]::Matches($script:Yaml, '(?m)^\s+- name:.*\n(?:\s+[^s][^:]*?:.*\n)*?\s+run:\s*\|')).Count
        # Every step that has run: should have shell: pwsh on the same step.
        # We check by enumerating all step starts and asserting each owning a
        # `run:` also owns a `shell: pwsh` line in the same step.
        $stepBlocks = $script:Yaml -split '(?m)^\s+- name:'
        foreach ($block in $stepBlocks) {
            if ($block -match '\brun:\s*\|') {
                $block | Should -Match 'shell:\s*pwsh' -Because 'PowerShell mode requires shell: pwsh on every run step'
            }
        }
    }

    It 'references the aggregator script that exists on disk' {
        $script:Yaml | Should -Match '\./Aggregate-TestResults\.ps1'
        Test-Path -LiteralPath (Join-Path $script:ProjectRoot 'Aggregate-TestResults.ps1') | Should -BeTrue
    }

    It 'references the Pester test file that exists on disk' {
        $script:Yaml | Should -Match 'tests/Aggregate-TestResults\.Tests\.ps1'
        Test-Path -LiteralPath (Join-Path $script:ProjectRoot 'tests/Aggregate-TestResults.Tests.ps1') | Should -BeTrue
    }
}

Describe 'actionlint validation' {
    It 'passes actionlint cleanly' {
        $output = & actionlint $script:WorkflowFile 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ("actionlint output:`n" + ($output -join "`n"))
    }
}

Describe 'act end-to-end runs' -Tag 'act' -Skip:(-not $script:CanRunAct) {
    BeforeAll {
        # Reset the act-result artifact at the start of the run; each test case
        # appends a delimited block to it.
        if (Test-Path -LiteralPath $script:ActResultFile) {
            Remove-Item -LiteralPath $script:ActResultFile -Force
        }
        New-Item -ItemType File -Path $script:ActResultFile | Out-Null

        # Helper: run the workflow inside an isolated temp git repo containing
        # only the project files + the requested fixture dir (mounted as
        # `fixtures/`). This isolates each test case and proves the workflow
        # works against a fresh checkout, the way real CI does.
        function script:Invoke-ActCase {
            param(
                [Parameter(Mandatory)][string]$CaseName,
                [Parameter(Mandatory)][string]$FixtureDir
            )

            $work = Join-Path ([System.IO.Path]::GetTempPath()) ("act-case-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $work | Out-Null
            try {
                # Copy project files into the temp repo.
                Copy-Item -Path (Join-Path $script:ProjectRoot 'Aggregate-TestResults.ps1') -Destination $work
                Copy-Item -Path (Join-Path $script:ProjectRoot 'tests') -Destination $work -Recurse
                Copy-Item -Path (Join-Path $script:ProjectRoot '.github') -Destination $work -Recurse
                # Copy .actrc so the temp repo uses the same image override.
                if (Test-Path (Join-Path $script:ProjectRoot '.actrc')) {
                    Copy-Item -Path (Join-Path $script:ProjectRoot '.actrc') -Destination $work
                }

                # Plant fixtures at the path the workflow's env default points to.
                $fixtureDest = Join-Path $work 'fixtures/case-mixed'
                New-Item -ItemType Directory -Path $fixtureDest -Force | Out-Null
                Copy-Item -Path (Join-Path $FixtureDir '*') -Destination $fixtureDest -Recurse

                # Initialize a git repo so actions/checkout@v4 has something to checkout.
                Push-Location $work
                try {
                    & git init -q
                    & git -c user.email=ci@example.com -c user.name=ci add -A
                    & git -c user.email=ci@example.com -c user.name=ci commit -q -m "case $CaseName"

                    # Run act and tee output. Use --rm so the container is cleaned up.
                    # --pull=false because the act-ubuntu-pwsh image is built locally
                    # and not pushed to a registry; otherwise act tries to pull it.
                    $logFile = Join-Path $work 'act.log'
                    & act push --rm --pull=false --workflows .github/workflows/test-results-aggregator.yml *>&1 |
                        Tee-Object -FilePath $logFile | Out-Null
                    $exitCode = $LASTEXITCODE
                    $log = Get-Content -LiteralPath $logFile -Raw

                    # Append delimited block to the project-root act-result.txt artifact.
                    $delim = "=" * 70
                    $header = "$delim`nCASE: $CaseName (fixture=$FixtureDir, exit=$exitCode)`n$delim"
                    Add-Content -LiteralPath $script:ActResultFile -Value $header
                    Add-Content -LiteralPath $script:ActResultFile -Value $log
                    Add-Content -LiteralPath $script:ActResultFile -Value ""

                    [pscustomobject]@{ ExitCode = $exitCode; Log = $log }
                }
                finally { Pop-Location }
            }
            finally {
                Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'case-mixed: 18 records, 1 flaky, 4 failed' {
        BeforeAll {
            $script:MixedResult = script:Invoke-ActCase -CaseName 'mixed' `
                -FixtureDir (Join-Path $script:ProjectRoot 'fixtures/case-mixed')
        }

        It 'act exits 0' {
            $script:MixedResult.ExitCode | Should -Be 0 -Because ("act log:`n" + $script:MixedResult.Log)
        }

        It 'every job reports Job succeeded' {
            # act prints "Job succeeded" once per successful job. We expect
            # exactly two (unit-tests + aggregate).
            $matches = [regex]::Matches($script:MixedResult.Log, '(?m)Job succeeded')
            $matches.Count | Should -BeGreaterOrEqual 2
        }

        It 'aggregator emits the exact totals line' {
            $script:MixedResult.Log | Should -Match 'Total=18 Passed=11 Failed=4 Skipped=3 Duration=1\.80s'
        }

        It 'reports exactly one flaky test, named auth::flaky_login' {
            $script:MixedResult.Log | Should -Match 'FlakyCount=1'
            $script:MixedResult.Log | Should -Match 'Flaky:\s*auth::flaky_login'
        }

        It 'markdown summary block is present in the log' {
            $script:MixedResult.Log | Should -Match 'BEGIN SUMMARY MARKDOWN'
            $script:MixedResult.Log | Should -Match '\| Total\s*\|\s*18 \|'
            $script:MixedResult.Log | Should -Match '\| Failed\s*\|\s*4 \|'
        }
    }

    Context 'case-green: all-passing, no flaky' {
        BeforeAll {
            $script:GreenResult = script:Invoke-ActCase -CaseName 'green' `
                -FixtureDir (Join-Path $script:ProjectRoot 'fixtures/case-green')
        }

        It 'act exits 0' {
            $script:GreenResult.ExitCode | Should -Be 0 -Because ("act log:`n" + $script:GreenResult.Log)
        }

        It 'every job reports Job succeeded' {
            $matches = [regex]::Matches($script:GreenResult.Log, '(?m)Job succeeded')
            $matches.Count | Should -BeGreaterOrEqual 2
        }

        It 'aggregator reports 4 records, all passed' {
            $script:GreenResult.Log | Should -Match 'Total=4 Passed=4 Failed=0 Skipped=0 Duration=0\.20s'
        }

        It 'reports zero flaky tests' {
            $script:GreenResult.Log | Should -Match 'FlakyCount=0'
        }

        It 'markdown summary indicates no flaky tests' {
            $script:GreenResult.Log | Should -Match 'No flaky tests detected'
        }
    }

    It 'act-result.txt was written' {
        Test-Path -LiteralPath $script:ActResultFile | Should -BeTrue
        (Get-Item $script:ActResultFile).Length | Should -BeGreaterThan 0
    }
}
