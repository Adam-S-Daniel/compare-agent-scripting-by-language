# Integration tests that execute the license-checker workflow through act.
#
# Each test case copies the project into a temp git repo, replaces the
# relevant fixture(s), commits, and invokes `act push --rm`. All act output
# is appended to act-result.txt in the repo root. We then assert:
#   1. act exited 0
#   2. The job succeeded (log contains "Job succeeded")
#   3. The report contains the exact license-status lines we expect for the
#      known input fixtures.
#
# We run at most 3 test cases; the instructions cap us at 3 `act push` runs.

BeforeDiscovery {
    $script:ProjectRoot = $PSScriptRoot
    $script:ActResultPath = Join-Path $script:ProjectRoot 'act-result.txt'
    # Truncate the act result log at the start of each discovery so re-runs
    # produce a clean artifact. This is idempotent under Pester.
    if (Test-Path $script:ActResultPath) { Remove-Item $script:ActResultPath -Force }
    '' | Set-Content -Path $script:ActResultPath -Encoding utf8

    # Probe for the tools we need. We still run the tests in discovery, but
    # mark them skipped if act/docker are missing so local iteration doesn't
    # force a Docker install.
    $script:HaveAct    = $null -ne (Get-Command act    -ErrorAction SilentlyContinue)
    $script:HaveDocker = $null -ne (Get-Command docker -ErrorAction SilentlyContinue)
}

BeforeAll {
    $script:ProjectRoot   = $PSScriptRoot
    $script:ActResultPath = Join-Path $script:ProjectRoot 'act-result.txt'
    $script:HaveAct       = $null -ne (Get-Command act    -ErrorAction SilentlyContinue)
    $script:HaveDocker    = $null -ne (Get-Command docker -ErrorAction SilentlyContinue)

    function Invoke-ActCase {
        <#
            Runs a single act test case end-to-end.
            $ManifestRelPath: the project-relative fixture path to advertise
                as the MANIFEST env var (so the default, which points at
                all-approved, is overridden per case).
            Returns a pscustomobject with ExitCode and Output (string).
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)][string]$CaseName,
            [Parameter(Mandatory)][string]$ManifestRelPath,
            [Parameter(Mandatory)][bool]$ExpectFailOnDenied
        )

        # Stage a clean copy of the project in a throwaway dir. act requires a
        # git repo, so we initialise and commit.
        $stage = Join-Path ([System.IO.Path]::GetTempPath()) ("dlc-act-{0}-{1}" -f $CaseName, ([guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path $stage | Out-Null
        try {
            # Copy only what we need — no .git, no act-result.txt, no dotfile cruft.
            $includes = @(
                'DependencyLicenseChecker.ps1',
                '.github',
                'fixtures',
                '.actrc'
            )
            foreach ($item in $includes) {
                $src = Join-Path $script:ProjectRoot $item
                if (Test-Path $src) {
                    Copy-Item -Path $src -Destination (Join-Path $stage $item) -Recurse -Force
                }
            }

            Push-Location $stage
            try {
                git init --quiet 2>&1 | Out-Null
                git config user.email 'act@example.com'
                git config user.name  'act'
                git add -A
                git commit --quiet -m "test: $CaseName" 2>&1 | Out-Null

                # Assemble act args. We override MANIFEST and disable fail-on-denied
                # for the case that expects the run to report-but-not-fail.
                # --pull=false: the `.actrc` pins runs to the local-only
                # act-ubuntu-pwsh image. Without this flag act force-pulls and
                # Docker Hub returns "repository does not exist".
                $actArgs = @(
                    'push',
                    '--rm',
                    '--pull=false',
                    '--env', "MANIFEST=$ManifestRelPath"
                )
                if (-not $ExpectFailOnDenied) {
                    $actArgs += @('--env', 'FAIL_ON_DENIED=false')
                }

                $output = & act @actArgs 2>&1 | Out-String
                $rc     = $LASTEXITCODE

                $banner = @(
                    ('=' * 70),
                    "CASE: $CaseName",
                    "MANIFEST: $ManifestRelPath",
                    "FAIL_ON_DENIED: $ExpectFailOnDenied",
                    "EXIT: $rc",
                    ('=' * 70)
                ) -join [Environment]::NewLine

                Add-Content -LiteralPath $script:ActResultPath -Value $banner
                Add-Content -LiteralPath $script:ActResultPath -Value $output
                Add-Content -LiteralPath $script:ActResultPath -Value ''

                return [pscustomobject]@{
                    ExitCode = $rc
                    Output   = $output
                }
            }
            finally {
                Pop-Location
            }
        }
        finally {
            # Best-effort cleanup. Docker might keep volumes around briefly.
            Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Act pipeline — license checker workflow' {
    BeforeAll {
        if (-not $script:HaveAct -or -not $script:HaveDocker) {
            return
        }
    }

    It 'Case 1: all-approved manifest passes the workflow (job succeeds)' {
        if (-not $script:HaveAct -or -not $script:HaveDocker) {
            Set-ItResult -Skipped -Because 'act/docker unavailable'
            return
        }

        $result = Invoke-ActCase -CaseName 'all-approved' `
                                 -ManifestRelPath 'fixtures/all-approved-package.json' `
                                 -ExpectFailOnDenied $true

        $result.ExitCode | Should -Be 0 -Because $result.Output

        # Every expected dependency must show up as approved.
        $result.Output | Should -Match 'lodash\s+\S+\s+MIT\s+approved'
        $result.Output | Should -Match 'express\s+\S+\s+MIT\s+approved'
        $result.Output | Should -Match 'react\s+\S+\s+MIT\s+approved'
        $result.Output | Should -Match 'jest\s+\S+\s+MIT\s+approved'

        # Summary line exact values (4 approved, 0 denied, 0 unknown, 4 total).
        $result.Output | Should -Match 'approved:\s*4'
        $result.Output | Should -Match 'denied:\s*0'
        $result.Output | Should -Match 'unknown:\s*0'
        $result.Output | Should -Match 'total:\s*4'
        $result.Output | Should -Match 'RESULT: PASS'

        # act prints "Job succeeded" on success.
        $result.Output | Should -Match 'Job succeeded'
    }

    It 'Case 2: has-denied manifest reports denied but does not fail the job (FAIL_ON_DENIED=false)' {
        if (-not $script:HaveAct -or -not $script:HaveDocker) {
            Set-ItResult -Skipped -Because 'act/docker unavailable'
            return
        }

        $result = Invoke-ActCase -CaseName 'has-denied' `
                                 -ManifestRelPath 'fixtures/has-denied-package.json' `
                                 -ExpectFailOnDenied $false

        $result.ExitCode | Should -Be 0 -Because $result.Output

        # Exact per-dependency assertions.
        $result.Output | Should -Match 'lodash\s+\S+\s+MIT\s+approved'
        $result.Output | Should -Match 'copyleft-lib\s+\S+\s+GPL-3\.0\s+denied'
        $result.Output | Should -Match 'agpl-tool\s+\S+\s+AGPL-3\.0\s+denied'

        # Exact summary values.
        $result.Output | Should -Match 'approved:\s*1'
        $result.Output | Should -Match 'denied:\s*2'
        $result.Output | Should -Match 'unknown:\s*0'
        $result.Output | Should -Match 'total:\s*3'
        $result.Output | Should -Match 'RESULT: FAIL \(denied licenses present\)'

        $result.Output | Should -Match 'Job succeeded'
    }

    It 'Case 3: mixed requirements.txt exercises the pip parser and UNKNOWN path' {
        if (-not $script:HaveAct -or -not $script:HaveDocker) {
            Set-ItResult -Skipped -Because 'act/docker unavailable'
            return
        }

        $result = Invoke-ActCase -CaseName 'mixed-requirements' `
                                 -ManifestRelPath 'fixtures/mixed-requirements.txt' `
                                 -ExpectFailOnDenied $false

        $result.ExitCode | Should -Be 0 -Because $result.Output

        # Known approved rows.
        $result.Output | Should -Match 'requests\s+2\.31\.0\s+Apache-2\.0\s+approved'
        $result.Output | Should -Match 'flask\s+2\.3\.0\s+BSD-3-Clause\s+approved'
        $result.Output | Should -Match 'pytest\s+7\.4\s+MIT\s+approved'
        $result.Output | Should -Match 'django\s+unspecified\s+BSD-3-Clause\s+approved'
        # Unknown row (not in mock DB).
        $result.Output | Should -Match 'unknown-package\s+0\.0\.1\s+UNKNOWN\s+unknown'

        # Exact summary values: 4 approved, 0 denied, 1 unknown, 5 total.
        $result.Output | Should -Match 'approved:\s*4'
        $result.Output | Should -Match 'denied:\s*0'
        $result.Output | Should -Match 'unknown:\s*1'
        $result.Output | Should -Match 'total:\s*5'

        $result.Output | Should -Match 'Job succeeded'
    }
}
