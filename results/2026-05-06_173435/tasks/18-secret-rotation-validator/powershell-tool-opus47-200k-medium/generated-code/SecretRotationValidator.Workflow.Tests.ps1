#requires -Modules Pester
# Workflow / integration tests.
#
# A single `act push --rm` exercises a 3-row matrix (validate job per case)
# plus the unit-tests job. We then parse the captured log to assert per-case
# expected values (total/expired/warning/ok) and confirm every job succeeded.
# The full log is written to act-result.txt as a required artifact.

BeforeAll {
    $script:RepoRoot = $PSScriptRoot
    $script:ResultFile = Join-Path $RepoRoot 'act-result.txt'
    $script:WorkflowPath = Join-Path $RepoRoot '.github/workflows/secret-rotation-validator.yml'

    function Invoke-ActOnce {
        # Build an isolated temp git repo containing the project files +
        # fixtures, commit them, and run `act push --rm` once. Returns the
        # captured stdout/stderr and exit code.
        $work = Join-Path ([System.IO.Path]::GetTempPath()) ("act-srv-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $work | Out-Null
        try {
            foreach ($name in @(
                'SecretRotationValidator.ps1',
                'SecretRotationValidator.Tests.ps1',
                '.actrc'
            )) {
                $src = Join-Path $script:RepoRoot $name
                if (Test-Path $src) { Copy-Item $src $work }
            }
            Copy-Item -Path (Join-Path $script:RepoRoot '.github')   -Destination $work -Recurse
            Copy-Item -Path (Join-Path $script:RepoRoot 'fixtures') -Destination $work -Recurse

            Push-Location $work
            try {
                git init -q -b main
                git -c user.email=t@t -c user.name=t add -A | Out-Null
                git -c user.email=t@t -c user.name=t commit -q -m init | Out-Null

                $log = & act push --rm 2>&1 | Out-String
                $exit = $LASTEXITCODE

                # Persist the full log to act-result.txt — required artifact.
                $header = "===== act push --rm (exit=$exit) ====="
                $footer = "===== END act push --rm ====="
                Set-Content -Path $script:ResultFile -Value "$header`n$log`n$footer`n"

                return [pscustomobject]@{
                    ExitCode = $exit
                    Log      = $log
                }
            } finally {
                Pop-Location
            }
        } finally {
            Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Workflow file structure' {
    BeforeAll {
        $script:WorkflowText = Get-Content -Raw $script:WorkflowPath
    }

    It 'exists' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It 'declares push, pull_request, schedule, and workflow_dispatch triggers' {
        $script:WorkflowText | Should -Match '(?m)^\s*push:'
        $script:WorkflowText | Should -Match '(?m)^\s*pull_request:'
        $script:WorkflowText | Should -Match '(?m)^\s*schedule:'
        $script:WorkflowText | Should -Match '(?m)^\s*workflow_dispatch:'
    }

    It 'defines the unit-tests and validate jobs with a dependency' {
        $script:WorkflowText | Should -Match '(?m)^\s*unit-tests:'
        $script:WorkflowText | Should -Match '(?m)^\s*validate:'
        $script:WorkflowText | Should -Match 'needs:\s*unit-tests'
    }

    It 'references script files that exist' {
        $script:WorkflowText | Should -Match 'SecretRotationValidator\.ps1'
        $script:WorkflowText | Should -Match 'SecretRotationValidator\.Tests\.ps1'
        Test-Path (Join-Path $PSScriptRoot 'SecretRotationValidator.ps1') | Should -BeTrue
        Test-Path (Join-Path $PSScriptRoot 'SecretRotationValidator.Tests.ps1') | Should -BeTrue
    }

    It 'references fixture files that exist' {
        foreach ($f in 'fixtures/all-ok.json','fixtures/mixed.json') {
            Test-Path (Join-Path $PSScriptRoot $f) | Should -BeTrue
        }
    }

    It 'uses actions/checkout@v4' {
        $script:WorkflowText | Should -Match 'actions/checkout@v4'
    }

    It 'passes actionlint cleanly' {
        $null = & actionlint $script:WorkflowPath
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'Workflow execution via act' {
    BeforeAll {
        $script:run = Invoke-ActOnce
    }

    It 'act exits 0' {
        $script:run.ExitCode | Should -Be 0
    }

    It 'every job in the run succeeds (4 jobs: unit-tests + 3-case matrix)' {
        $matches = ($script:run.Log | Select-String -Pattern 'Job succeeded' -AllMatches).Matches
        # 1 unit-tests + 3 validate matrix jobs == 4 successful jobs
        $matches.Count | Should -BeGreaterOrEqual 4
    }

    It 'shows no failed jobs' {
        $script:run.Log | Should -Not -Match 'Job failed'
    }

    Context 'Case all-ok (fresh secrets only)' {
        It 'reports total=2 expired=0 warning=0 ok=2' {
            $script:run.Log | Should -Match 'CASE=all-ok SUMMARY total=2 expired=0 warning=0 ok=2'
        }
    }

    Context 'Case mixed-json' {
        It 'reports total=3 expired=1 warning=1 ok=1' {
            $script:run.Log | Should -Match 'CASE=mixed-json SUMMARY total=3 expired=1 warning=1 ok=1'
        }
        It 'JSON output names db-password as expired' {
            # Extract the mixed-json case block and scan it for expected JSON.
            $m = [regex]::Match($script:run.Log,
                '(?s)===== BEGIN CASE: mixed-json =====(.*?)===== END CASE: mixed-json =====')
            $m.Success | Should -BeTrue
            $m.Groups[1].Value | Should -Match '"name":\s*"db-password"'
            $m.Groups[1].Value | Should -Match '"urgency":\s*"expired"'
            $m.Groups[1].Value | Should -Match '"urgency":\s*"warning"'
            $m.Groups[1].Value | Should -Match '"urgency":\s*"ok"'
        }
    }

    Context 'Case mixed-markdown' {
        It 'reports total=3 expired=1 warning=1 ok=1' {
            $script:run.Log | Should -Match 'CASE=mixed-markdown SUMMARY total=3 expired=1 warning=1 ok=1'
        }
        It 'markdown output has expected section headers and rows' {
            $m = [regex]::Match($script:run.Log,
                '(?s)===== BEGIN CASE: mixed-markdown =====(.*?)===== END CASE: mixed-markdown =====')
            $m.Success | Should -BeTrue
            $body = $m.Groups[1].Value
            $body | Should -Match '## Expired \(1\)'
            $body | Should -Match '## Warning \(1\)'
            $body | Should -Match '## OK \(1\)'
            $body | Should -Match 'db-password'
            $body | Should -Match 'billing, api'
        }
    }
}

Describe 'act-result.txt artifact' {
    It 'exists after the run' {
        Test-Path $script:ResultFile | Should -BeTrue
    }
    It 'is non-empty and contains the act log header' {
        $text = Get-Content -Raw $script:ResultFile
        $text.Length | Should -BeGreaterThan 0
        $text | Should -Match '===== act push --rm'
    }
}
