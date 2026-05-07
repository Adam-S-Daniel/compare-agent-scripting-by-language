<#
    Pester test harness.

    All assertions on script behavior run THROUGH the GitHub Actions workflow
    via `act`. The workflow uses a matrix that processes every fixture in a
    single `act push --rm` invocation; the harness asserts on the combined
    output.

    Workflow structure tests parse the YAML and verify actionlint passes —
    these run locally without invoking act.

    Pester v5 isolates module scope between discovery and run, so all setup
    (paths, helpers, fixture-result reset) lives inside BeforeAll blocks.
#>

BeforeAll {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest

    $script:ProjectRoot  = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:WorkflowFile = Join-Path $script:ProjectRoot '.github/workflows/semantic-version-bumper.yml'
    $script:ResultFile   = Join-Path $script:ProjectRoot 'act-result.txt'

    if (Test-Path $script:ResultFile) { Remove-Item $script:ResultFile -Force }

    function Invoke-ActAllCases {
        # Build a temp git repo with the entire project content (script,
        # workflow, fixtures), then run `act push --rm --pull=false` once.
        # The matrix-based workflow exercises every fixture in a single
        # invocation, so the captured output covers all cases.
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("svb-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Path $tmp | Out-Null

        try {
            Copy-Item -Recurse -Force (Join-Path $script:ProjectRoot '.github')   $tmp
            Copy-Item -Recurse -Force (Join-Path $script:ProjectRoot 'fixtures')  $tmp
            Copy-Item -Force          (Join-Path $script:ProjectRoot 'Bump-Version.ps1') $tmp
            Copy-Item -Force          (Join-Path $script:ProjectRoot '.actrc')    $tmp -ErrorAction SilentlyContinue

            Push-Location $tmp
            try {
                git init -q -b main 2>&1 | Out-Null
                git config user.email "test@example.com"
                git config user.name  "test"
                git add -A 2>&1 | Out-Null
                git commit -q -m "test: matrix" 2>&1 | Out-Null

                $logPath = Join-Path $tmp 'act.log'
                $errPath = Join-Path $tmp 'act.err'
                $proc = Start-Process -FilePath 'act' `
                    -ArgumentList @('push','--rm','--pull=false') `
                    -NoNewWindow -Wait -PassThru `
                    -RedirectStandardOutput $logPath `
                    -RedirectStandardError  $errPath

                $stdout = if (Test-Path $logPath) { Get-Content $logPath -Raw } else { '' }
                $stderr = if (Test-Path $errPath) { Get-Content $errPath -Raw } else { '' }

                $delim = "=" * 72
                Add-Content -Path $script:ResultFile -Value @"
$delim
RUN: matrix (feat, fix, breaking)
EXIT: $($proc.ExitCode)
$delim
--- STDOUT ---
$stdout
--- STDERR ---
$stderr

"@
                return [pscustomobject]@{
                    ExitCode = $proc.ExitCode
                    Output   = ($stdout + "`n" + $stderr)
                }
            } finally {
                Pop-Location
            }
        } finally {
            Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Workflow file structure' {
    It 'workflow file exists' {
        Test-Path $script:WorkflowFile | Should -BeTrue
    }

    It 'declares expected triggers, job, matrix and uses checkout + script' {
        $text = Get-Content $script:WorkflowFile -Raw
        $text | Should -Match '(?m)^on:'
        $text | Should -Match 'push:'
        $text | Should -Match 'pull_request:'
        $text | Should -Match 'workflow_dispatch:'
        $text | Should -Match 'jobs:\s*\r?\n\s*bump:'
        $text | Should -Match 'matrix:\s*\r?\n\s*fixture:\s*\[feat, fix, breaking\]'
        $text | Should -Match 'actions/checkout@v4'
        $text | Should -Match 'Bump-Version\.ps1'
    }

    It 'references files that actually exist' {
        Test-Path (Join-Path $script:ProjectRoot 'Bump-Version.ps1') | Should -BeTrue
        Test-Path (Join-Path $script:ProjectRoot 'fixtures/feat/version.txt')      | Should -BeTrue
        Test-Path (Join-Path $script:ProjectRoot 'fixtures/feat/commits.txt')      | Should -BeTrue
        Test-Path (Join-Path $script:ProjectRoot 'fixtures/fix/version.txt')       | Should -BeTrue
        Test-Path (Join-Path $script:ProjectRoot 'fixtures/fix/commits.txt')       | Should -BeTrue
        Test-Path (Join-Path $script:ProjectRoot 'fixtures/breaking/version.json') | Should -BeTrue
        Test-Path (Join-Path $script:ProjectRoot 'fixtures/breaking/commits.txt')  | Should -BeTrue
    }

    It 'passes actionlint with exit code 0' {
        $proc = Start-Process -FilePath 'actionlint' `
            -ArgumentList @($script:WorkflowFile) `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput (Join-Path $TestDrive 'al.out') `
            -RedirectStandardError  (Join-Path $TestDrive 'al.err')
        $proc.ExitCode | Should -Be 0
    }
}

Describe 'Workflow execution via act' {
    BeforeAll {
        $script:Run = Invoke-ActAllCases
        # Count "Job succeeded" markers — one per matrix entry (3 expected).
        $script:JobSucceededCount =
            ([regex]::Matches($script:Run.Output, 'Job succeeded')).Count
    }

    It 'act exits with code 0' {
        $script:Run.ExitCode | Should -Be 0
    }

    It 'every job (3 matrix entries) shows Job succeeded' {
        $script:JobSucceededCount | Should -Be 3
    }

    Context 'feat fixture: 1.1.0 -> 1.2.0 (minor)' {
        It 'emits exact RESULT_VERSION[feat]=1.2.0' {
            $script:Run.Output | Should -Match 'RESULT_VERSION\[feat\]=1\.2\.0'
        }
        It 'reports BUMP_TYPE=minor in the feat output block' {
            $script:Run.Output | Should -Match '(?s)BEGIN BUMPER OUTPUT \[feat\].*?BUMP_TYPE=minor.*?END BUMPER OUTPUT \[feat\]'
        }
        It 'updated VERSION file content to 1.2.0' {
            $script:Run.Output | Should -Match '(?s)BEGIN VERSION FILE \[feat\].*?1\.2\.0.*?END VERSION FILE \[feat\]'
        }
        It 'changelog entry includes new heading and feat commit' {
            $script:Run.Output | Should -Match '(?s)BEGIN CHANGELOG \[feat\].*?## 1\.2\.0.*?feat\(api\): add user search endpoint.*?END CHANGELOG \[feat\]'
        }
    }

    Context 'fix fixture: 2.3.4 -> 2.3.5 (patch)' {
        It 'emits exact RESULT_VERSION[fix]=2.3.5' {
            $script:Run.Output | Should -Match 'RESULT_VERSION\[fix\]=2\.3\.5'
        }
        It 'reports BUMP_TYPE=patch in the fix output block' {
            $script:Run.Output | Should -Match '(?s)BEGIN BUMPER OUTPUT \[fix\].*?BUMP_TYPE=patch.*?END BUMPER OUTPUT \[fix\]'
        }
        It 'updated VERSION file to 2.3.5' {
            $script:Run.Output | Should -Match '(?s)BEGIN VERSION FILE \[fix\].*?2\.3\.5.*?END VERSION FILE \[fix\]'
        }
    }

    Context 'breaking fixture (package.json): 0.9.7 -> 1.0.0 (major)' {
        It 'emits exact RESULT_VERSION[breaking]=1.0.0' {
            $script:Run.Output | Should -Match 'RESULT_VERSION\[breaking\]=1\.0\.0'
        }
        It 'reports BUMP_TYPE=major in the breaking output block' {
            $script:Run.Output | Should -Match '(?s)BEGIN BUMPER OUTPUT \[breaking\].*?BUMP_TYPE=major.*?END BUMPER OUTPUT \[breaking\]'
        }
        It 'updated package.json version field to 1.0.0' {
            $script:Run.Output | Should -Match '(?s)BEGIN VERSION FILE \[breaking\].*?"version"\s*:\s*"1\.0\.0".*?END VERSION FILE \[breaking\]'
        }
    }
}
